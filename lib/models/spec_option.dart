class SpecGroupKey {
  static const String size = 'size';
  static const String sugar = 'sugar';
  static const String ice = 'ice';
  static const String toppings = 'toppings';

  static const List<String> values = [size, sugar, ice, toppings];
}

class SpecOption {
  const SpecOption({
    required this.id,
    required this.groupKey,
    required this.name,
    this.nameTh,
    this.nameZh,
    this.nameEn,
    required this.price,
    required this.sortOrder,
    required this.isActive,
  });

  final int id;
  final String groupKey;
  final String name;
  final String? nameTh;
  final String? nameZh;
  final String? nameEn;
  final double price;
  final int sortOrder;
  final bool isActive;

  String localizedName(String languageCode) {
    final th = nameTh?.trim();
    final zh = nameZh?.trim();
    final en = nameEn?.trim();
    final base = name.trim();
    if (languageCode == 'th' && th != null && th.isNotEmpty) return th;
    if (languageCode == 'zh' && zh != null && zh.isNotEmpty) return zh;
    if (languageCode == 'en' && en != null && en.isNotEmpty) return en;
    if (zh != null && zh.isNotEmpty) return zh;
    if (th != null && th.isNotEmpty) return th;
    if (en != null && en.isNotEmpty) return en;
    return base;
  }

  factory SpecOption.fromMap(Map<String, Object?> map) {
    return SpecOption(
      id: map['id'] as int,
      groupKey: map['group_key'] as String,
      name: map['name'] as String,
      nameTh: map['name_th'] as String?,
      nameZh: map['name_zh'] as String?,
      nameEn: map['name_en'] as String?,
      price: (map['price'] as num?)?.toDouble() ?? 0,
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
      isActive: (map['is_active'] as int? ?? 1) == 1,
    );
  }
}
