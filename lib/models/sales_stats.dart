class DailyRevenueStat {
  const DailyRevenueStat({
    required this.day,
    required this.grossAmount,
    required this.promoAmount,
    required this.refundedAmount,
    required this.netAmount,
    required this.orderCount,
  });

  final DateTime day;
  final double grossAmount;
  final double promoAmount;
  final double refundedAmount;
  final double netAmount;
  final int orderCount;

  factory DailyRevenueStat.fromMap(Map<String, Object?> map) {
    return DailyRevenueStat(
      day: DateTime.parse('${map['day']}T00:00:00'),
      grossAmount: (map['gross_amount'] as num?)?.toDouble() ?? 0,
      promoAmount: (map['promo_amount'] as num?)?.toDouble() ?? 0,
      refundedAmount: (map['refunded_amount'] as num?)?.toDouble() ?? 0,
      netAmount: (map['net_amount'] as num?)?.toDouble() ?? 0,
      orderCount: (map['order_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class ProductSalesStat {
  const ProductSalesStat({
    required this.productName,
    required this.grossQty,
    required this.refundedQty,
    required this.netQty,
    required this.grossAmount,
    required this.refundedAmount,
    required this.netAmount,
  });

  final String productName;
  final int grossQty;
  final int refundedQty;
  final int netQty;
  final double grossAmount;
  final double refundedAmount;
  final double netAmount;

  factory ProductSalesStat.fromMap(Map<String, Object?> map) {
    return ProductSalesStat(
      productName: (map['product_name'] as String?) ?? '',
      grossQty: (map['gross_qty'] as num?)?.toInt() ?? 0,
      refundedQty: (map['refunded_qty'] as num?)?.toInt() ?? 0,
      netQty: (map['net_qty'] as num?)?.toInt() ?? 0,
      grossAmount: (map['gross_amount'] as num?)?.toDouble() ?? 0,
      refundedAmount: (map['refunded_amount'] as num?)?.toDouble() ?? 0,
      netAmount: (map['net_amount'] as num?)?.toDouble() ?? 0,
    );
  }
}

class PaymentMethodStat {
  const PaymentMethodStat({
    required this.paymentMethod,
    required this.orderCount,
    required this.grossAmount,
    required this.refundedAmount,
    required this.netAmount,
  });

  final String paymentMethod;
  final int orderCount;
  final double grossAmount;
  final double refundedAmount;
  final double netAmount;

  factory PaymentMethodStat.fromMap(Map<String, Object?> map) {
    return PaymentMethodStat(
      paymentMethod: (map['payment_method'] as String?) ?? '',
      orderCount: (map['order_count'] as num?)?.toInt() ?? 0,
      grossAmount: (map['gross_amount'] as num?)?.toDouble() ?? 0,
      refundedAmount: (map['refunded_amount'] as num?)?.toDouble() ?? 0,
      netAmount: (map['net_amount'] as num?)?.toDouble() ?? 0,
    );
  }
}

class OrderTypeStat {
  const OrderTypeStat({
    required this.orderType,
    required this.orderCount,
    required this.grossAmount,
    required this.refundedAmount,
    required this.netAmount,
  });

  final String orderType;
  final int orderCount;
  final double grossAmount;
  final double refundedAmount;
  final double netAmount;

  factory OrderTypeStat.fromMap(Map<String, Object?> map) {
    return OrderTypeStat(
      orderType: (map['order_type'] as String?) ?? 'inStore',
      orderCount: (map['order_count'] as num?)?.toInt() ?? 0,
      grossAmount: (map['gross_amount'] as num?)?.toDouble() ?? 0,
      refundedAmount: (map['refunded_amount'] as num?)?.toDouble() ?? 0,
      netAmount: (map['net_amount'] as num?)?.toDouble() ?? 0,
    );
  }
}

class DeliveryChannelStat {
  const DeliveryChannelStat({
    required this.channel,
    required this.orderCount,
    required this.netAmount,
  });

  final String channel;
  final int orderCount;
  final double netAmount;

  factory DeliveryChannelStat.fromMap(Map<String, Object?> map) {
    return DeliveryChannelStat(
      channel: (map['order_channel'] as String?) ?? '',
      orderCount: (map['order_count'] as num?)?.toInt() ?? 0,
      netAmount: (map['net_amount'] as num?)?.toDouble() ?? 0,
    );
  }
}

class HourlyRevenueStat {
  const HourlyRevenueStat({
    required this.hour,
    required this.orderCount,
    required this.netAmount,
  });

  final int hour;
  final int orderCount;
  final double netAmount;

  factory HourlyRevenueStat.fromMap(Map<String, Object?> map) {
    return HourlyRevenueStat(
      hour: (map['hour'] as num?)?.toInt() ?? 0,
      orderCount: (map['order_count'] as num?)?.toInt() ?? 0,
      netAmount: (map['net_amount'] as num?)?.toDouble() ?? 0,
    );
  }
}
