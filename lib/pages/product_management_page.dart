import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import 'category_management_page.dart';
import 'spec_management_page.dart';
import '../l10n/app_i18n.dart';
import '../models/product_category.dart';
import '../models/product.dart';
import '../models/spec_option.dart';
import '../services/image_upload_service.dart';
import '../services/snackbar_helper.dart';
import '../state/pos_controller.dart';

enum _ProductStatusFilter { all, active, inactive }

class ProductManagementPage extends StatefulWidget {
  const ProductManagementPage({
    super.key,
    required this.controller,
    required this.i18n,
  });

  final PosController controller;
  final AppI18n i18n;

  @override
  State<ProductManagementPage> createState() => _ProductManagementPageState();
}

class _ProductManagementPageState extends State<ProductManagementPage> {
  late final TextEditingController _keywordController;
  bool _loading = true;
  String? _error;
  String _keyword = '';
  String _category = AppI18n.allCategoryKey;
  _ProductStatusFilter _status = _ProductStatusFilter.all;
  List<Product> _allProducts = const <Product>[];
  List<ProductCategory> _categories = const <ProductCategory>[];

  @override
  void initState() {
    super.initState();
    _keywordController = TextEditingController();
    _loadProducts();
  }

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.controller.loadAllProductsForManagement();
      final categories = await widget.controller.loadActiveCategories();
      if (!mounted) return;
      setState(() {
        _allProducts = data
            .where((item) => !_isLegacyToppingCategory(item.category))
            .toList(growable: false);
        _categories = categories
            .where((item) => !_isLegacyToppingCategory(item.name))
            .toList(growable: false);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = widget.i18n;
    final categories = <String>[
      AppI18n.allCategoryKey,
      ..._uniqueCategoryValues(_allProducts.map((e) => e.category)),
    ];
    final selectedFilterCategory = categories.contains(_category)
        ? _category
        : AppI18n.allCategoryKey;
    final keyword = _keyword.trim().toLowerCase();
    final list = _allProducts
        .where((item) {
          final statusMatch = switch (_status) {
            _ProductStatusFilter.all => true,
            _ProductStatusFilter.active => item.isActive,
            _ProductStatusFilter.inactive => !item.isActive,
          };
          final categoryMatch =
              _category == AppI18n.allCategoryKey || item.category == _category;
          final keywordMatch =
              keyword.isEmpty ||
              item.name.toLowerCase().contains(keyword) ||
              (item.nameTh ?? '').toLowerCase().contains(keyword) ||
              (item.nameZh ?? '').toLowerCase().contains(keyword) ||
              (item.nameEn ?? '').toLowerCase().contains(keyword) ||
              item
                  .localizedName(i18n.language.name)
                  .toLowerCase()
                  .contains(keyword) ||
              item.category.toLowerCase().contains(keyword);
          return statusMatch && categoryMatch && keywordMatch;
        })
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(i18n.productManagement),
        actions: [
          IconButton(
            onPressed: _loadProducts,
            icon: const Icon(Icons.refresh),
            tooltip: i18n.retry,
          ),
          TextButton.icon(
            onPressed: _openAddDialog,
            icon: const Icon(Icons.add),
            label: Text(i18n.addProduct),
          ),
          TextButton.icon(
            onPressed: () => Navigator.of(context)
                .push(
                  MaterialPageRoute(
                    builder: (_) => CategoryManagementPage(
                      controller: widget.controller,
                      i18n: i18n,
                    ),
                  ),
                )
                .then((_) => _loadProducts()),
            icon: const Icon(Icons.category_outlined),
            label: Text(i18n.categoryManagement),
          ),
          TextButton.icon(
            onPressed: () => Navigator.of(context)
                .push(
                  MaterialPageRoute(
                    builder: (_) =>
                        SpecManagementPage(controller: widget.controller),
                  ),
                )
                .then((_) => _loadProducts()),
            icon: const Icon(Icons.tune),
            label: Text(i18n.specManagement),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7FAFE),
                  border: Border.all(color: const Color(0xFFE3EEF9)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 320,
                      height: 48,
                      child: TextField(
                        controller: _keywordController,
                        onChanged: (v) => setState(() => _keyword = v),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search),
                          hintText: i18n.searchProductHint,
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 180,
                      height: 48,
                      child: DropdownButtonFormField<String>(
                        initialValue: selectedFilterCategory,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                        ),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _category = value);
                        },
                        items: categories
                            .map(
                              (e) => DropdownMenuItem(
                                value: e,
                                child: Text(
                                  e == AppI18n.allCategoryKey
                                      ? i18n.allCategory
                                      : widget.controller.categoryDisplayLabel(
                                          e,
                                        ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ),
                    SizedBox(
                      width: 180,
                      height: 48,
                      child: DropdownButtonFormField<_ProductStatusFilter>(
                        initialValue: _status,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                        ),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _status = value);
                        },
                        items: [
                          DropdownMenuItem(
                            value: _ProductStatusFilter.all,
                            child: Text(i18n.allStatus),
                          ),
                          DropdownMenuItem(
                            value: _ProductStatusFilter.active,
                            child: Text(i18n.activeOnly),
                          ),
                          DropdownMenuItem(
                            value: _ProductStatusFilter.inactive,
                            child: Text(i18n.inactiveOnly),
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        _keywordController.clear();
                        setState(() {
                          _keyword = '';
                          _category = AppI18n.allCategoryKey;
                          _status = _ProductStatusFilter.all;
                        });
                      },
                      icon: const Icon(Icons.restart_alt),
                      label: Text(i18n.reset),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(child: Text(_error!))
                  : list.isEmpty
                  ? Center(child: Text(i18n.noProducts))
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, index) {
                        final item = list[index];
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: const Color(0xFFE3EEF9)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              _ProductThumb(imageUrl: item.imageUrl),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.localizedName(i18n.language.name),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      item.hasPromotion
                                          ? '${widget.controller.categoryDisplayLabel(item.category)} · ${i18n.formatMoney(item.effectivePrice)} (原价 ${i18n.formatMoney(item.price)})'
                                          : '${widget.controller.categoryDisplayLabel(item.category)} · ${i18n.formatMoney(item.price)}',
                                    ),
                                    if (item.deliveryPrice != null &&
                                        item.deliveryPrice! > 0)
                                      Text(
                                        '外卖价 ${i18n.formatMoney(item.deliveryPrice!)}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: const Color(0xFF1565C0),
                                            ),
                                      ),
                                    if ((item.description ?? '')
                                        .trim()
                                        .isNotEmpty)
                                      Text(
                                        item.description!.trim(),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    if (item.hasPromotion)
                                      const Text(
                                        '促销中',
                                        style: TextStyle(
                                          color: Color(0xFFD32F2F),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              _StatusBadge(
                                label: item.isActive
                                    ? i18n.activeOnly
                                    : i18n.inactiveOnly,
                                color: item.isActive
                                    ? const Color(0xFF2E7D32)
                                    : const Color(0xFFC62828),
                              ),
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed: () => _openEditDialog(item),
                                child: Text(i18n.editProduct),
                              ),
                              if (widget.controller.isAdmin)
                                TextButton.icon(
                                  onPressed: () => _deleteProduct(item),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.red,
                                  ),
                                  icon: const Icon(Icons.warning_amber_rounded),
                                  label: Text(_t('删除', 'ลบ', 'Delete')),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAddDialog() async {
    if (_categories.isEmpty) {
      showLatestSnackBar(context, widget.i18n.addCategoryFirst);
      return;
    }
    final data = await _showEditDialog(
      categories: _uniqueCategoryValues(_categories.map((e) => e.name)),
    );
    if (data == null) return;
    try {
      await widget.controller.createProduct(
        name: data.name,
        category: data.category,
        price: data.price,
        deliveryPrice: data.deliveryPrice,
        promoType: data.promoType.code,
        promoValue: data.promoValue,
        promoActive: data.promoActive,
        nameTh: data.nameTh,
        nameZh: data.nameZh,
        nameEn: data.nameEn,
        description: data.description,
        imageUrl: data.imageUrl,
        showSize: data.showSize,
        showSugar: data.showSugar,
        showIce: data.showIce,
        showToppings: data.showToppings,
      );
      await _loadProducts();
      if (!mounted) return;
      showLatestSnackBar(context, widget.i18n.productSaved);
    } catch (e) {
      if (!mounted) return;
      showLatestSnackBar(context, '${widget.i18n.saveFailed}: $e');
    }
  }

  Future<void> _openEditDialog(Product item) async {
    final categories = _uniqueCategoryValues(_categories.map((e) => e.name));
    if (!categories.contains(item.category)) {
      categories.add(item.category);
    }
    final data = await _showEditDialog(product: item, categories: categories);
    if (data == null) return;
    try {
      await widget.controller.updateProduct(
        id: item.id,
        name: data.name,
        category: data.category,
        price: data.price,
        deliveryPrice: data.deliveryPrice,
        promoType: data.promoType.code,
        promoValue: data.promoValue,
        promoActive: data.promoActive,
        nameTh: data.nameTh,
        nameZh: data.nameZh,
        nameEn: data.nameEn,
        description: data.description,
        imageUrl: data.imageUrl,
        showSize: data.showSize,
        showSugar: data.showSugar,
        showIce: data.showIce,
        showToppings: data.showToppings,
      );
      if (data.isActive != item.isActive) {
        await widget.controller.setProductActive(item.id, data.isActive);
      }
      await _loadProducts();
      if (!mounted) return;
      showLatestSnackBar(context, widget.i18n.productSaved);
    } catch (e) {
      if (!mounted) return;
      showLatestSnackBar(context, '${widget.i18n.saveFailed}: $e');
    }
  }

  Future<void> _deleteProduct(Product item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text(_t('删除商品', 'ลบสินค้า', 'Delete Product')),
          ],
        ),
        content: Text(
          '${_t('确认删除', 'ยืนยันการลบ', 'Delete')}「${item.localizedName(widget.i18n.language.name)}」?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(widget.i18n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(widget.i18n.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final adminPin = await widget.controller.settingsStore.loadAdminPin();
    if (!mounted) return;
    final inputPin = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _DeletePinDialog(i18n: widget.i18n),
    );
    if (!mounted) return;
    if (inputPin == null) return;
    if (inputPin != adminPin) {
      showLatestSnackBar(context, widget.i18n.permissionDenied);
      return;
    }
    try {
      await widget.controller.deleteProduct(item.id);
      await _loadProducts();
      if (!mounted) return;
      showLatestSnackBar(
        context,
        _t('商品已删除', 'ลบสินค้าแล้ว', 'Product deleted'),
      );
    } catch (e) {
      if (!mounted) return;
      showLatestSnackBar(
        context,
        '${_t('删除失败', 'ลบไม่สำเร็จ', 'Delete failed')}: $e',
      );
    }
  }

  String _t(String zh, String th, String en) {
    return switch (widget.i18n.language) {
      AppLanguage.th => th,
      AppLanguage.en => en,
      AppLanguage.zh => zh,
    };
  }

  Future<_ProductEditData?> _showEditDialog({
    Product? product,
    required List<String> categories,
  }) async {
    return showDialog<_ProductEditData>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ProductEditDialog(
        i18n: widget.i18n,
        controller: widget.controller,
        product: product,
        categories: categories,
      ),
    );
  }

  bool _isLegacyToppingCategory(String category) => category.trim() == '加料';

  List<String> _uniqueCategoryValues(Iterable<String> source) {
    final seen = <String>{};
    final values = <String>[];
    for (final raw in source) {
      final value = raw.trim();
      if (value.isEmpty) continue;
      if (seen.add(value)) {
        values.add(value);
      }
    }
    return values;
  }
}

class _ProductEditDialog extends StatefulWidget {
  const _ProductEditDialog({
    required this.i18n,
    required this.controller,
    required this.categories,
    this.product,
  });

  final AppI18n i18n;
  final PosController controller;
  final Product? product;
  final List<String> categories;

  @override
  State<_ProductEditDialog> createState() => _ProductEditDialogState();
}

class _DeletePinDialog extends StatefulWidget {
  const _DeletePinDialog({required this.i18n});

  final AppI18n i18n;

  @override
  State<_DeletePinDialog> createState() => _DeletePinDialogState();
}

class _DeletePinDialogState extends State<_DeletePinDialog> {
  late final TextEditingController _pinController;
  String? _error;

  @override
  void initState() {
    super.initState();
    _pinController = TextEditingController();
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String t(String zh, String th, String en) => switch (widget.i18n.language) {
      AppLanguage.th => th,
      AppLanguage.en => en,
      AppLanguage.zh => zh,
    };
    return AlertDialog(
      scrollable: true,
      title: Text(t('输入管理员 PIN', 'กรอกรหัสผู้ดูแล', 'Enter Admin PIN')),
      content: SizedBox(
        width: 320,
        child: TextField(
          controller: _pinController,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 8,
          autofocus: true,
          decoration: InputDecoration(
            labelText: widget.i18n.adminPinHint,
            errorText: _error,
          ),
          onSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.i18n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.i18n.confirm)),
      ],
    );
  }

  void _submit() {
    final pin = _pinController.text.trim();
    if (pin.isEmpty) {
      setState(() => _error = t('请输入PIN', 'กรุณากรอก PIN', 'Please enter PIN'));
      return;
    }
    Navigator.of(context).pop(pin);
  }

  String t(String zh, String th, String en) {
    return switch (widget.i18n.language) {
      AppLanguage.th => th,
      AppLanguage.en => en,
      AppLanguage.zh => zh,
    };
  }
}

class _ProductEditDialogState extends State<_ProductEditDialog> {
  late final TextEditingController _nameZhController;
  late final TextEditingController _nameThController;
  late final TextEditingController _nameEnController;
  late final TextEditingController _priceController;
  late final TextEditingController _deliveryPriceController;
  late final TextEditingController _promoValueController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _imageUrlController;
  late String _selectedCategory;
  late ProductPromoType _promoType;
  late bool _promoActive;
  late bool _showSize;
  late bool _showSugar;
  late bool _showIce;
  late bool _showToppings;
  late bool _isActive;
  bool _isUploadingImage = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _nameZhController = TextEditingController(
      text: widget.product?.nameZh ?? widget.product?.name ?? '',
    );
    _nameThController = TextEditingController(
      text: widget.product?.nameTh ?? '',
    );
    _nameEnController = TextEditingController(
      text: widget.product?.nameEn ?? '',
    );
    _priceController = TextEditingController(
      text: widget.product == null
          ? ''
          : widget.product!.price.toStringAsFixed(0),
    );
    _deliveryPriceController = TextEditingController(
      text: widget.product?.deliveryPrice == null
          ? ''
          : widget.product!.deliveryPrice!.toStringAsFixed(0),
    );
    _promoValueController = TextEditingController(
      text: widget.product != null && widget.product!.promoValue > 0
          ? widget.product!.promoValue.toStringAsFixed(0)
          : '',
    );
    _descriptionController = TextEditingController(
      text: widget.product?.description ?? '',
    );
    _imageUrlController = TextEditingController(
      text: widget.product?.imageUrl ?? '',
    );
    if (widget.product != null) {
      _selectedCategory = widget.product!.category;
    } else if (widget.categories.isNotEmpty) {
      _selectedCategory = widget.categories.first;
    } else {
      _selectedCategory = '';
    }
    _showSize = widget.product?.showSize ?? true;
    final initialPromoType = widget.product?.promoType ?? ProductPromoType.none;
    _promoType = initialPromoType == ProductPromoType.none
        ? ProductPromoType.percentage
        : initialPromoType;
    _promoActive = widget.product?.hasPromotion ?? false;
    _showSugar = widget.product?.showSugar ?? true;
    _showIce = widget.product?.showIce ?? true;
    _showToppings = widget.product?.showToppings ?? true;
    _isActive = widget.product?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameZhController.dispose();
    _nameThController.dispose();
    _nameEnController.dispose();
    _priceController.dispose();
    _deliveryPriceController.dispose();
    _promoValueController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final i18n = widget.i18n;
    String t(String zh, String th, String en) => switch (i18n.language) {
      AppLanguage.th => th,
      AppLanguage.en => en,
      AppLanguage.zh => zh,
    };
    final uniqueCategories = _uniqueCategoryValues(widget.categories);
    final selectedCategoryValue = uniqueCategories.contains(_selectedCategory)
        ? _selectedCategory
        : null;
    final viewInsetsBottom = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;
    final maxDialogContentHeight = (screenHeight - viewInsetsBottom - 220)
        .clamp(220.0, screenHeight * 0.78)
        .toDouble();
    return AlertDialog(
      scrollable: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(widget.product == null ? i18n.addProduct : i18n.editProduct),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxDialogContentHeight),
        child: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _nameZhController,
                  decoration: InputDecoration(
                    labelText: '${i18n.productName} (中文)',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _nameThController,
                        decoration: InputDecoration(
                          labelText: '${i18n.productName} (ไทย)',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _nameEnController,
                        decoration: InputDecoration(
                          labelText: '${i18n.productName} (EN)',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _imageUrlController,
                  decoration: InputDecoration(
                    labelText: i18n.productImageUrl,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _isUploadingImage ? null : _pickImage,
                    icon: const Icon(Icons.image_outlined),
                    label: Text(
                      _isUploadingImage
                          ? t('上传中...', 'กำลังอัปโหลด...', 'Uploading...')
                          : t(
                              '选择并上传图片',
                              'เลือกและอัปโหลดรูป',
                              'Select & Upload Image',
                            ),
                    ),
                  ),
                ),
                if (_isUploadingImage) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        t(
                          '图片上传中，请稍候...',
                          'กำลังอัปโหลดรูป โปรดรอสักครู่...',
                          'Uploading image, please wait...',
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: _descriptionController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: i18n.productDescription,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    SizedBox(
                      width: 180,
                      child: DropdownButtonFormField<String>(
                        initialValue: selectedCategoryValue,
                        decoration: InputDecoration(
                          labelText: i18n.productCategory,
                          border: const OutlineInputBorder(),
                        ),
                        items: uniqueCategories
                            .map(
                              (category) => DropdownMenuItem(
                                value: category,
                                child: Text(
                                  widget.controller.categoryDisplayLabel(
                                    category,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _selectedCategory = value);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _priceController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: i18n.productPrice,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _deliveryPriceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: t(
                      '外卖价（可选，不填则跟店内价一致）',
                      'ราคาเดลิเวอรี่ (ไม่บังคับ)',
                      'Delivery price (optional)',
                    ),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8F1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFE0B2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          t('启用促销活动', 'เปิดโปรโมชันสินค้า', 'Enable Promotion'),
                        ),
                        subtitle: Text(
                          t(
                            '支持百分比折扣或固定减价',
                            'รองรับส่วนลด % หรือจำนวนเงินคงที่',
                            'Support percent or fixed discount',
                          ),
                        ),
                        value: _promoActive,
                        onChanged: (value) => setState(() {
                          _promoActive = value;
                          if (_promoActive &&
                              _promoType == ProductPromoType.none) {
                            _promoType = ProductPromoType.percentage;
                          }
                        }),
                      ),
                      if (_promoActive) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<ProductPromoType>(
                                initialValue: _promoType,
                                decoration: InputDecoration(
                                  labelText: t(
                                    '促销类型',
                                    'ประเภทโปรโมชัน',
                                    'Promotion Type',
                                  ),
                                  border: OutlineInputBorder(),
                                ),
                                items: [
                                  DropdownMenuItem(
                                    value: ProductPromoType.percentage,
                                    child: Text(
                                      t('折扣 (%)', 'ส่วนลด (%)', 'Discount (%)'),
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: ProductPromoType.amount,
                                    child: Text(
                                      t(
                                        '直减 (฿)',
                                        'ลดทันที (฿)',
                                        'Flat off (฿)',
                                      ),
                                    ),
                                  ),
                                ],
                                onChanged: (value) {
                                  if (value == null) return;
                                  setState(() => _promoType = value);
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _promoValueController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: InputDecoration(
                                  labelText:
                                      _promoType == ProductPromoType.amount
                                      ? t(
                                          '减价金额',
                                          'จำนวนเงินที่ลด',
                                          'Discount amount',
                                        )
                                      : t(
                                          '折扣比例',
                                          'เปอร์เซ็นต์ส่วนลด',
                                          'Discount percent',
                                        ),
                                  suffixText:
                                      _promoType == ProductPromoType.amount
                                      ? '฿'
                                      : '%',
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (widget.product != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7FAFE),
                      border: Border.all(color: const Color(0xFFE3EEF9)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: SwitchListTile(
                      title: Text(t('商品状态', 'สถานะสินค้า', 'Product Status')),
                      subtitle: Text(
                        _isActive ? i18n.activate : i18n.deactivate,
                      ),
                      value: _isActive,
                      onChanged: (value) => setState(() => _isActive = value),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F9FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFD6E9FF)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            i18n.options,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0D47A1),
                            ),
                          ),
                          const Spacer(),
                          OutlinedButton.icon(
                            onPressed: () =>
                                _openSpecDetails(SpecGroupKey.size),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF1565C0),
                              side: const BorderSide(
                                color: Color(0xFF90CAF9),
                                width: 1.2,
                              ),
                              shape: const StadiumBorder(),
                              visualDensity: VisualDensity.compact,
                            ),
                            icon: const Icon(Icons.tune, size: 18),
                            label: Text(i18n.details),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _SpecToggleChip(
                            label: i18n.size,
                            selected: _showSize,
                            onSelected: (value) =>
                                setState(() => _showSize = value),
                          ),
                          _SpecToggleChip(
                            label: i18n.sugar,
                            selected: _showSugar,
                            onSelected: (value) =>
                                setState(() => _showSugar = value),
                          ),
                          _SpecToggleChip(
                            label: i18n.ice,
                            selected: _showIce,
                            onSelected: (value) =>
                                setState(() => _showIce = value),
                          ),
                          _SpecToggleChip(
                            label: i18n.toppings,
                            selected: _showToppings,
                            onSelected: (value) =>
                                setState(() => _showToppings = value),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (_errorText != null) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _errorText!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isUploadingImage ? null : () => Navigator.pop(context),
          child: Text(i18n.cancel),
        ),
        FilledButton(
          onPressed: _isUploadingImage
              ? null
              : () {
                  final nameZh = _nameZhController.text.trim();
                  final nameTh = _nameThController.text.trim();
                  final nameEn = _nameEnController.text.trim();
                  final description = _descriptionController.text.trim();
                  final imageUrl = _imageUrlController.text.trim();
                  final normalizedPrice = _priceController.text
                      .trim()
                      .replaceAll(',', '.');
                  final normalizedPromoValue = _promoValueController.text
                      .trim()
                      .replaceAll(',', '.');
                  final normalizedDeliveryPrice = _deliveryPriceController.text
                      .trim()
                      .replaceAll(',', '.');
                  final parsed = double.tryParse(normalizedPrice);
                  final parsedDelivery = normalizedDeliveryPrice.isEmpty
                      ? null
                      : double.tryParse(normalizedDeliveryPrice);
                  final promoValue = _promoActive
                      ? (double.tryParse(normalizedPromoValue) ?? -1.0)
                      : 0.0;
                  final fallbackName = nameZh.isNotEmpty
                      ? nameZh
                      : (nameTh.isNotEmpty
                            ? nameTh
                            : (nameEn.isNotEmpty ? nameEn : ''));
                  if (fallbackName.isEmpty ||
                      _selectedCategory.isEmpty ||
                      parsed == null ||
                      parsed <= 0 ||
                      (parsedDelivery != null && parsedDelivery <= 0) ||
                      (_promoActive &&
                          (promoValue <= 0 ||
                              (_promoType == ProductPromoType.percentage &&
                                  promoValue > 100) ||
                              (_promoType == ProductPromoType.amount &&
                                  promoValue >= parsed)))) {
                    setState(() => _errorText = i18n.saveFailed);
                    return;
                  }
                  Navigator.pop(
                    context,
                    _ProductEditData(
                      name: fallbackName,
                      category: _selectedCategory,
                      price: parsed,
                      deliveryPrice: parsedDelivery,
                      promoType: _promoActive
                          ? _promoType
                          : ProductPromoType.none,
                      promoValue: _promoActive ? promoValue : 0.0,
                      promoActive: _promoActive,
                      nameZh: nameZh,
                      nameTh: nameTh,
                      nameEn: nameEn,
                      description: description,
                      imageUrl: imageUrl,
                      showSize: _showSize,
                      showSugar: _showSugar,
                      showIce: _showIce,
                      showToppings: _showToppings,
                      isActive: _isActive,
                    ),
                  );
                },
          child: Text(i18n.save),
        ),
      ],
    );
  }

  Future<void> _pickImage() async {
    String t(String zh, String th, String en) => switch (widget.i18n.language) {
      AppLanguage.th => th,
      AppLanguage.en => en,
      AppLanguage.zh => zh,
    };
    try {
      if (kIsWeb) {
        if (!mounted) return;
        setState(
          () => _errorText = t(
            'Web 端暂不支持直传，请手动填写图片链接。',
            'Web ยังไม่รองรับอัปโหลดตรง กรุณาใส่ลิงก์รูปภาพเอง',
            'Web direct upload is not supported. Please input image URL manually.',
          ),
        );
        return;
      }
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
      );
      final sourcePath = picked?.path;
      if (sourcePath == null || sourcePath.trim().isEmpty) return;
      final baseUrl = await widget.controller.settingsStore
          .loadUploadApiBaseUrl();
      if (baseUrl == null || baseUrl.trim().isEmpty) {
        if (!mounted) return;
        setState(() {
          _errorText = t(
            '请先到设置页填写 Upload API Base URL。',
            'กรุณาตั้งค่า Upload API Base URL ในหน้าตั้งค่าก่อน',
            'Please set Upload API Base URL in Settings first.',
          );
        });
        return;
      }
      if (!mounted) return;
      setState(() {
        _isUploadingImage = true;
        _errorText = null;
      });
      final service = const ImageUploadService();
      final publicUrl = await service.uploadProductImage(
        file: File(sourcePath),
        apiBaseUrl: baseUrl,
      );
      _imageUrlController.text = publicUrl;
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isUploadingImage = false;
        _errorText = '$e';
      });
    }
  }

  Future<void> _openSpecDetails(String groupKey) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SpecManagementPage(
          controller: widget.controller,
          initialGroupKey: groupKey,
        ),
      ),
    );
  }

  List<String> _uniqueCategoryValues(Iterable<String> source) {
    final seen = <String>{};
    final values = <String>[];
    for (final raw in source) {
      final value = raw.trim();
      if (value.isEmpty) continue;
      if (seen.add(value)) {
        values.add(value);
      }
    }
    return values;
  }
}

