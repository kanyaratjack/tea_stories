class OrderDetail {
  const OrderDetail({
    required this.orderNo,
    required this.pickupNo,
    required this.orderType,
    required this.orderChannel,
    required this.platformOrderId,
    required this.subtotal,
    required this.promoAmount,
    required this.discount,
    required this.total,
    required this.status,
    required this.createdAt,
    required this.paymentMethod,
    required this.cashReceived,
    required this.changeAmount,
    required this.items,
    required this.refundRecords,
  });

  final String orderNo;
  final String pickupNo;
  final String orderType;
  final String orderChannel;
  final String platformOrderId;
  final double subtotal;
  final double promoAmount;
  final double discount;
  final double total;
  final String status;
  final DateTime createdAt;
  final String paymentMethod;
  final double? cashReceived;
  final double? changeAmount;
  final List<OrderDetailItem> items;
  final List<RefundRecord> refundRecords;
}

class OrderDetailItem {
  const OrderDetailItem({
    required this.productName,
    this.productNameTh,
    this.productNameZh,
    this.productNameEn,
    required this.quantity,
    required this.refundedQuantity,
    required this.unitPrice,
    required this.lineTotal,
    required this.size,
    required this.sugar,
    required this.ice,
    required this.toppings,
    required this.note,
  });

  final String productName;
  final String? productNameTh;
  final String? productNameZh;
  final String? productNameEn;
  final int quantity;
  final int refundedQuantity;
  final double unitPrice;
  final double lineTotal;
  final String size;
  final String sugar;
  final String ice;
  final String toppings;
  final String note;

  int get remainingQuantity => quantity - refundedQuantity;
  bool get isFullyRefunded => remainingQuantity <= 0;

  String localizedName(String languageCode) {
    final th = productNameTh?.trim();
    final zh = productNameZh?.trim();
    final en = productNameEn?.trim();
    final base = productName.trim();
    if (languageCode == 'th' && th != null && th.isNotEmpty) return th;
    if (languageCode == 'zh' && zh != null && zh.isNotEmpty) return zh;
    if (languageCode == 'en' && en != null && en.isNotEmpty) return en;
    if (zh != null && zh.isNotEmpty) return zh;
    if (th != null && th.isNotEmpty) return th;
    if (en != null && en.isNotEmpty) return en;
    return base;
  }
}

class RefundRecord {
  const RefundRecord({
    required this.amount,
    required this.refundType,
    required this.reason,
    required this.operatorName,
    required this.createdAt,
  });

  final double amount;
  final String refundType;
  final String reason;
  final String operatorName;
  final DateTime createdAt;
}
