class SuspendedOrder {
  const SuspendedOrder({
    required this.id,
    required this.ticketNo,
    required this.total,
    required this.itemCount,
    required this.createdAt,
    this.label,
  });

  final int id;
  final String ticketNo;
  final double total;
  final int itemCount;
  final DateTime createdAt;
  final String? label;

  factory SuspendedOrder.fromMap(Map<String, Object?> map) {
    return SuspendedOrder(
      id: map['id'] as int,
      ticketNo: map['ticket_no'] as String,
      total: (map['total'] as num).toDouble(),
      itemCount: map['item_count'] as int,
      createdAt: DateTime.parse(map['created_at'] as String),
      label: map['label'] as String?,
    );
  }
}
