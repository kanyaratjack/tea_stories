import 'dart:ui';

import 'package:intl/intl.dart';

import '../state/pos_controller.dart';

enum AppLanguage { th, zh, en }

class AppI18n {
  const AppI18n(this.language);

  final AppLanguage language;

  static const String allCategoryKey = '__all__';

  Locale get locale => switch (language) {
    AppLanguage.th => const Locale('th'),
    AppLanguage.zh => const Locale('zh'),
    AppLanguage.en => const Locale('en'),
  };

  String get localeCode => switch (language) {
    AppLanguage.th => 'th_TH',
    AppLanguage.zh => 'zh_CN',
    AppLanguage.en => 'en_US',
  };

  String get appTitle => _t('appTitle');

  String get posTitle => _t('posTitle');

  String get productsUnit => _t('productsUnit');
  String get orderManagement => _t('orderManagement');
  String get productManagement => _t('productManagement');
  String get promotionManagement => _t('promotionManagement');
  String get specManagement => _t('specManagement');
  String get statistics => _t('statistics');
  String get categoryManagement => _t('categoryManagement');
  String get settings => _t('settings');
  String get role => _t('role');
  String get roleAdmin => _t('roleAdmin');
  String get roleClerk => _t('roleClerk');
  String get switchToAdmin => _t('switchToAdmin');
  String get switchToClerk => _t('switchToClerk');
  String get printerSettings => _t('printerSettings');
  String get directPrint => _t('directPrint');
  String get autoPrintReceipt => _t('autoPrintReceipt');
  String get autoOpenCashDrawer => _t('autoOpenCashDrawer');
  String get printerIp => _t('printerIp');
  String get testPrint => _t('testPrint');
  String get codePageTest => _t('codePageTest');
  String get codePageTestSuccess => _t('codePageTestSuccess');
  String get printerSaved => _t('printerSaved');
  String get printerNotConfigured => _t('printerNotConfigured');
  String get enterAdminPin => _t('enterAdminPin');
  String get adminPinHint => _t('adminPinHint');
  String get confirm => _t('confirm');
  String get permissionDenied => _t('permissionDenied');
  String get productName => _t('productName');
  String get productCategory => _t('productCategory');
  String get productPrice => _t('productPrice');
  String get productDescription => _t('productDescription');
  String get productImageUrl => _t('productImageUrl');
  String get addProduct => _t('addProduct');
  String get editProduct => _t('editProduct');
  String get activate => _t('activate');
  String get deactivate => _t('deactivate');
  String get activeOnly => _t('activeOnly');
  String get inactiveOnly => _t('inactiveOnly');
  String get allStatus => _t('allStatus');
  String get searchProductHint => _t('searchProductHint');
  String get saveFailed => _t('saveFailed');
  String get productSaved => _t('productSaved');
  String get addCategory => _t('addCategory');
  String get editCategory => _t('editCategory');
  String get categorySaved => _t('categorySaved');
  String get categoryName => _t('categoryName');
  String get addCategoryFirst => _t('addCategoryFirst');

  String get cartTitle => _t('cartTitle');

  String get clear => _t('clear');

  String get emptyCartHint => _t('emptyCartHint');

  String get subtotal => _t('subtotal');

  String get productDiscount => _t('productDiscount');

  String get activityDiscount => _t('activityDiscount');

  String get discount => _t('discount');

  String get total => _t('total');

  String get cashReceived => _t('cashReceived');

  String get change => _t('change');

  String get checkout => _t('checkout');
  String get checkoutPanelTitle => _t('checkoutPanelTitle');
  String get openCheckout => _t('openCheckout');
  String get scanToPay => _t('scanToPay');
  String get offlineQrHint => _t('offlineQrHint');
  String get markPaid => _t('markPaid');
  String get suspend => _t('suspend');
  String get resume => _t('resume');
  String get refund => _t('refund');
  String get managerPin => _t('managerPin');
  String get reason => _t('reason');
  String get noSuspendedOrders => _t('noSuspendedOrders');
  String get noPaidOrders => _t('noPaidOrders');
  String get sortNewest => _t('sortNewest');
  String get sortOldest => _t('sortOldest');
  String get createdAt => _t('createdAt');
  String get details => _t('details');
  String get refundableItems => _t('refundableItems');
  String get remaining => _t('remaining');
  String get refundQty => _t('refundQty');
  String get refundTotal => _t('refundTotal');

