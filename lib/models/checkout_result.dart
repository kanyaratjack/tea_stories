class CheckoutResult {
  const CheckoutResult({
    required this.orderNo,
    required this.pickupNo,
    required this.orderType,
    required this.orderChannel,
    required this.platformOrderId,
  });

  final String orderNo;
  final String pickupNo;
  final String orderType;
  final String orderChannel;
  final String platformOrderId;
}
