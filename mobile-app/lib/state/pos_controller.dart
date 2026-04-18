import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../data/pos_repository.dart';
import '../l10n/app_i18n.dart';
import '../models/cart_item.dart';
import '../models/checkout_result.dart';
import '../models/order_detail.dart';
import '../models/paid_order.dart';
import '../models/product_category.dart';
import '../models/product.dart';
import '../models/promotion_rule.dart';
import '../models/refundable_order_item.dart';
import '../models/sales_stats.dart';
import '../models/spec_option.dart';
import '../models/suspended_order.dart';
import '../models/user_role.dart';
import '../services/app_settings_store.dart';
import '../services/pos_backend_sync_service.dart';

enum PaymentMethod {
  cash,
  wechat,
  alipay,
  promptPayQr,
  trueMoneyQr,
  card,
  deliveryApp,
}

enum OrderType { inStore, delivery }

enum BackendSyncState { unknown, pending, synced, failed, disabled }

class PosController extends ChangeNotifier {
  PosController({required this.repository, required this.settingsStore});

  final PosRepository repository;
  final AppSettingsStore settingsStore;
  final PosBackendSyncService _backendSyncService =
      const PosBackendSyncService();

  final List<CartItem> _cart = [];
  List<Product> _products = [];
  List<ProductCategory> _categoriesCatalog = [];
  List<PromotionRule> _promotionRules = [];
  List<SpecOption> _specOptions = [];
  List<SuspendedOrder> _suspendedOrders = [];
  List<PaidOrder> _recentPaidOrders = [];
  static const int _ordersPageSize = 20;
  int _ordersFetchLimit = _ordersPageSize;
  bool _hasMoreRecentPaidOrders = false;
  bool _isLoadingMoreRecentPaidOrders = false;
  bool _hasPosBackendConfig = false;
  final Map<String, BackendSyncState> _orderSyncStates =
      <String, BackendSyncState>{};
  Timer? _syncRetryTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _isProcessingSyncQueue = false;
  bool _isNetworkReachable = true;
  int _pendingSyncTaskCount = 0;
  String? _latestSyncError;
  DateTime? _lastSyncAttemptAt;
  DateTime? _lastSyncSuccessAt;
  static const String _syncTaskOrderCreate = 'order_create';
  static const String _syncTaskRefundCreate = 'refund_create';

  AppLanguage language = AppLanguage.th;
  UserRole userRole = UserRole.clerk;
  String selectedCategory = AppI18n.allCategoryKey;
  String searchKeyword = '';
  PaymentMethod paymentMethod = PaymentMethod.cash;
  double? cashReceived;
  bool isSubmitting = false;

  AppI18n get i18n => AppI18n(language);
  bool get isAdmin => userRole == UserRole.admin;

  List<CartItem> get cart => List.unmodifiable(_cart);
  List<SuspendedOrder> get suspendedOrders =>
      List.unmodifiable(_suspendedOrders);
  List<PaidOrder> get recentPaidOrders => List.unmodifiable(_recentPaidOrders);
  bool get hasMoreRecentPaidOrders => _hasMoreRecentPaidOrders;
  bool get isLoadingMoreRecentPaidOrders => _isLoadingMoreRecentPaidOrders;
  bool get hasPosBackendConfig => _hasPosBackendConfig;
  bool get isNetworkReachable => _isNetworkReachable;
  int get pendingSyncTaskCount => _pendingSyncTaskCount;
  String? get latestSyncError => _latestSyncError;
  DateTime? get lastSyncAttemptAt => _lastSyncAttemptAt;
  DateTime? get lastSyncSuccessAt => _lastSyncSuccessAt;

  List<Product> get products => _products;
  List<ProductCategory> get categoriesCatalog =>
      List.unmodifiable(_categoriesCatalog);
  List<PromotionRule> get promotionRules => List.unmodifiable(_promotionRules);

  List<SpecOption> get sizeOptions => _specOptions
      .where((e) => e.groupKey == SpecGroupKey.size && e.isActive)
      .toList(growable: false);

  List<SpecOption> get sugarOptions => _specOptions
      .where((e) => e.groupKey == SpecGroupKey.sugar && e.isActive)
      .toList(growable: false);

  List<SpecOption> get iceOptions => _specOptions
      .where((e) => e.groupKey == SpecGroupKey.ice && e.isActive)
      .toList(growable: false);

  List<SpecOption> get toppingOptions => _specOptions
      .where((e) => e.groupKey == SpecGroupKey.toppings && e.isActive)
      .toList(growable: false);

  List<Product> get beverageProducts => _products
      .where((product) => product.category != '加料')
      .toList(growable: false);

  List<String> get categories {
    final values =
        _categoriesCatalog
            .where((e) => e.isActive)
            .map((e) => e.name.trim())
            .where((e) => e.isNotEmpty && e != '加料')
            .toSet()
            .toList()
          ..sort();
    if (values.isEmpty) {
      values.addAll(
        beverageProducts.map((e) => e.category).toSet().toList()..sort(),
      );
    }
    return [AppI18n.allCategoryKey, ...values];
  }

  String categoryDisplayLabel(String category) {
    final key = category.trim();
    if (key.isEmpty || key == AppI18n.allCategoryKey) return i18n.allCategory;
    final matched = _categoriesCatalog
        .where((e) => e.name.trim() == key)
        .toList(growable: false);
    if (matched.isNotEmpty) {
      return matched.first.localizedName(language.name);
    }
    return i18n.categoryLabel(category);
  }

  List<Product> get filteredProducts {
    final keyword = searchKeyword.trim().toLowerCase();
    return beverageProducts
        .where((product) {
          final matchCategory =
              selectedCategory == AppI18n.allCategoryKey ||
              product.category == selectedCategory;
          final localized = product.localizedName(language.name).toLowerCase();
          final nameTh = (product.nameTh ?? '').toLowerCase();
          final nameZh = (product.nameZh ?? '').toLowerCase();
          final nameEn = (product.nameEn ?? '').toLowerCase();
          final matchKeyword =
              keyword.isEmpty ||
              product.name.toLowerCase().contains(keyword) ||
              localized.contains(keyword) ||
              nameTh.contains(keyword) ||
              nameZh.contains(keyword) ||
              nameEn.contains(keyword) ||
              product.category.toLowerCase().contains(keyword);
          return matchCategory && matchKeyword;
        })
        .toList(growable: false);
  }

  double get subtotal =>
      _cart.fold(0, (sum, item) => sum + item.unitPrice * item.quantity);

  double get discount => 0;

  double get total => subtotal - discount;

  double get change {
    final received = cashReceived;
    if (paymentMethod != PaymentMethod.cash || received == null) return 0;
    final diff = received - total;
    return diff > 0 ? diff : 0;
  }

  bool get canCheckout {
    return _cart.isNotEmpty && !isSubmitting;
  }