  String get searchHint => _t('searchHint');
  String get searchOrderHint => _t('searchOrderHint');
  String get noOrders => _t('noOrders');
  String get noMoreOrders => _t('noMoreOrders');
  String get loadMore => _t('loadMore');
  String get loadingMore => _t('loadingMore');
  String get orderDetails => _t('orderDetails');
  String get recentDays => _t('recentDays');
  String get allTime => _t('allTime');
  String get today => _t('today');
  String get dailyRevenue => _t('dailyRevenue');
  String get grossRevenue => _t('grossRevenue');
  String get netRevenue => _t('netRevenue');
  String get topProducts => _t('topProducts');
  String get paymentMethodStats => _t('paymentMethodStats');
  String get orderTypeStats => _t('orderTypeStats');
  String get deliveryChannelStats => _t('deliveryChannelStats');
  String get orderCount => _t('orderCount');
  String get soldQty => _t('soldQty');
  String get rank => _t('rank');
  String get status => _t('status');
  String get unitPrice => _t('unitPrice');
  String get lineTotal => _t('lineTotal');
  String get refundRecords => _t('refundRecords');
  String get refundAmount => _t('refundAmount');
  String get refundType => _t('refundType');
  String get operatorName => _t('operatorName');

  String get noProducts => _t('noProducts');

  String get paymentTip => _t('paymentTip');

  String get cashSuccess => _t('cashSuccess');
  String get checkoutFailed => _t('checkoutFailed');
  String get printReceipt => _t('printReceipt');
  String get printLabel => _t('printLabel');
  String get printReceiptOneCopy => _t('printReceiptOneCopy');
  String get printReceiptTwoCopies => _t('printReceiptTwoCopies');
  String get previewReceipt => _t('previewReceipt');
  String get previewLabel => _t('previewLabel');
  String get receiptPreview => _t('receiptPreview');
  String get labelPreview => _t('labelPreview');
  String get printReceiptSuccess => _t('printReceiptSuccess');
  String get printReceiptFailed => _t('printReceiptFailed');
  String get openCashDrawer => _t('openCashDrawer');
  String get openCashDrawerSuccess => _t('openCashDrawerSuccess');
  String get openCashDrawerFailed => _t('openCashDrawerFailed');

  String get orderNo => _t('orderNo');
  String get pickupNo => _t('pickupNo');

  String get paymentMethod => _t('paymentMethod');
  String get orderType => _t('orderType');
  String get orderChannel => _t('orderChannel');
  String get platformOrderId => _t('platformOrderId');
  String get platformOrderIdHint => _t('platformOrderIdHint');
  String get deliveryPlatformDiscount => _t('deliveryPlatformDiscount');
  String get deliveryPlatformDiscountHint => _t('deliveryPlatformDiscountHint');
  String get deliveryChannelSettings => _t('deliveryChannelSettings');
  String get orderTypeInStore => _t('orderTypeInStore');
  String get orderTypeDelivery => _t('orderTypeDelivery');

  String get save => _t('save');

  String get cancel => _t('cancel');

  String get options => _t('options');

  String get note => _t('note');

  String get noteHint => _t('noteHint');

  String get size => _t('size');

  String get sugar => _t('sugar');

  String get ice => _t('ice');

  String get addToCart => _t('addToCart');
  String get toppings => _t('toppings');
  String get noToppings => _t('noToppings');

  String get editItem => _t('editItem');

  String get allCategory => _t('allCategory');

  String get retry => _t('retry');
  String get reset => _t('reset');

  String get startupFailed => _t('startupFailed');
  String get loadTimeoutRetry => _t('loadTimeoutRetry');
  String get refundTimeoutRetry => _t('refundTimeoutRetry');
  String get refundConfirmTitle => _t('refundConfirmTitle');
  String get refundConfirmHint => _t('refundConfirmHint');
  String get selectedItems => _t('selectedItems');

  String get unsupportedWeb => _t('unsupportedWeb');

  String categoryLabel(String category) {
    final key = category.trim();
    if (key.isEmpty) return category;
    const categoryMap = {
      '奶茶': ('ชานม', 'Milk Tea'),
      '纯茶': ('ชาล้วน', 'Pure Tea'),
      '果茶': ('ชาผลไม้', 'Fruit Tea'),
      '鲜奶': ('นมสด', 'Fresh Milk'),
      '加料': ('ท็อปปิ้ง', 'Topping'),
    };
    final value = categoryMap[key];
    if (value == null) return category;
    return switch (language) {
      AppLanguage.th => value.$1,
      AppLanguage.zh => key,
      AppLanguage.en => value.$2,
    };
  }

  String getLanguageLabel(AppLanguage lang) => switch (lang) {
    AppLanguage.th => _t('langTh'),
    AppLanguage.zh => _t('langZh'),
    AppLanguage.en => _t('langEn'),
  };

  String paymentLabel(PaymentMethod method) => switch (method) {
    PaymentMethod.cash => _t('paymentCash'),
    PaymentMethod.wechat => _t('paymentWechat'),
    PaymentMethod.alipay => _t('paymentAlipay'),
    PaymentMethod.promptPayQr => _t('paymentPromptPayQr'),
    PaymentMethod.trueMoneyQr => _t('paymentTrueMoneyQr'),
    PaymentMethod.card => _t('paymentCard'),
    PaymentMethod.deliveryApp => _t('paymentDeliveryApp'),
  };

