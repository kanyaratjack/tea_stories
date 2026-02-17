class ProductCategory {
  const ProductCategory({
    required this.id,
    required this.name,
    this.nameTh,
    this.nameZh,
    this.nameEn,
    required this.isActive,
    required this.productCount,
  });

  final int id;
  final String name;
  final String? nameTh;
  final String? nameZh;
  final String? nameEn;
  final bool isActive;
  final int productCount;

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

  factory ProductCategory.fromMap(Map<String, Object?> map) {
    return ProductCategory(
      id: map['id'] as int,
      name: map['name'] as String,
      nameTh: map['name_th'] as String?,
      nameZh: map['name_zh'] as String?,
      nameEn: map['name_en'] as String?,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      productCount: (map['product_count'] as int?) ?? 0,
    );
  }
}