class _ProductEditData {
  const _ProductEditData({
    required this.name,
    required this.category,
    required this.price,
    this.deliveryPrice,
    this.promoType = ProductPromoType.none,
    this.promoValue = 0,
    this.promoActive = false,
    this.nameTh,
    this.nameZh,
    this.nameEn,
    this.description,
    this.imageUrl,
    this.showSize = true,
    this.showSugar = true,
    this.showIce = true,
    this.showToppings = true,
    this.isActive = true,
  });

  final String name;
  final String category;
  final double price;
  final double? deliveryPrice;
  final ProductPromoType promoType;
  final double promoValue;
  final bool promoActive;
  final String? nameTh;
  final String? nameZh;
  final String? nameEn;
  final String? description;
  final String? imageUrl;
  final bool showSize;
  final bool showSugar;
  final bool showIce;
  final bool showToppings;
  final bool isActive;
}

class _SpecToggleChip extends StatelessWidget {
  const _SpecToggleChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      selectedColor: const Color(0xFF1976D2),
      backgroundColor: Colors.white,
      side: const BorderSide(color: Color(0xFF90CAF9), width: 1.2),
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: selected ? Colors.white : const Color(0xFF0D47A1),
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ProductThumb extends StatelessWidget {
  const _ProductThumb({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final raw = imageUrl?.trim() ?? '';
    if (raw.isEmpty) {
      return Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFFF0F6FD),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE3EEF9)),
        ),
        child: const Icon(Icons.local_drink_outlined, color: Color(0xFF90A4AE)),
      );
    }

    final isHttp = raw.startsWith('http://') || raw.startsWith('https://');
    if (!isHttp) {
      if (!kIsWeb) {
        return Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE3EEF9)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.file(
            File(raw),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              color: const Color(0xFFF0F6FD),
              child: const Icon(
                Icons.broken_image_outlined,
                color: Color(0xFF90A4AE),
              ),
            ),
          ),
        );
      }
      return Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFFF0F6FD),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE3EEF9)),
        ),
        child: const Icon(Icons.image_outlined, color: Color(0xFF90A4AE)),
      );
    }
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE3EEF9)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image(
        image: NetworkImage(raw),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: const Color(0xFFF0F6FD),
          child: const Icon(
            Icons.broken_image_outlined,
            color: Color(0xFF90A4AE),
          ),
        ),
      ),
    );
  }
}