  Future<void> loadProducts() async {
    final savedLanguage = await settingsStore.loadLanguage();
    if (savedLanguage != null) {
      language = savedLanguage;
    }
    final savedRole = await settingsStore.loadUserRole();
    if (savedRole != null) {
      userRole = savedRole;
    }
    _products = await repository.fetchProducts();
    _categoriesCatalog = await repository.fetchCategories(
      includeInactive: true,
    );
    _promotionRules = await repository.fetchPromotionRules(
      includeInactive: true,
    );
    _specOptions = await repository.fetchSpecOptions();
    _suspendedOrders = await repository.fetchSuspendedOrders();
    _recentPaidOrders = await repository.fetchRecentPaidOrders(
      limit: _ordersFetchLimit,
    );
    final posApiBaseUrl = await settingsStore.loadPosApiBaseUrl();
    _hasPosBackendConfig =
        posApiBaseUrl != null && posApiBaseUrl.trim().isNotEmpty;
    final totalCount = await repository.countRecentPaidOrders();
    _hasMoreRecentPaidOrders = _recentPaidOrders.length < totalCount;
    await _refreshSyncQueueOverview(notify: false);
    notifyListeners();
    await _initConnectivityWatch();
    _startSyncRetryLoop();
    unawaited(_processSyncQueue());
  }

  Future<void> refreshBackendSyncConfig() async {
    final posApiBaseUrl = await settingsStore.loadPosApiBaseUrl();
    _hasPosBackendConfig =
        posApiBaseUrl != null && posApiBaseUrl.trim().isNotEmpty;
    notifyListeners();
    if (_hasPosBackendConfig) {
      unawaited(_processSyncQueue());
    } else {
      await _refreshSyncQueueOverview();
    }
  }

  Future<void> retrySyncQueueNow() async {
    await _processSyncQueue();
  }

  BackendSyncState orderSyncStateOf(String orderNo) {
    final state = _orderSyncStates[orderNo];
    if (state != null) return state;
    if (!_hasPosBackendConfig) return BackendSyncState.disabled;
    return BackendSyncState.unknown;
  }

  Future<List<SpecOption>> loadSpecOptionsForManagement({
    String? groupKey,
    bool includeInactive = true,
  }) {
    return repository.fetchSpecOptions(
      groupKey: groupKey,
      includeInactive: includeInactive,
    );
  }

  Future<void> createSpecOption({
    required String groupKey,
    required String name,
    String? nameTh,
    String? nameZh,
    String? nameEn,
    double price = 0,
  }) async {
    _ensureAdmin();
    await repository.createSpecOption(
      groupKey: groupKey,
      name: name,
      nameTh: nameTh,
      nameZh: nameZh,
      nameEn: nameEn,
      price: price,
    );
    _specOptions = await repository.fetchSpecOptions();
    notifyListeners();
  }

  Future<void> updateSpecOption({
    required int id,
    required String name,
    String? nameTh,
    String? nameZh,
    String? nameEn,
    double price = 0,
  }) async {
    _ensureAdmin();
    await repository.updateSpecOption(
      id: id,
      name: name,
      nameTh: nameTh,
      nameZh: nameZh,
      nameEn: nameEn,
      price: price,
    );
    _specOptions = await repository.fetchSpecOptions();
    notifyListeners();
  }

  Future<void> setSpecOptionActive(int id, bool isActive) async {
    _ensureAdmin();
    await repository.setSpecOptionActive(id, isActive);
    _specOptions = await repository.fetchSpecOptions();
    notifyListeners();
  }

  Future<void> deleteSpecOption(int id) async {
    _ensureAdmin();
    await repository.deleteSpecOption(id);
    _specOptions = await repository.fetchSpecOptions();
    notifyListeners();
  }

  Future<List<Product>> loadAllProductsForManagement() {
    return repository.fetchAllProducts();
  }

  Future<void> createProduct({
    required String name,
    required String category,
    required double price,
    double? deliveryPrice,
    String promoType = 'none',
    double promoValue = 0,
    bool promoActive = false,
    String? nameTh,
    String? nameZh,
    String? nameEn,
    String? description,
    String? imageUrl,
    bool showSize = true,
    bool showSugar = true,
    bool showIce = true,
    bool showToppings = true,
  }) async {
    _ensureAdmin();
    await repository.createProduct(
      name: name,
      category: category,
      price: price,
      deliveryPrice: deliveryPrice,
      promoType: promoType,
      promoValue: promoValue,
      promoActive: promoActive,
      nameTh: nameTh,
      nameZh: nameZh,
      nameEn: nameEn,
      description: description,
      imageUrl: imageUrl,
      showSize: showSize,
      showSugar: showSugar,
      showIce: showIce,
      showToppings: showToppings,
    );
    _products = await repository.fetchProducts();
    notifyListeners();
  }

  Future<void> updateProduct({
    required int id,
    required String name,
    required String category,
    required double price,
    double? deliveryPrice,
    String promoType = 'none',
    double promoValue = 0,
    bool promoActive = false,
    String? nameTh,
    String? nameZh,
    String? nameEn,
    String? description,
    String? imageUrl,
    bool showSize = true,
    bool showSugar = true,
    bool showIce = true,
    bool showToppings = true,
  }) async {
    _ensureAdmin();
    await repository.updateProduct(
      id: id,
      name: name,
      category: category,
      price: price,
      deliveryPrice: deliveryPrice,
      promoType: promoType,
      promoValue: promoValue,
      promoActive: promoActive,
      nameTh: nameTh,
      nameZh: nameZh,
      nameEn: nameEn,
      description: description,
      imageUrl: imageUrl,
      showSize: showSize,
      showSugar: showSugar,
      showIce: showIce,
      showToppings: showToppings,
    );
    _products = await repository.fetchProducts();
    notifyListeners();
  }

  Future<void> setProductActive(int id, bool isActive) async {
    _ensureAdmin();
    await repository.setProductActive(id, isActive);
    _products = await repository.fetchProducts();
    notifyListeners();
  }

  Future<void> deleteProduct(int id) async {
    _ensureAdmin();
    await repository.deleteProduct(id);
    _products = await repository.fetchProducts();
    notifyListeners();
  }

  Future<List<ProductCategory>> loadCategoriesForManagement({
    bool includeInactive = true,
  }) {
    return repository.fetchCategories(includeInactive: includeInactive);
  }

  Future<List<ProductCategory>> loadActiveCategories() {
    return repository.fetchCategories(includeInactive: false);
  }

  Future<void> createCategory(
    String name, {
    String? nameTh,
    String? nameZh,
    String? nameEn,
  }) async {
    _ensureAdmin();
    await repository.createCategory(
      name,
      nameTh: nameTh,
      nameZh: nameZh,
      nameEn: nameEn,
    );
    _categoriesCatalog = await repository.fetchCategories(
      includeInactive: true,
    );
    notifyListeners();
  }

