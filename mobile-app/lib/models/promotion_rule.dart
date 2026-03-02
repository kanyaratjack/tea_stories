import 'dart:convert';

enum PromotionType { comboPrice, fullReduce, nthDiscount }

extension PromotionTypeX on PromotionType {
  String get code => switch (this) {
    PromotionType.comboPrice => 'combo_price',
    PromotionType.fullReduce => 'full_reduce',
    PromotionType.nthDiscount => 'nth_discount',
  };

  static PromotionType fromCode(String code) => switch (code) {
    'combo_price' => PromotionType.comboPrice,
    'full_reduce' => PromotionType.fullReduce,
    'nth_discount' => PromotionType.nthDiscount,
    _ => PromotionType.comboPrice,
  };
}

class PromotionRule {
  const PromotionRule({
    required this.id,
    required this.name,
    required this.type,
    required this.priority,
    required this.isActive,
    required this.applyInStore,
    required this.applyDelivery,
    required this.condition,
    required this.benefit,
    required this.createdAt,
    this.startAt,
    this.endAt,
  });

  final int id;
  final String name;
  final PromotionType type;
  final int priority;
  final bool isActive;
  final bool applyInStore;
  final bool applyDelivery;
  final DateTime? startAt;
  final DateTime? endAt;
  final Map<String, dynamic> condition;
  final Map<String, dynamic> benefit;
  final DateTime createdAt;

  factory PromotionRule.fromMap(Map<String, Object?> map) {
    final conditionJson = (map['condition_json'] as String?) ?? '{}';
    final benefitJson = (map['benefit_json'] as String?) ?? '{}';
    return PromotionRule(
      id: map['id'] as int,
      name: (map['name'] as String?) ?? '',
      type: PromotionTypeX.fromCode((map['type'] as String?) ?? ''),
      priority: (map['priority'] as num?)?.toInt() ?? 100,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      applyInStore: (map['apply_in_store'] as int? ?? 1) == 1,
      applyDelivery: (map['apply_delivery'] as int? ?? 0) == 1,
      startAt: _parseDate(map['start_at'] as String?),
      endAt: _parseDate(map['end_at'] as String?),
      condition: _decodeJsonMap(conditionJson),
      benefit: _decodeJsonMap(benefitJson),
      createdAt: _parseDate(map['created_at'] as String?) ?? DateTime.now(),
    );
  }

  static DateTime? _parseDate(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return DateTime.tryParse(value);
  }

  static Map<String, dynamic> _decodeJsonMap(String raw) {
    try {
      final value = jsonDecode(raw);
      if (value is Map<String, dynamic>) return value;
      if (value is Map) {
        return value.map((key, item) => MapEntry(key.toString(), item));
      }
      return <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }
}

class AppliedPromotion {
  const AppliedPromotion({
    required this.ruleId,
    required this.ruleName,
    required this.type,
    required this.amount,
    this.description = '',
  });

  final int ruleId;
  final String ruleName;
  final PromotionType type;
  final double amount;
  final String description;

  Map<String, dynamic> toMap() => {
    'rule_id': ruleId,
    'rule_name': ruleName,
    'type': type.code,
    'amount': amount,
    'description': description,
  };
}
