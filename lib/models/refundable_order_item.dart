class RefundableOrderItem {
  const RefundableOrderItem({
    required this.orderItemId,
    required this.productName,
    required this.quantity,
    required this.refundedQuantity,
    required this.unitPrice,
  });

  final int orderItemId;
  final String productName;
  final int quantity;
  final int refundedQuantity;
  final double unitPrice;

  int get remainingQuantity => quantity - refundedQuantity;

  double lineAmount(int refundQty) => unitPrice * refundQty;

  factory RefundableOrderItem.fromMap(Map<String, Object?> map) {
    return RefundableOrderItem(
      orderItemId: map['order_item_id'] as int,
      productName: map['product_name'] as String,
      quantity: map['quantity'] as int,
      refundedQuantity: map['refunded_qty'] as int,
      unitPrice: (map['unit_price'] as num).toDouble(),
    );
  }
}