  Future<void> renameCategory({
    required int id,
    required String newName,
    String? nameTh,
    String? nameZh,
    String? nameEn,
  }) async {
    _ensureAdmin();
    await repository.renameCategory(
      id: id,
      newName: newName,
      nameTh: nameTh,
      nameZh: nameZh,
      nameEn: nameEn,
    );
    _products = await repository.fetchProducts();
    _categoriesCatalog = await repository.fetchCategories(
      includeInactive: true,
    );
    notifyListeners();
  }

  Future<void> setCategoryActive(int id, bool isActive) async {
    _ensureAdmin();
    await repository.setCategoryActive(id, isActive);
    _categoriesCatalog = await repository.fetchCategories(
      includeInactive: true,
    );
    notifyListeners();
  }

  Future<void> deleteCategory(int id) async {
    _ensureAdmin();
    await repository.deleteCategory(id);
    _categoriesCatalog = await repository.fetchCategories(
      includeInactive: true,
    );
    notifyListeners();
  }

  Future<List<PromotionRule>> loadPromotionRulesForManagement({
    bool includeInactive = true,
  }) {
    return repository.fetchPromotionRules(includeInactive: includeInactive);
  }

  Future<void> createPromotionRule({
    required String name,
    required PromotionType type,
    required int priority,
    required bool isActive,
    required bool applyInStore,
    required bool applyDelivery,
    required Map<String, dynamic> condition,
    required Map<String, dynamic> benefit,
    DateTime? startAt,
    DateTime? endAt,
  }) async {
    _ensureAdmin();
    await repository.createPromotionRule(
      name: name,
      type: type,
      priority: priority,
      isActive: isActive,
      applyInStore: applyInStore,
      applyDelivery: applyDelivery,
      condition: condition,
      benefit: benefit,
      startAt: startAt,
      endAt: endAt,
    );
    _promotionRules = await repository.fetchPromotionRules(
      includeInactive: true,
    );
    notifyListeners();
  }

  Future<void> updatePromotionRule({
    required int id,
    required String name,
    required PromotionType type,
    required int priority,
    required bool isActive,
    required bool applyInStore,
    required bool applyDelivery,
    required Map<String, dynamic> condition,
    required Map<String, dynamic> benefit,
    DateTime? startAt,
    DateTime? endAt,
  }) async {
    _ensureAdmin();
    await repository.updatePromotionRule(
      id: id,
      name: name,
      type: type,
      priority: priority,
      isActive: isActive,
      applyInStore: applyInStore,
      applyDelivery: applyDelivery,
      condition: condition,
      benefit: benefit,
      startAt: startAt,
      endAt: endAt,
    );
    _promotionRules = await repository.fetchPromotionRules(
      includeInactive: true,
    );
    notifyListeners();
  }

  Future<void> setPromotionRuleActive(int id, bool isActive) async {
    _ensureAdmin();
    await repository.setPromotionRuleActive(id, isActive);
    _promotionRules = await repository.fetchPromotionRules(
      includeInactive: true,
    );
    notifyListeners();
  }

  Future<void> deletePromotionRule(int id) async {
    _ensureAdmin();
    await repository.deletePromotionRule(id);
    _promotionRules = await repository.fetchPromotionRules(
      includeInactive: true,
    );
    notifyListeners();
  }

  void setLanguage(AppLanguage value) {
    language = value;
    settingsStore.saveLanguage(value);
    notifyListeners();
  }

  Future<void> setUserRole(UserRole value) async {
    userRole = value;
    await settingsStore.saveUserRole(value);
    notifyListeners();
  }

  void setCategory(String value) {
    selectedCategory = value;
    notifyListeners();
  }

  void setSearch(String keyword) {
    searchKeyword = keyword;
    notifyListeners();
  }

  void setPaymentMethod(PaymentMethod value) {
    paymentMethod = value;
    if (value != PaymentMethod.cash) {
      cashReceived = null;
    }
    notifyListeners();
  }

  void setCashReceived(String value) {
    final cleaned = value.trim();
    if (cleaned.isEmpty) {
      cashReceived = null;
    } else {
      cashReceived = double.tryParse(cleaned);
    }
    notifyListeners();
  }

  void quickSetCashReceived(double value) {
    cashReceived = value;
    notifyListeners();
  }

  void addProductWithOptions({
    required Product product,
    required String sizeName,
    required double sizeExtraPrice,
    required String sugarName,
    required String iceName,
    required List<ToppingSelection> toppings,
    required String note,
  }) {
    final normalizedNote = note.trim();
    final toppingIds = toppings.map((e) => e.id).toList()..sort();
    final index = _cart.indexWhere(
      (item) =>
          item.product.id == product.id &&
          item.sizeName == sizeName &&
          item.sizeExtraPrice == sizeExtraPrice &&
          item.sugarName == sugarName &&
          item.iceName == iceName &&
          _sameToppingIds(item.toppings, toppingIds) &&
          item.note.trim() == normalizedNote,
    );

    if (index == -1) {
      _cart.add(
        CartItem(
          product: product,
          sizeName: sizeName,
          sizeExtraPrice: sizeExtraPrice,
          sugarName: sugarName,
          iceName: iceName,
          toppings: List<ToppingSelection>.from(toppings),
          note: normalizedNote,
        ),
      );
    } else {
      _cart[index].quantity += 1;
    }
    notifyListeners();
  }

  void increase(CartItem item) {
    item.quantity += 1;
    notifyListeners();
  }

  void decrease(CartItem item) {
    item.quantity -= 1;
    if (item.quantity <= 0) {
      _cart.remove(item);
    }
    notifyListeners();
  }

  void remove(CartItem item) {
    _cart.remove(item);
    notifyListeners();
  }

  void clearCart() {
    _cart.clear();
    cashReceived = null;
    notifyListeners();
  }

  Future<String> suspendCurrentCart({String? label}) async {
    if (_cart.isEmpty) throw StateError('Cart is empty.');
    final ticketNo = await repository.suspendCart(
      items: List<CartItem>.from(_cart),
      total: total,
      label: label,
    );
    clearCart();
    _suspendedOrders = await repository.fetchSuspendedOrders();
    notifyListeners();
    return ticketNo;
  }

  Future<void> restoreSuspendedCart(int suspendedId) async {
    final restored = await repository.restoreSuspendedOrder(suspendedId);
    await repository.deleteSuspendedOrder(suspendedId);
    _cart
      ..clear()
      ..addAll(restored);
    _suspendedOrders = await repository.fetchSuspendedOrders();
    notifyListeners();
  }

  Future<void> deleteSuspendedCart(int suspendedId) async {
    await repository.deleteSuspendedOrder(suspendedId);
    _suspendedOrders = await repository.fetchSuspendedOrders();
    notifyListeners();
  }