  String paymentLabelByCode(String code) {
    switch (code) {
      case 'cash':
        return _t('paymentCash');
      case 'wechat':
        return _t('paymentWechat');
      case 'alipay':
        return _t('paymentAlipay');
      case 'promptPayQr':
        return _t('paymentPromptPayQr');
      case 'trueMoneyQr':
        return _t('paymentTrueMoneyQr');
      case 'card':
        return _t('paymentCard');
      case 'deliveryApp':
        return _t('paymentDeliveryApp');
      default:
        return code;
    }
  }

  String orderTypeLabelByCode(String code) {
    switch (code) {
      case 'inStore':
        return orderTypeInStore;
      case 'delivery':
        return orderTypeDelivery;
      default:
        return code;
    }
  }

  String sizeLabel(String value) => _legacyLabel(value, {
    'medium': _t('sizeMedium'),
    'large': _t('sizeLarge'),
  });

  String sugarLabel(String value) => _legacyLabel(value, {
    'full': _t('sugarFull'),
    'normal': _t('sugarNormal'),
    'less': _t('sugarLess'),
    'zero': _t('sugarZero'),
  });

  String iceLabel(String value) => _legacyLabel(value, {
    'normal': _t('iceNormal'),
    'less': _t('iceLess'),
    'noIce': _t('iceNoIce'),
    'hot': _t('iceHot'),
  });

  String formatMoney(num value) {
    final formatter = NumberFormat.currency(
      locale: localeCode,
      symbol: '฿',
      decimalDigits: 0,
    );
    return formatter.format(value);
  }

  String _t(String key) => _localizedValues[language]![key] ?? key;

  String _legacyLabel(String value, Map<String, String> mapping) {
    final key = value.trim();
    return mapping[key] ?? value;
  }

  String orderStatusLabel(String status) => switch (status) {
    'paid' => _t('orderStatusPaid'),
    'partially_refunded' => _t('orderStatusPartiallyRefunded'),
    'refunded' => _t('orderStatusRefunded'),
    _ => status,
  };

  String refundTypeLabel(String type) => switch (type) {
    'full' => _t('refundTypeFull'),
    'partial' => _t('refundTypePartial'),
    _ => type,
  };

