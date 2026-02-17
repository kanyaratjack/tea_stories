class PaidOrder {
  const PaidOrder({
    required this.orderNo,
    required this.pickupNo,
    required this.orderType,
    required this.orderChannel,
    required this.platformOrderId,
    required this.total,
    required this.refundedAmount,
    required this.createdAt,
    required this.status,
  });

  final String orderNo;
  final String pickupNo;
  final String orderType;
  final String orderChannel;
  final String platformOrderId;
  final double total;
  final double refundedAmount;
  final DateTime createdAt;
  final String status;
  double get actualAmount => (total - refundedAmount).clamp(0, double.infinity);

  factory PaidOrder.fromMap(Map<String, Object?> map) {
    return PaidOrder(
      orderNo: map['order_no'] as String,
      pickupNo: (map['pickup_no'] as String?) ?? '',
      orderType: (map['order_type'] as String?) ?? 'inStore',
      orderChannel: (map['order_channel'] as String?) ?? '',
      platformOrderId: (map['platform_order_id'] as String?) ?? '',
      total: (map['total'] as num).toDouble(),
      refundedAmount: (map['refunded_amount'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
      status: (map['status'] as String?) ?? 'paid',
    );
  }
}