  Future<List<CartItem>> loadSuspendedCartDetails(int suspendedId) {
    return repository.restoreSuspendedOrder(suspendedId);
  }

  Future<void> refreshSuspendAndOrders() async {
    _suspendedOrders = await repository.fetchSuspendedOrders();
    _ordersFetchLimit = _ordersPageSize;
    _recentPaidOrders = await repository.fetchRecentPaidOrders(
      limit: _ordersFetchLimit,
    );
    final totalCount = await repository.countRecentPaidOrders();
    _hasMoreRecentPaidOrders = _recentPaidOrders.length < totalCount;
    _isLoadingMoreRecentPaidOrders = false;
    notifyListeners();
  }

  Future<void> deleteOrderByNo(String orderNo) async {
    _ensureAdmin();
    await repository.deleteOrderByNo(orderNo);
    await refreshSuspendAndOrders();
  }

  Future<void> loadMoreRecentPaidOrders() async {
    if (_isLoadingMoreRecentPaidOrders || !_hasMoreRecentPaidOrders) return;
    _isLoadingMoreRecentPaidOrders = true;
    notifyListeners();
    try {
      _ordersFetchLimit += _ordersPageSize;
      _recentPaidOrders = await repository.fetchRecentPaidOrders(
        limit: _ordersFetchLimit,
      );
      final totalCount = await repository.countRecentPaidOrders();
      _hasMoreRecentPaidOrders = _recentPaidOrders.length < totalCount;
    } finally {
      _isLoadingMoreRecentPaidOrders = false;
      notifyListeners();
    }
  }

  void updateItemOptions({
    required CartItem item,
    required String sizeName,
    required double sizeExtraPrice,
    required String sugarName,
    required String iceName,
    required List<ToppingSelection> toppings,
    required String note,
  }) {
    item
      ..sizeName = sizeName
      ..sizeExtraPrice = sizeExtraPrice
      ..sugarName = sugarName
      ..iceName = iceName
      ..toppings = List<ToppingSelection>.from(toppings)
      ..note = note.trim();
    notifyListeners();
  }

  bool _sameToppingIds(List<ToppingSelection> existing, List<int> selectedIds) {
    final existingIds = existing.map((e) => e.id).toList()..sort();
    if (existingIds.length != selectedIds.length) return false;
    for (var i = 0; i < existingIds.length; i++) {
      if (existingIds[i] != selectedIds[i]) return false;
    }
    return true;
  }

  void _ensureAdmin() {
    if (isAdmin) return;
    throw StateError('Permission denied: admin only.');
  }

  Future<CheckoutResult> checkout() async {
    return checkoutWith(
      method: paymentMethod,
      cashReceivedAmount: paymentMethod == PaymentMethod.cash
          ? cashReceived
          : null,
      orderType: OrderType.inStore,
    );
  }