  static const Map<AppLanguage, Map<String, String>> _localizedValues = {
    AppLanguage.th: {
      'appTitle': 'ระบบแคชเชียร์ร้านชา',
      'posTitle': 'เคาน์เตอร์ขาย',
      'productsUnit': 'รายการ',
      'orderManagement': 'จัดการออเดอร์',
      'productManagement': 'จัดการสินค้า',
      'promotionManagement': 'จัดการโปรโมชัน',
      'specManagement': 'จัดการตัวเลือกสินค้า',
      'statistics': 'สถิติ',
      'categoryManagement': 'จัดการหมวดหมู่',
      'settings': 'ตั้งค่า',
      'role': 'บทบาท',
      'roleAdmin': 'ผู้ดูแล',
      'roleClerk': 'พนักงาน',
      'switchToAdmin': 'สลับเป็นผู้ดูแล',
      'switchToClerk': 'สลับเป็นพนักงาน',
      'printerSettings': 'เครื่องพิมพ์',
      'directPrint': 'พิมพ์ตรงผ่าน IP/Port',
      'autoPrintReceipt': 'พิมพ์ใบเสร็จอัตโนมัติหลังชำระเงิน',
      'autoOpenCashDrawer': 'เปิดลิ้นชักเก็บเงินอัตโนมัติ (เงินสด)',
      'printerIp': 'IP เครื่องพิมพ์',
      'testPrint': 'ทดสอบพิมพ์',
      'codePageTest': 'ทดสอบรหัสภาษาไทย',
      'codePageTestSuccess': 'ส่งงานพิมพ์ทดสอบรหัสแล้ว',
      'printerSaved': 'บันทึกการตั้งค่าเครื่องพิมพ์แล้ว',
      'printerNotConfigured': 'กรุณากรอก IP เครื่องพิมพ์',
      'enterAdminPin': 'กรอกรหัสผู้ดูแล',
      'adminPinHint': 'PIN ผู้ดูแล',
      'confirm': 'ยืนยัน',
      'permissionDenied': 'ไม่มีสิทธิ์ดำเนินการ',
      'productName': 'ชื่อสินค้า',
      'productCategory': 'หมวดหมู่',
      'productPrice': 'ราคา',
      'productDescription': 'รายละเอียดสินค้า',
      'productImageUrl': 'ลิงก์/พาธรูปภาพ',
      'addProduct': 'เพิ่มสินค้า',
      'editProduct': 'แก้ไขสินค้า',
      'activate': 'เปิดขาย',
      'deactivate': 'ปิดขาย',
      'activeOnly': 'ขายอยู่',
      'inactiveOnly': 'ปิดขาย',
      'allStatus': 'ทั้งหมด',
      'searchProductHint': 'ค้นหาสินค้า/หมวดหมู่',
      'saveFailed': 'บันทึกไม่สำเร็จ',
      'productSaved': 'บันทึกสินค้าแล้ว',
      'addCategory': 'เพิ่มหมวดหมู่',
      'editCategory': 'แก้ไขหมวดหมู่',
      'categorySaved': 'บันทึกหมวดหมู่แล้ว',
      'categoryName': 'ชื่อหมวดหมู่',
      'addCategoryFirst': 'กรุณาเพิ่มหมวดหมู่ก่อน',
      'cartTitle': 'ตะกร้า',
      'clear': 'ล้าง',
      'emptyCartHint': 'เลือกสินค้าก่อนเริ่มออเดอร์',
      'subtotal': 'ยอดรวม',
      'productDiscount': 'ส่วนลดสินค้า',
      'activityDiscount': 'ส่วนลดโปรโมชัน',
      'discount': 'ส่วนลด',
      'total': 'สุทธิ',
      'cashReceived': 'รับเงิน',
      'change': 'เงินทอน',
      'checkout': 'ยืนยันรับเงินและออกบิล',
      'checkoutPanelTitle': 'ชำระเงิน',
      'openCheckout': 'ไปหน้าเช็คเอาท์',
      'scanToPay': 'สแกน QR เพื่อชำระเงิน',
      'offlineQrHint':
          'ใช้ QR ของหน้าร้านในการรับเงิน เมื่อรับเงินแล้วให้กดยืนยันรับชำระ',
      'markPaid': 'ยืนยันว่าชำระแล้ว',
      'suspend': 'พักบิล',
      'resume': 'เรียกบิล',
      'refund': 'คืนเงิน',
      'managerPin': 'รหัสผู้จัดการ',
      'reason': 'เหตุผล',
      'noSuspendedOrders': 'ไม่มีบิลที่พักไว้',
      'noPaidOrders': 'ไม่มีออเดอร์ที่คืนเงินได้',
      'sortNewest': 'ล่าสุดก่อน',
      'sortOldest': 'เก่าสุดก่อน',
      'createdAt': 'เวลาสร้าง',
      'details': 'รายละเอียด',
      'refundableItems': 'รายการที่คืนเงินได้',
      'remaining': 'คงเหลือ',
      'refundQty': 'จำนวนคืน',
      'refundTotal': 'ยอดคืน',
      'searchHint': 'ค้นหาสินค้า',
      'searchOrderHint': 'ค้นหาเลขออเดอร์/รหัสแพลตฟอร์ม/ช่องทาง',
      'noOrders': 'ยังไม่มีออเดอร์',
      'noMoreOrders': 'ไม่มีออเดอร์เพิ่มเติม',
      'loadMore': 'โหลดเพิ่ม',
      'loadingMore': 'กำลังโหลด...',
      'orderDetails': 'รายละเอียดออเดอร์',
      'recentDays': 'ย้อนหลัง',
      'allTime': 'ทั้งหมด',
      'today': 'วันนี้',
      'dailyRevenue': 'รายได้รายวัน',
      'grossRevenue': 'ยอดขายรวม',
      'netRevenue': 'รายได้สุทธิ',
      'topProducts': 'สินค้าขายดี',
      'paymentMethodStats': 'สถิติช่องทางชำระเงิน',
      'orderTypeStats': 'สถิติประเภทออเดอร์',
      'deliveryChannelStats': 'สถิติช่องทางเดลิเวอรี่',
      'orderCount': 'จำนวนออเดอร์',
      'soldQty': 'จำนวนขาย',
      'rank': 'อันดับ',
      'status': 'สถานะ',
      'unitPrice': 'ราคาต่อหน่วย',
      'lineTotal': 'ยอดรวมรายการ',
      'refundRecords': 'ประวัติคืนเงิน',
      'refundAmount': 'ยอดคืน',
      'refundType': 'ประเภท',
      'operatorName': 'ผู้ดำเนินการ',
      'noProducts': 'ไม่พบสินค้า',
      'paymentTip': 'ชำระเงินสดต้องรับเงินไม่น้อยกว่ายอดสุทธิ',
      'cashSuccess': 'รับเงินสำเร็จ',
      'checkoutFailed': 'ออกบิลไม่สำเร็จ กรุณาลองใหม่',
      'printReceipt': 'พิมพ์ใบเสร็จ',
      'printLabel': 'พิมพ์ฉลาก',
      'printReceiptOneCopy': 'พิมพ์ 1 ใบ',
      'printReceiptTwoCopies': 'พิมพ์ 2 ใบ',
      'previewReceipt': 'ดูตัวอย่าง',
      'previewLabel': 'ดูตัวอย่างฉลาก',
      'receiptPreview': 'ตัวอย่างใบเสร็จ',
      'labelPreview': 'ตัวอย่างฉลาก',
      'printReceiptSuccess': 'ส่งคำสั่งพิมพ์แล้ว',
      'printReceiptFailed': 'พิมพ์ไม่สำเร็จ',
      'openCashDrawer': 'เปิดลิ้นชักเงิน',
      'openCashDrawerSuccess': 'เปิดลิ้นชักเงินแล้ว',
      'openCashDrawerFailed': 'เปิดลิ้นชักเก็บเงินไม่สำเร็จ',
      'orderNo': 'เลขออเดอร์',
      'pickupNo': 'หมายเลขเรียกคิว',
      'orderStatusPaid': 'ชำระแล้ว',
      'orderStatusPartiallyRefunded': 'คืนเงินบางส่วน',
      'orderStatusRefunded': 'คืนเงินแล้ว',
      'refundTypeFull': 'คืนเต็มจำนวน',
      'refundTypePartial': 'คืนบางส่วน',
      'paymentMethod': 'ช่องทางชำระเงิน',
      'orderType': 'ประเภทออเดอร์',
      'orderChannel': 'ช่องทางเดลิเวอรี่',
      'platformOrderId': 'รหัสคำสั่งซื้อแพลตฟอร์ม',
      'platformOrderIdHint': 'เช่น GRAB-20260210-0001',
      'deliveryPlatformDiscount': 'ส่วนลดจากแพลตฟอร์ม',
      'deliveryPlatformDiscountHint': 'เช่น 10',
      'deliveryChannelSettings': 'ตั้งค่าช่องทางเดลิเวอรี่',
      'orderTypeInStore': 'หน้าร้าน',
      'orderTypeDelivery': 'เดลิเวอรี่',
      'save': 'บันทึก',
      'cancel': 'ยกเลิก',
      'options': 'ตัวเลือก',
      'note': 'หมายเหตุ',
      'noteHint': 'เช่น ไม่ใส่น้ำแข็ง / ไม่เอาหลอด',
      'size': 'ขนาด',
      'sugar': 'ความหวาน',
      'ice': 'น้ำแข็ง',
      'addToCart': 'เพิ่มเข้าตะกร้า',
      'toppings': 'ท็อปปิ้ง',
      'noToppings': 'ไม่เพิ่มท็อปปิ้ง',
      'editItem': 'แก้ไข',
      'allCategory': 'ทั้งหมด',
      'retry': 'ลองใหม่',
      'reset': 'รีเซ็ต',
      'startupFailed': 'เริ่มระบบไม่สำเร็จ: ฐานข้อมูลผิดพลาด',
      'loadTimeoutRetry': 'โหลดข้อมูลหมดเวลา กรุณาลองใหม่',
      'refundTimeoutRetry': 'คืนเงินหมดเวลา กรุณาลองใหม่',
      'refundConfirmTitle': 'ยืนยันการคืนเงิน',
      'refundConfirmHint': 'โปรดตรวจสอบจำนวนและยอดเงินก่อนยืนยัน',
      'selectedItems': 'รายการที่เลือก',
      'unsupportedWeb': 'Web ไม่รองรับ sqflite กรุณาใช้ iOS/macOS',
      'langTh': 'ไทย',
      'langZh': '中文',
      'langEn': 'EN',
      'paymentCash': 'เงินสด',
      'paymentWechat': 'WeChat',
      'paymentAlipay': 'Alipay',
      'paymentPromptPayQr': 'PromptPay QR',
      'paymentTrueMoneyQr': 'TrueMoney QR',
      'paymentCard': 'บัตร',
      'paymentDeliveryApp': 'แอปเดลิเวอรี่',
      'sizeMedium': 'แก้วกลาง',
      'sizeLarge': 'แก้วใหญ่ (+2)',
      'sugarFull': 'หวานปกติ',
      'sugarNormal': 'หวานกลาง',
      'sugarLess': 'หวานน้อย',
      'sugarZero': 'ไม่หวาน',
      'iceNormal': 'น้ำแข็งปกติ',
      'iceLess': 'น้ำแข็งน้อย',
      'iceNoIce': 'ไม่ใส่น้ำแข็ง',
      'iceHot': 'ร้อน',
    },
    AppLanguage.zh: {
      'appTitle': '奶茶店收银系统',
      'posTitle': '收银台',
      'productsUnit': '个',
      'orderManagement': '订单管理',
      'productManagement': '商品管理',
      'promotionManagement': '活动管理',
      'specManagement': '规格管理',
      'statistics': '统计',
      'categoryManagement': '分类管理',
      'settings': '设置',
      'role': '角色',
      'roleAdmin': '管理员',
      'roleClerk': '店员',
      'switchToAdmin': '切换为管理员',
      'switchToClerk': '切换为店员',
      'printerSettings': '打印机',
      'directPrint': '启用 IP/端口直连打印',
      'autoPrintReceipt': '结算后自动打印小票',
      'autoOpenCashDrawer': '现金支付后自动弹开收银箱',
      'printerIp': '打印机 IP',
      'testPrint': '测试打印',
      'codePageTest': '代码页测试',
      'codePageTestSuccess': '已发送代码页测试打印',
      'printerSaved': '打印机设置已保存',
      'printerNotConfigured': '请先填写打印机 IP',
      'enterAdminPin': '输入管理员 PIN',
      'adminPinHint': '管理员 PIN',
      'confirm': '确认',
      'permissionDenied': '无权限执行此操作',
      'productName': '商品名',
      'productCategory': '分类',
      'productPrice': '价格',
      'productDescription': '商品描述',
      'productImageUrl': '图片链接/路径',
      'addProduct': '新增商品',
      'editProduct': '编辑商品',
      'activate': '恢复上架',
      'deactivate': '停售',
      'activeOnly': '上架中',
      'inactiveOnly': '仅停售',
      'allStatus': '全部状态',
      'searchProductHint': '搜索商品/分类',
      'saveFailed': '保存失败',
      'productSaved': '商品已保存',
      'addCategory': '新增分类',
      'editCategory': '编辑分类',
      'categorySaved': '分类已保存',
      'categoryName': '分类名称',
      'addCategoryFirst': '请先新增分类',
      'cartTitle': '购物车',
      'clear': '清空',
      'emptyCartHint': '请选择商品开始下单',
      'subtotal': '小计',
      'productDiscount': '折扣',
      'activityDiscount': '活动优惠',
      'discount': '优惠',
      'total': '应收',
      'cashReceived': '实收金额',
      'change': '找零',
      'checkout': '确认收款并下单',
      'checkoutPanelTitle': '结算',
      'openCheckout': '去结算',
      'scanToPay': '请扫码支付',
      'offlineQrHint': '使用门店线下二维码收款，收款完成后点击“确认已收款”。',
      'markPaid': '确认已收款',
      'suspend': '挂单',
      'resume': '取单',
      'refund': '退款',
      'managerPin': '店长 PIN',
      'reason': '原因',
      'noSuspendedOrders': '暂无挂单',
      'noPaidOrders': '暂无可退款订单',
      'sortNewest': '最新优先',
      'sortOldest': '最早优先',
      'createdAt': '创建时间',
      'details': '详情',
      'refundableItems': '可退款商品',
      'remaining': '剩余',
      'refundQty': '退款数量',
      'refundTotal': '退款金额',
      'searchHint': '搜索商品',
      'searchOrderHint': '搜索订单号/平台订单ID/平台',
      'noOrders': '暂无订单',
      'noMoreOrders': '没有更多订单了',
      'loadMore': '加载更多',
      'loadingMore': '加载中...',
      'orderDetails': '订单详情',
      'recentDays': '最近天数',
      'allTime': '全部',
      'today': '当天',
      'dailyRevenue': '每日收入',
      'grossRevenue': '总销售额',
      'netRevenue': '净收入',
      'topProducts': '热销商品',
      'paymentMethodStats': '支付方式统计',
      'orderTypeStats': '订单类型统计',
      'deliveryChannelStats': '外卖平台统计',
      'orderCount': '订单数',
      'soldQty': '销量',
      'rank': '排名',
      'status': '状态',
      'unitPrice': '单价',
      'lineTotal': '小计',
      'refundRecords': '退款记录',
      'refundAmount': '退款金额',
      'refundType': '类型',
      'operatorName': '操作人',
      'noProducts': '没有匹配的商品',
      'paymentTip': '现金支付时，实收金额需大于等于应收。',
      'cashSuccess': '收款成功',
      'checkoutFailed': '下单失败，请重试',
      'printReceipt': '打印小票',
      'printLabel': '打印标签',
      'printReceiptOneCopy': '打印1张',
      'printReceiptTwoCopies': '打印2张',
      'previewReceipt': '预览小票',
      'previewLabel': '预览标签',
      'receiptPreview': '小票预览',
      'labelPreview': '标签预览',
      'printReceiptSuccess': '已发送打印任务',
      'printReceiptFailed': '打印失败',
      'openCashDrawer': '打开收银箱',
      'openCashDrawerSuccess': '已打开收银箱',
      'openCashDrawerFailed': '收银箱打开失败',
      'orderNo': '订单号',
      'pickupNo': '取餐号',
      'orderStatusPaid': '已支付',
      'orderStatusPartiallyRefunded': '部分退款',
      'orderStatusRefunded': '已退款',
      'refundTypeFull': '全额退款',
      'refundTypePartial': '部分退款',
      'paymentMethod': '支付方式',
      'orderType': '订单类型',
      'orderChannel': '外卖平台',
      'platformOrderId': '平台订单ID',
      'platformOrderIdHint': '例如 GRAB-20260210-0001',
      'deliveryPlatformDiscount': '平台优惠金额',
      'deliveryPlatformDiscountHint': '例如 10',
      'deliveryChannelSettings': '外卖平台设置',
      'orderTypeInStore': '堂食/到店',
      'orderTypeDelivery': '外卖',
      'save': '保存',
      'cancel': '取消',
      'options': '规格',
      'note': '备注',
      'noteHint': '例如：少冰、不要吸管',
      'size': '杯型',
      'sugar': '甜度',
      'ice': '冰度',
      'addToCart': '加入购物车',
      'toppings': '小料',
      'noToppings': '不加小料',
      'editItem': '规格',
      'allCategory': '全部',
      'retry': '重试',
      'reset': '重置',
      'startupFailed': '启动失败：数据库初始化异常',
      'loadTimeoutRetry': '加载超时，请重试',
      'refundTimeoutRetry': '退款超时，请重试',
      'refundConfirmTitle': '确认退款',
      'refundConfirmHint': '请再次确认退款商品数量和金额',
      'selectedItems': '已选商品',
      'unsupportedWeb': '当前运行在 Web，sqflite 不支持。请改用 iOS/macOS。',
      'langTh': 'ไทย',
      'langZh': '中文',
      'langEn': 'EN',
      'paymentCash': '现金',
      'paymentWechat': '微信',
      'paymentAlipay': '支付宝',
      'paymentPromptPayQr': 'PromptPay 扫码',
      'paymentTrueMoneyQr': 'TrueMoney 扫码',
      'paymentCard': '银行卡',
      'paymentDeliveryApp': '外卖平台',
      'sizeMedium': '中杯',
      'sizeLarge': '大杯(+2)',
      'sugarFull': '全糖',
      'sugarNormal': '正常糖',
      'sugarLess': '少糖',
      'sugarZero': '无糖',
      'iceNormal': '正常冰',
      'iceLess': '少冰',
      'iceNoIce': '去冰',
      'iceHot': '热饮',
    },
    AppLanguage.en: {
      'appTitle': 'Tea Store POS',
      'posTitle': 'POS',
      'productsUnit': 'items',
      'orderManagement': 'Orders',
      'productManagement': 'Products',
      'promotionManagement': 'Promotions',
      'specManagement': 'Spec Management',
      'statistics': 'Stats',
      'categoryManagement': 'Categories',
      'settings': 'Settings',
      'role': 'Role',
      'roleAdmin': 'Admin',
      'roleClerk': 'Clerk',
      'switchToAdmin': 'Switch to admin',
      'switchToClerk': 'Switch to clerk',
      'printerSettings': 'Printer',
      'directPrint': 'Enable direct IP/Port print',
      'autoPrintReceipt': 'Auto print receipt after checkout',
      'autoOpenCashDrawer': 'Auto open cash drawer for cash orders',
      'printerIp': 'Printer IP',
      'testPrint': 'Test print',
      'codePageTest': 'Code page test',
      'codePageTestSuccess': 'Code page test sent',
      'printerSaved': 'Printer settings saved',
      'printerNotConfigured': 'Please enter printer IP',
      'enterAdminPin': 'Enter admin PIN',
      'adminPinHint': 'Admin PIN',
      'confirm': 'Confirm',
      'permissionDenied': 'Permission denied',
      'productName': 'Product Name',
      'productCategory': 'Category',
      'productPrice': 'Price',
      'productDescription': 'Description',
      'productImageUrl': 'Image URL/Path',
      'addProduct': 'Add Product',
      'editProduct': 'Edit Product',
      'activate': 'Activate',
      'deactivate': 'Deactivate',
      'activeOnly': 'Active',
      'inactiveOnly': 'Inactive',
      'allStatus': 'All',
      'searchProductHint': 'Search product/category',
      'saveFailed': 'Save failed',
      'productSaved': 'Product saved',
      'addCategory': 'Add Category',
      'editCategory': 'Edit Category',
      'categorySaved': 'Category saved',
      'categoryName': 'Category Name',
      'addCategoryFirst': 'Please add a category first.',
      'cartTitle': 'Cart',
      'clear': 'Clear',
      'emptyCartHint': 'Select products to start an order',
      'subtotal': 'Subtotal',
      'productDiscount': 'Item Discount',
      'activityDiscount': 'Promotion Discount',
      'discount': 'Discount',
      'total': 'Total',
      'cashReceived': 'Cash Received',
      'change': 'Change',
      'checkout': 'Confirm Payment',
      'checkoutPanelTitle': 'Checkout',
      'openCheckout': 'Open Checkout',
      'scanToPay': 'Scan QR to pay',
      'offlineQrHint':
          'Use the store offline QR code to receive payment, then tap “Mark as paid”.',
      'markPaid': 'Mark as paid',
      'suspend': 'Hold',
      'resume': 'Resume',
      'refund': 'Refund',
      'managerPin': 'Manager PIN',
      'reason': 'Reason',
      'noSuspendedOrders': 'No suspended orders',
      'noPaidOrders': 'No refundable orders',
      'sortNewest': 'Newest first',
      'sortOldest': 'Oldest first',
      'createdAt': 'Created at',
      'details': 'Details',
      'refundableItems': 'Refundable items',
      'remaining': 'Remaining',
      'refundQty': 'Refund qty',
      'refundTotal': 'Refund total',
      'searchHint': 'Search products',
      'searchOrderHint': 'Search order/platform order ID/channel',
      'noOrders': 'No orders',
      'noMoreOrders': 'No more orders',
      'loadMore': 'Load more',
      'loadingMore': 'Loading...',
      'orderDetails': 'Order details',
      'recentDays': 'Recent days',
      'allTime': 'All',
      'today': 'Today',
      'dailyRevenue': 'Daily revenue',
      'grossRevenue': 'Gross revenue',
      'netRevenue': 'Net revenue',
      'topProducts': 'Top products',
      'paymentMethodStats': 'Payment method stats',
      'orderTypeStats': 'Order type stats',
      'deliveryChannelStats': 'Delivery channel stats',
      'orderCount': 'Order count',
      'soldQty': 'Sold qty',
      'rank': 'Rank',
      'status': 'Status',
      'unitPrice': 'Unit price',
      'lineTotal': 'Line total',
      'refundRecords': 'Refund records',
      'refundAmount': 'Refund amount',
      'refundType': 'Type',
      'operatorName': 'Operator',
      'noProducts': 'No matched products',
      'paymentTip': 'For cash, received amount must be >= total.',
      'cashSuccess': 'Payment successful',
      'checkoutFailed': 'Order failed. Please retry.',
      'printReceipt': 'Print Receipt',
      'printLabel': 'Print Label',
      'printReceiptOneCopy': 'Print 1 Copy',
      'printReceiptTwoCopies': 'Print 2 Copies',
      'previewReceipt': 'Preview Receipt',
      'previewLabel': 'Preview Label',
      'receiptPreview': 'Receipt Preview',
      'labelPreview': 'Label Preview',
      'printReceiptSuccess': 'Print job sent',
      'printReceiptFailed': 'Print failed',
      'openCashDrawer': 'Open Cash Drawer',
      'openCashDrawerSuccess': 'Cash drawer opened',
      'openCashDrawerFailed': 'Failed to open cash drawer',
      'orderNo': 'Order No.',
      'pickupNo': 'Pickup No.',
      'orderStatusPaid': 'Paid',
      'orderStatusPartiallyRefunded': 'Partially refunded',
      'orderStatusRefunded': 'Refunded',
      'refundTypeFull': 'Full refund',
      'refundTypePartial': 'Partial refund',
      'paymentMethod': 'Payment Method',
      'orderType': 'Order type',
      'orderChannel': 'Delivery channel',
      'platformOrderId': 'Platform order ID',
      'platformOrderIdHint': 'e.g. GRAB-20260210-0001',
      'deliveryPlatformDiscount': 'Platform discount',
      'deliveryPlatformDiscountHint': 'e.g. 10',
      'deliveryChannelSettings': 'Delivery channels',
      'orderTypeInStore': 'In-store',
      'orderTypeDelivery': 'Delivery',
      'save': 'Save',
      'cancel': 'Cancel',
      'options': 'Options',
      'note': 'Note',
      'noteHint': 'e.g. no ice / no straw',
      'size': 'Size',
      'sugar': 'Sugar',
      'ice': 'Ice',
      'addToCart': 'Add to Cart',
      'toppings': 'Toppings',
      'noToppings': 'No toppings',
      'editItem': 'Edit',
      'allCategory': 'All',
      'retry': 'Retry',
      'reset': 'Reset',
      'startupFailed': 'Startup failed: database initialization error',
      'loadTimeoutRetry': 'Loading timed out. Please retry.',
      'refundTimeoutRetry': 'Refund timed out. Please retry.',
      'refundConfirmTitle': 'Confirm refund',
      'refundConfirmHint':
          'Please review selected items and amount before confirming.',
      'selectedItems': 'Selected items',
      'unsupportedWeb':
          'Web does not support sqflite. Please run on iOS/macOS.',
      'langTh': 'ไทย',
      'langZh': '中文',
      'langEn': 'EN',
      'paymentCash': 'Cash',
      'paymentWechat': 'WeChat',
      'paymentAlipay': 'Alipay',
      'paymentPromptPayQr': 'PromptPay QR',
      'paymentTrueMoneyQr': 'TrueMoney QR',
      'paymentCard': 'Card',
      'paymentDeliveryApp': 'Delivery app',
      'sizeMedium': 'Medium',
      'sizeLarge': 'Large (+2)',
      'sugarFull': 'Full sugar',
      'sugarNormal': 'Regular sugar',
      'sugarLess': 'Less sugar',
      'sugarZero': 'No sugar',
      'iceNormal': 'Regular ice',
      'iceLess': 'Less ice',
      'iceNoIce': 'No ice',
      'iceHot': 'Hot',
    },
  };
}