  Future<CheckoutResult> checkoutWith({
    required PaymentMethod method,
    double? cashReceivedAmount,
    double deliveryPlatformDiscount = 0,
    required OrderType orderType,
    String? orderChannel,
    String? platformOrderId,
  }) async {
    if (_cart.isEmpty || isSubmitting) {
      throw StateError('Checkout is not allowed.');
    }
    final pricing = _buildPricingForOrderType(orderType);
    final pricedItems = pricing.items;
    final checkoutSubtotal = pricing.subtotal;
    final checkoutDiscount = pricing.discount;
    final checkoutTotal = pricing.total;
    final normalizedDeliveryDiscount = orderType == OrderType.delivery
        ? deliveryPlatformDiscount.clamp(0, checkoutTotal).toDouble()
        : 0.0;
    final finalDiscount = checkoutDiscount + normalizedDeliveryDiscount;
    final finalTotal = (checkoutTotal - normalizedDeliveryDiscount)
        .clamp(0, double.infinity)
        .toDouble();
    final promoAmount = pricing.promoAmount;
    final promoBreakdownJson = jsonEncode(
      pricing.appliedPromotions.map((e) => e.toMap()).toList(growable: false),
    );
    if (method == PaymentMethod.cash) {
      if (cashReceivedAmount == null || cashReceivedAmount < finalTotal) {
        throw StateError('Cash received is not enough.');
      }
    }

    isSubmitting = true;
    notifyListeners();

    try {
      paymentMethod = method;
      cashReceived = method == PaymentMethod.cash ? cashReceivedAmount : null;
      final normalizedChannel = orderType == OrderType.delivery
          ? (orderChannel == null || orderChannel.trim().isEmpty
                ? 'Other'
                : orderChannel.trim())
          : '';
      final normalizedPlatformOrderId = orderType == OrderType.delivery
          ? (platformOrderId?.trim() ?? '')
          : '';
      final checkoutResult = await repository.createOrder(
        items: pricedItems,
        subtotal: checkoutSubtotal,
        discount: finalDiscount,
        total: finalTotal,
        promoAmount: promoAmount,
        promoBreakdownJson: promoBreakdownJson,
        paymentMethod: method.name,
        orderType: orderType.name,
        orderChannel: normalizedChannel,
        platformOrderId: normalizedPlatformOrderId,
        receivedAmount: method == PaymentMethod.cash
            ? cashReceivedAmount
            : null,
        changeAmount: method == PaymentMethod.cash
            ? ((cashReceivedAmount ?? 0) - finalTotal).clamp(0, double.infinity)
            : null,
      );
      _syncOrderToBackend(
        orderNo: checkoutResult.orderNo,
        orderType: checkoutResult.orderType,
        orderChannel: checkoutResult.orderChannel,
        total: finalTotal,
        createdAt: checkoutResult.createdAt,
      );
      clearCart();
      _recentPaidOrders = await repository.fetchRecentPaidOrders(
        limit: _ordersFetchLimit,
      );
      final totalCount = await repository.countRecentPaidOrders();
      _hasMoreRecentPaidOrders = _recentPaidOrders.length < totalCount;
      return checkoutResult;
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  double estimateCheckoutTotal(
    OrderType orderType, {
    double deliveryPlatformDiscount = 0,
  }) {
    final baseTotal = _buildPricingForOrderType(orderType).total;
    if (orderType != OrderType.delivery) return baseTotal;
    return (baseTotal - deliveryPlatformDiscount.clamp(0, baseTotal))
        .clamp(0, double.infinity)
        .toDouble();
  }

  CheckoutPricingPreview previewPricing(
    OrderType orderType, {
    double deliveryPlatformDiscount = 0,
  }) {
    final pricing = _buildPricingForOrderType(orderType);
    final extraDeliveryDiscount = orderType == OrderType.delivery
        ? deliveryPlatformDiscount.clamp(0, pricing.total).toDouble()
        : 0.0;
    return CheckoutPricingPreview(
      rawSubtotal: pricing.rawSubtotal,
      productDiscountAmount: pricing.productDiscountAmount,
      subtotal: pricing.subtotal,
      promoAmount: pricing.promoAmount,
      discount: pricing.discount + extraDeliveryDiscount,
      total: (pricing.total - extraDeliveryDiscount)
          .clamp(0, double.infinity)
          .toDouble(),
    );
  }

  List<CartItem> buildReceiptItemsForOrderType(OrderType orderType) {
    return _buildPricingForOrderType(orderType).items;
  }

  _PricingResult _buildPricingForOrderType(OrderType orderType) {
    final isDelivery = orderType == OrderType.delivery;
    final baseItems = _cart
        .map(
          (item) => _cloneCartItem(
            item,
            product: _productWithOrderTypePrice(
              item.product,
              isDelivery,
              applyPromotion: false,
            ),
          ),
        )
        .toList(growable: false);
    final productDiscountedItems = _cart
        .map(
          (item) => _cloneCartItem(
            item,
            product: _productWithOrderTypePrice(
              item.product,
              isDelivery,
              applyPromotion: !isDelivery,
            ),
          ),
        )
        .toList(growable: false);
    var workingItems = productDiscountedItems;

    final appliedPromotions = <AppliedPromotion>[];
    var orderLevelPromotion = 0.0;
    if (!isDelivery) {
      final activeRules =
          _promotionRules
              .where((rule) {
                if (!rule.isActive || !rule.applyInStore) return false;
                final now = DateTime.now();
                if (rule.startAt != null && now.isBefore(rule.startAt!)) {
                  return false;
                }
                if (rule.endAt != null && now.isAfter(rule.endAt!)) {
                  return false;
                }
                return true;
              })
              .toList(growable: false)
            ..sort((a, b) => a.priority.compareTo(b.priority));

      for (final rule in activeRules) {
        switch (rule.type) {
          case PromotionType.comboPrice:
            final result = _applyComboPriceRule(workingItems, rule);
            workingItems = result.items;
            if (result.discount > 0) {
              appliedPromotions.add(
                AppliedPromotion(
                  ruleId: rule.id,
                  ruleName: rule.name,
                  type: rule.type,
                  amount: result.discount,
                  description: result.description,
                ),
              );
            }
            break;
          case PromotionType.fullReduce:
            final discount = _calcFullReduce(rule, workingItems);
            if (discount > 0) {
              orderLevelPromotion += discount;
              appliedPromotions.add(
                AppliedPromotion(
                  ruleId: rule.id,
                  ruleName: rule.name,
                  type: rule.type,
                  amount: discount,
                  description: '满减',
                ),
              );
            }
            break;
          case PromotionType.nthDiscount:
            final result = _applyNthDiscountRule(workingItems, rule);
            workingItems = result.items;
            if (result.discount > 0) {
              appliedPromotions.add(
                AppliedPromotion(
                  ruleId: rule.id,
                  ruleName: rule.name,
                  type: rule.type,
                  amount: result.discount,
                  description: result.description,
                ),
              );
            }
            break;
        }
      }
    }

    final rawSubtotal = _subtotalOf(baseItems);
    final productDiscountedSubtotal = _subtotalOf(productDiscountedItems);
    final subtotal = _subtotalOf(workingItems);
    final productDiscountAmount = (rawSubtotal - productDiscountedSubtotal)
        .clamp(0, double.infinity)
        .toDouble();
    final orderDiscount = _discountOf(subtotal, orderType: orderType);
    final promoAmount = appliedPromotions.fold<double>(
      0,
      (sum, item) => sum + item.amount,
    );
    final total = subtotal - orderDiscount - orderLevelPromotion;
    return _PricingResult(
      items: workingItems,
      rawSubtotal: rawSubtotal,
      productDiscountAmount: productDiscountAmount,
      subtotal: subtotal,
      discount: orderDiscount,
      total: total > 0 ? total : 0,
      promoAmount: promoAmount,
      appliedPromotions: appliedPromotions,
    );
  }

  Product _productWithOrderTypePrice(
    Product product,
    bool isDelivery, {
    required bool applyPromotion,
  }) {
    if (!isDelivery && applyPromotion) {
      // Keep product-level promotion for in-store price calculation.
      return product;
    }
    return product.copyWith(
      price: product.effectivePriceByOrderType(
        isDelivery: isDelivery,
        applyPromotion: applyPromotion,
      ),
      promoType: ProductPromoType.none,
      promoValue: 0,
      promoActive: false,
    );
  }

  CartItem _cloneCartItem(CartItem source, {Product? product, int? quantity}) {
    return CartItem(
      product: product ?? source.product,
      quantity: quantity ?? source.quantity,
      sizeName: source.sizeName,
      sizeExtraPrice: source.sizeExtraPrice,
      sugarName: source.sugarName,
      iceName: source.iceName,
      toppings: List<ToppingSelection>.from(source.toppings),
      note: source.note,
    );
  }

  double _subtotalOf(List<CartItem> items) =>
      items.fold(0.0, (sum, item) => sum + item.unitPrice * item.quantity);

  double _discountOf(double subtotalValue, {required OrderType orderType}) {
    return 0;
  }

  _PromotionApplyResult _applyComboPriceRule(
    List<CartItem> sourceItems,
    PromotionRule rule,
  ) {
    final condition = rule.condition;
    final requiredCategory = (condition['requiredCategory'] as String?) ?? '';
    final maxApplications =
        (condition['maxApplications'] as num?)?.toInt() ?? 0;
    final discountAmount =
        (rule.benefit['discountAmount'] as num?)?.toDouble() ?? 0;
    final legacyBundlePrice =
        (rule.benefit['bundlePrice'] as num?)?.toDouble() ?? 0;
    if (discountAmount <= 0 && legacyBundlePrice <= 0) {
      return _PromotionApplyResult(
        items: sourceItems,
        discount: 0,
        description: '',
      );
    }

    var availableComboCount = sourceItems
        .where((item) {
          if (!_isActivityEligibleItem(item)) return false;
          if (requiredCategory.trim().isEmpty) return false;
          return item.product.category.trim() == requiredCategory.trim();
        })
        .fold<int>(0, (sum, item) => sum + item.quantity);
    if (availableComboCount <= 0) {
      return _PromotionApplyResult(
        items: sourceItems,
        discount: 0,
        description: '',
      );
    }
    if (maxApplications > 0 && availableComboCount > maxApplications) {
      availableComboCount = maxApplications;
    }

    final output = <CartItem>[];
    var discount = 0.0;
    for (final item in sourceItems) {
      final matchTarget = _matchRuleTarget(item.product, condition);
      if (!matchTarget ||
          !_isActivityEligibleItem(item) ||
          availableComboCount <= 0) {
        output.add(_cloneCartItem(item));
        continue;
      }
      final comboQty = item.quantity < availableComboCount
          ? item.quantity
          : availableComboCount;
      final normalQty = item.quantity - comboQty;
      availableComboCount -= comboQty;
      if (comboQty > 0) {
        final oldUnit = item.unitPrice;
        final comboBase = discountAmount > 0
            ? (item.product.price - discountAmount)
                  .clamp(0, double.infinity)
                  .toDouble()
            : (legacyBundlePrice - item.sizeExtraPrice - item.toppingTotal)
                  .clamp(0, double.infinity)
                  .toDouble();
        final comboItem = _cloneCartItem(
          item,
          quantity: comboQty,
          product: item.product.copyWith(
            price: comboBase,
            promoType: ProductPromoType.none,
            promoValue: 0,
            promoActive: false,
          ),
        );
        output.add(comboItem);
        discount += ((oldUnit - comboItem.unitPrice) * comboQty);
      }
      if (normalQty > 0) {
        output.add(_cloneCartItem(item, quantity: normalQty));
      }
    }
    return _PromotionApplyResult(
      items: output,
      discount: discount > 0 ? discount : 0,
      description: '组合优惠',
    );
  }

  _PromotionApplyResult _applyNthDiscountRule(
    List<CartItem> sourceItems,
    PromotionRule rule,
  ) {
    final condition = rule.condition;
    final nth = (condition['nth'] as num?)?.toInt() ?? 2;
    final discountPercent =
        (rule.benefit['discountPercent'] as num?)?.toDouble() ?? 0;
    if (nth < 2 || discountPercent <= 0 || discountPercent >= 100) {
      return _PromotionApplyResult(
        items: sourceItems,
        discount: 0,
        description: '',
      );
    }

    final output = <CartItem>[];
    var discount = 0.0;
    for (final item in sourceItems) {
      if (!_matchRuleTarget(item.product, condition) || item.quantity < nth) {
        output.add(_cloneCartItem(item));
        continue;
      }
      if (!_isActivityEligibleItem(item)) {
        output.add(_cloneCartItem(item));
        continue;
      }
      final discountedQty = item.quantity ~/ nth;
      final normalQty = item.quantity - discountedQty;
      if (discountedQty > 0) {
        final discountedBase =
            (item.product.price * (1 - discountPercent / 100))
                .clamp(0, double.infinity)
                .toDouble();
        final discounted = _cloneCartItem(
          item,
          quantity: discountedQty,
          product: item.product.copyWith(
            price: discountedBase,
            promoType: ProductPromoType.none,
            promoValue: 0,
            promoActive: false,
          ),
        );
        output.add(discounted);
        discount += ((item.unitPrice - discounted.unitPrice) * discountedQty);
      }
      if (normalQty > 0) {
        output.add(_cloneCartItem(item, quantity: normalQty));
      }
    }
    return _PromotionApplyResult(
      items: output,
      discount: discount > 0 ? discount : 0,
      description: '第N件折扣',
    );
  }

  double _calcFullReduce(PromotionRule rule, List<CartItem> items) {
    final threshold = (rule.condition['threshold'] as num?)?.toDouble() ?? 0;
    final reduce = (rule.benefit['reduce'] as num?)?.toDouble() ?? 0;
    if (threshold <= 0 || reduce <= 0) return 0;
    final amount = _subtotalOf(
      items.where(_isActivityEligibleItem).toList(growable: false),
    );
    return amount >= threshold ? reduce : 0;
  }

  bool _matchRuleTarget(Product product, Map<String, dynamic> condition) {
    final rawTargetIds = (condition['targetProductIds'] as List?) ?? const [];
    final targetIds = rawTargetIds
        .map((e) => (e as num?)?.toInt())
        .whereType<int>()
        .toSet();
    final targetCategory =
        (condition['targetCategory'] as String?)?.trim() ?? '';
    if (targetIds.isEmpty && targetCategory.isEmpty) return false;
    if (targetIds.isNotEmpty && targetIds.contains(product.id)) return true;
    if (targetCategory.isNotEmpty &&
        product.category.trim() == targetCategory) {
      return true;
    }
    return false;
  }

  bool _isActivityEligibleItem(CartItem item) {
    // Product-level discount and activity promotions are mutually exclusive.
    return !item.product.hasPromotion;
  }

  Future<double> refundOrder({
    required String orderNo,
    String reason = '',
  }) async {
    final finalReason = reason.trim().isEmpty ? 'manual refund' : reason.trim();
    final amount = await repository.refundOrder(
      orderNo: orderNo,
      reason: finalReason,
      managerPin: '',
    );
    _syncRefundToBackend(
      orderNo: orderNo,
      amount: amount,
      reason: finalReason,
      createdAt: DateTime.now(),
    );
    _recentPaidOrders = await repository.fetchRecentPaidOrders(
      limit: _ordersFetchLimit,
    );
    final totalCount = await repository.countRecentPaidOrders();
    _hasMoreRecentPaidOrders = _recentPaidOrders.length < totalCount;
    notifyListeners();
    return amount;
  }

  Future<List<RefundableOrderItem>> loadRefundableOrderItems(String orderNo) {
    return repository.fetchRefundableOrderItems(orderNo);
  }

  Future<OrderDetail> loadOrderDetail(String orderNo) {
    return repository.fetchOrderDetail(orderNo);
  }

  Future<double> refundOrderItems({
    required String orderNo,
    required String reason,
    required Map<int, int> refundQtyByOrderItem,
  }) async {
    final finalReason = reason.trim().isEmpty ? 'manual refund' : reason.trim();
    final amount = await repository.refundOrderItems(
      orderNo: orderNo,
      reason: finalReason,
      managerPin: '',
      operatorName: 'cashier',
      refundQtyByOrderItem: refundQtyByOrderItem,
    );
    _syncRefundToBackend(
      orderNo: orderNo,
      amount: amount,
      reason: finalReason,
      createdAt: DateTime.now(),
    );
    _recentPaidOrders = await repository.fetchRecentPaidOrders(
      limit: _ordersFetchLimit,
    );
    final totalCount = await repository.countRecentPaidOrders();
    _hasMoreRecentPaidOrders = _recentPaidOrders.length < totalCount;
    notifyListeners();
    return amount;
  }

  Future<List<DailyRevenueStat>> loadDailyRevenueStats({
    int days = 30,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return repository.fetchDailyRevenueStats(
      days: days,
      startDate: startDate,
      endDate: endDate,
    );
  }

  Future<List<ProductSalesStat>> loadTopProductSalesStats({
    int days = 30,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 10,
  }) {
    return repository.fetchTopProductSalesStats(
      days: days,
      startDate: startDate,
      endDate: endDate,
      limit: limit,
    );
  }

  Future<List<PaymentMethodStat>> loadPaymentMethodStats({
    int days = 30,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return repository.fetchPaymentMethodStats(
      days: days,
      startDate: startDate,
      endDate: endDate,
    );
  }

  Future<List<OrderTypeStat>> loadOrderTypeStats({
    int days = 30,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return repository.fetchOrderTypeStats(
      days: days,
      startDate: startDate,
      endDate: endDate,
    );
  }

  Future<List<DeliveryChannelStat>> loadDeliveryChannelStats({
    int days = 30,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return repository.fetchDeliveryChannelStats(
      days: days,
      startDate: startDate,
      endDate: endDate,
    );
  }

  Future<List<HourlyRevenueStat>> loadHourlyRevenueStats({DateTime? date}) {
    return repository.fetchHourlyRevenueStats(date: date);
  }

  Future<HistoricalSyncReport> syncHistoricalOrdersToBackend({
    int? days,
  }) async {
    final baseUrl = await settingsStore.loadPosApiBaseUrl();
    if (baseUrl == null || baseUrl.trim().isEmpty) {
      throw StateError('POS backend URL is not configured.');
    }
    final now = DateTime.now();
    final startAt = (days != null && days > 0)
        ? DateTime(
            now.year,
            now.month,
            now.day,
          ).subtract(Duration(days: days - 1))
        : null;
    final orders = await repository.fetchOrdersForBackendSync(
      startAtInclusive: startAt,
    );
    if (orders.isEmpty) {
      return const HistoricalSyncReport(
        totalOrders: 0,
        syncedOrders: 0,
        skippedExistingOrders: 0,
        failedOrders: 0,
        totalRefunds: 0,
        syncedRefunds: 0,
        failedRefunds: 0,
      );
    }

    final createdOrderNos = <String>{};
    var syncedOrders = 0;
    var skippedExistingOrders = 0;
    var failedOrders = 0;
    var totalRefunds = 0;
    var syncedRefunds = 0;
    var failedRefunds = 0;

    for (final order in orders) {
      try {
        final exists = await _backendSyncService.orderExists(
          apiBaseUrl: baseUrl,
          orderNo: order.orderNo,
        );
        if (exists) {
          skippedExistingOrders += 1;
          _orderSyncStates[order.orderNo] = BackendSyncState.synced;
          continue;
        }
        await _backendSyncService.mirrorCreateOrder(
          apiBaseUrl: baseUrl,
          orderNo: order.orderNo,
          orderType: order.orderType,
          orderChannel: order.orderChannel,
          total: order.total,
          idempotencyKey: _syncTaskKeyForOrder(order.orderNo),
          createdAt: order.createdAt,
        );
        syncedOrders += 1;
        createdOrderNos.add(order.orderNo);
        _orderSyncStates[order.orderNo] = BackendSyncState.synced;
      } catch (e) {
        failedOrders += 1;
        _orderSyncStates[order.orderNo] = BackendSyncState.failed;
        debugPrint('historical order sync failed(${order.orderNo}): $e');
      }
    }

    // Only sync refunds for orders created by this run.
    for (final orderNo in createdOrderNos) {
      final refunds = await repository.fetchRefundsForBackendSync(orderNo);
      totalRefunds += refunds.length;
      for (final refund in refunds) {
        try {
          await _backendSyncService.mirrorRefund(
            apiBaseUrl: baseUrl,
            orderNo: orderNo,
            amount: refund.amount,
            reason: refund.reason,
            idempotencyKey: _syncTaskKeyForRefund(
              orderNo: orderNo,
              amount: refund.amount,
              reason: refund.reason,
              createdAt: refund.createdAt,
            ),
            createdAt: refund.createdAt,
          );
          syncedRefunds += 1;
        } catch (e) {
          failedRefunds += 1;
          debugPrint('historical refund sync failed($orderNo): $e');
        }
      }
    }

    notifyListeners();
    return HistoricalSyncReport(
      totalOrders: orders.length,
      syncedOrders: syncedOrders,
      skippedExistingOrders: skippedExistingOrders,
      failedOrders: failedOrders,
      totalRefunds: totalRefunds,
      syncedRefunds: syncedRefunds,
      failedRefunds: failedRefunds,
    );
  }

  Future<void> _syncOrderToBackend({
    required String orderNo,
    required String orderType,
    required String orderChannel,
    required double total,
    DateTime? createdAt,
  }) async {
    final baseUrl = await settingsStore.loadPosApiBaseUrl();
    if (baseUrl == null || baseUrl.trim().isEmpty) {
      _orderSyncStates[orderNo] = BackendSyncState.disabled;
      notifyListeners();
      return;
    }
    final taskKey = _syncTaskKeyForOrder(orderNo);
    _orderSyncStates[orderNo] = BackendSyncState.pending;
    notifyListeners();
    Future<void>(() async {
      try {
        await _backendSyncService.mirrorCreateOrder(
          apiBaseUrl: baseUrl,
          orderNo: orderNo,
          orderType: orderType,
          orderChannel: orderChannel,
          total: total,
          idempotencyKey: taskKey,
          createdAt: createdAt,
        );
        await repository.deleteSyncTaskByKey(taskKey);
        _orderSyncStates[orderNo] = BackendSyncState.synced;
        notifyListeners();
      } catch (e) {
        debugPrint('mirrorCreateOrder failed: $e');
        await repository.enqueueSyncTask(
          taskType: _syncTaskOrderCreate,
          taskKey: taskKey,
          payload: <String, Object?>{
            'order_no': orderNo,
            'order_type': orderType,
            'order_channel': orderChannel,
            'total': total,
            if (createdAt != null) 'created_at': createdAt.toIso8601String(),
          },
        );
        await _refreshSyncQueueOverview(notify: false);
        _orderSyncStates[orderNo] = BackendSyncState.failed;
        notifyListeners();
      }
    });
  }

  Future<void> _syncRefundToBackend({
    required String orderNo,
    required double amount,
    required String reason,
    DateTime? createdAt,
  }) async {
    final baseUrl = await settingsStore.loadPosApiBaseUrl();
    if (baseUrl == null || baseUrl.trim().isEmpty) return;
    final taskKey = _syncTaskKeyForRefund(
      orderNo: orderNo,
      amount: amount,
      reason: reason,
      createdAt: createdAt,
    );
    _orderSyncStates[orderNo] = BackendSyncState.pending;
    notifyListeners();
    Future<void>(() async {
      try {
        await _backendSyncService.mirrorRefund(
          apiBaseUrl: baseUrl,
          orderNo: orderNo,
          amount: amount,
          reason: reason,
          idempotencyKey: taskKey,
          createdAt: createdAt,
        );
        await repository.deleteSyncTaskByKey(taskKey);
        _orderSyncStates[orderNo] = BackendSyncState.synced;
        notifyListeners();
      } catch (e) {
        debugPrint('mirrorRefund failed: $e');
        await repository.enqueueSyncTask(
          taskType: _syncTaskRefundCreate,
          taskKey: taskKey,
          payload: <String, Object?>{
            'order_no': orderNo,
            'amount': amount,
            'reason': reason,
            if (createdAt != null) 'created_at': createdAt.toIso8601String(),
          },
        );
        await _refreshSyncQueueOverview(notify: false);
        _orderSyncStates[orderNo] = BackendSyncState.failed;
        notifyListeners();
      }
    });
  }

  void _startSyncRetryLoop() {
    if (_syncRetryTimer != null) return;
    _syncRetryTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      unawaited(_processSyncQueue());
    });
  }

  Future<void> _initConnectivityWatch() async {
    if (_connectivitySub != null) return;
    final connectivity = Connectivity();
    final initial = await connectivity.checkConnectivity();
    _isNetworkReachable = _hasUsableNetwork(initial);
    _connectivitySub = connectivity.onConnectivityChanged.listen((results) {
      final reachable = _hasUsableNetwork(results);
      final changed = reachable != _isNetworkReachable;
      _isNetworkReachable = reachable;
      if (changed) {
        notifyListeners();
        if (reachable) {
          unawaited(_processSyncQueue());
        }
      }
    });
  }

  bool _hasUsableNetwork(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    for (final result in results) {
      if (result != ConnectivityResult.none) {
        return true;
      }
    }
    return false;
  }

  Future<void> _processSyncQueue() async {
    if (_isProcessingSyncQueue) return;
    if (!_isNetworkReachable) return;
    final baseUrl = await settingsStore.loadPosApiBaseUrl();
    if (baseUrl == null || baseUrl.trim().isEmpty) return;
    _lastSyncAttemptAt = DateTime.now();
    _isProcessingSyncQueue = true;
    try {
      final tasks = await repository.fetchDueSyncTasks(limit: 20);
      var hasSuccess = false;
      for (final task in tasks) {
        try {
          if (task.taskType == _syncTaskOrderCreate) {
            final orderNo = (task.payload['order_no'] as String?) ?? '';
            final orderType =
                (task.payload['order_type'] as String?) ?? 'inStore';
            final orderChannel =
                (task.payload['order_channel'] as String?) ?? '';
            final total = (task.payload['total'] as num?)?.toDouble() ?? 0;
            final createdAtRaw = task.payload['created_at'] as String?;
            final createdAt =
                createdAtRaw == null || createdAtRaw.trim().isEmpty
                ? null
                : DateTime.tryParse(createdAtRaw);
            if (orderNo.trim().isEmpty || total <= 0) {
              await repository.markSyncTaskSuccess(task.id);
              continue;
            }
            await _backendSyncService.mirrorCreateOrder(
              apiBaseUrl: baseUrl,
              orderNo: orderNo,
              orderType: orderType,
              orderChannel: orderChannel,
              total: total,
              idempotencyKey: task.taskKey,
              createdAt: createdAt,
            );
            await repository.markSyncTaskSuccess(task.id);
            _orderSyncStates[orderNo] = BackendSyncState.synced;
            hasSuccess = true;
          } else if (task.taskType == _syncTaskRefundCreate) {
            final orderNo = (task.payload['order_no'] as String?) ?? '';
            final amount = (task.payload['amount'] as num?)?.toDouble() ?? 0;
            final reason = (task.payload['reason'] as String?) ?? '';
            final createdAtRaw = task.payload['created_at'] as String?;
            final createdAt =
                createdAtRaw == null || createdAtRaw.trim().isEmpty
                ? null
                : DateTime.tryParse(createdAtRaw);
            if (orderNo.trim().isEmpty || amount <= 0) {
              await repository.markSyncTaskSuccess(task.id);
              continue;
            }
            await _backendSyncService.mirrorRefund(
              apiBaseUrl: baseUrl,
              orderNo: orderNo,
              amount: amount,
              reason: reason,
              idempotencyKey: task.taskKey,
              createdAt: createdAt,
            );
            await repository.markSyncTaskSuccess(task.id);
            _orderSyncStates[orderNo] = BackendSyncState.synced;
            hasSuccess = true;
          } else {
            await repository.markSyncTaskSuccess(task.id);
            hasSuccess = true;
          }
        } catch (e) {
          final orderNo = (task.payload['order_no'] as String?) ?? '';
          await repository.markSyncTaskFailed(
            task.id,
            errorMessage: e.toString(),
          );
          if (orderNo.trim().isNotEmpty) {
            _orderSyncStates[orderNo] = BackendSyncState.failed;
          }
        }
      }
      if (hasSuccess) {
        _lastSyncSuccessAt = DateTime.now();
      }
      await _refreshSyncQueueOverview(notify: false);
      if (tasks.isNotEmpty) notifyListeners();
    } finally {
      _isProcessingSyncQueue = false;
    }
  }

  Future<void> _refreshSyncQueueOverview({bool notify = true}) async {
    _pendingSyncTaskCount = await repository.countPendingSyncTasks();
    _latestSyncError = await repository.fetchLatestSyncQueueError();
    if (notify) notifyListeners();
  }

  String _syncTaskKeyForOrder(String orderNo) => 'order:$orderNo';

  String _syncTaskKeyForRefund({
    required String orderNo,
    required double amount,
    required String reason,
    DateTime? createdAt,
  }) {
    final ts = createdAt?.toIso8601String() ?? '';
    return 'refund:$orderNo:$amount:${reason.trim()}:$ts';
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _connectivitySub = null;
    _syncRetryTimer?.cancel();
    _syncRetryTimer = null;
    super.dispose();
  }
}

class _PricingResult {
  const _PricingResult({
    required this.items,
    required this.rawSubtotal,
    required this.productDiscountAmount,
    required this.subtotal,
    required this.discount,
    required this.total,
    required this.promoAmount,
    required this.appliedPromotions,
  });

  final List<CartItem> items;
  final double rawSubtotal;
  final double productDiscountAmount;
  final double subtotal;
  final double discount;
  final double total;
  final double promoAmount;
  final List<AppliedPromotion> appliedPromotions;
}

class HistoricalSyncReport {
  const HistoricalSyncReport({
    required this.totalOrders,
    required this.syncedOrders,
    required this.skippedExistingOrders,
    required this.failedOrders,
    required this.totalRefunds,
    required this.syncedRefunds,
    required this.failedRefunds,
  });

  final int totalOrders;
  final int syncedOrders;
  final int skippedExistingOrders;
  final int failedOrders;
  final int totalRefunds;
  final int syncedRefunds;
  final int failedRefunds;
}

class _PromotionApplyResult {
  const _PromotionApplyResult({
    required this.items,
    required this.discount,
    required this.description,
  });

  final List<CartItem> items;
  final double discount;
  final String description;
}

class CheckoutPricingPreview {
  const CheckoutPricingPreview({
    required this.rawSubtotal,
    required this.productDiscountAmount,
    required this.subtotal,
    required this.promoAmount,
    required this.discount,
    required this.total,
  });

  final double rawSubtotal;
  final double productDiscountAmount;
  final double subtotal;
  final double promoAmount;
  final double discount;
  final double total;
}
