class Product {
  const Product({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    this.deliveryPrice,
    this.promoType = ProductPromoType.none,
    this.promoValue = 0,
    this.promoActive = false,
    this.nameTh,
    this.nameZh,
    this.nameEn,
    this.description,
    this.imageUrl,
    this.showSize = true,
    this.showSugar = true,
    this.showIce = true,
    this.showToppings = true,
    this.isActive = true,
  });

  final int id;
  final String name;
  final String category;
  final double price;
  final double? deliveryPrice;
  final ProductPromoType promoType;
  final double promoValue;
  final bool promoActive;
  final String? nameTh;
  final String? nameZh;
  final String? nameEn;
  final String? description;
  final String? imageUrl;
  final bool showSize;
  final bool showSugar;
  final bool showIce;
  final bool showToppings;
  final bool isActive;

  bool get hasPromotion =>
      promoActive && promoType != ProductPromoType.none && promoValue > 0;

  double get effectivePrice {
    if (!hasPromotion) return price;
    if (promoType == ProductPromoType.percentage) {
      final percent = promoValue.clamp(0, 100);
      return (price * (1 - percent / 100)).clamp(0, price).toDouble();
    }
    final reduced = price - promoValue;
    return reduced > 0 ? reduced : 0;
  }

  double effectivePriceByOrderType({
    required bool isDelivery,
    bool applyPromotion = true,
  }) {
    if (isDelivery) {
      final delivery = deliveryPrice;
      if (delivery != null && delivery > 0) return delivery;
      return applyPromotion ? effectivePrice : price;
    }
    return applyPromotion ? effectivePrice : price;
  }

  Product copyWith({
    int? id,
    String? name,
    String? category,
    double? price,
    double? deliveryPrice,
    bool clearDeliveryPrice = false,
    ProductPromoType? promoType,
    double? promoValue,
    bool? promoActive,
    String? nameTh,
    String? nameZh,
    String? nameEn,
    String? description,
    String? imageUrl,
    bool? showSize,
    bool? showSugar,
    bool? showIce,
    bool? showToppings,
    bool? isActive,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      price: price ?? this.price,
      deliveryPrice: clearDeliveryPrice
          ? null
          : (deliveryPrice ?? this.deliveryPrice),
      promoType: promoType ?? this.promoType,
      promoValue: promoValue ?? this.promoValue,
      promoActive: promoActive ?? this.promoActive,
      nameTh: nameTh ?? this.nameTh,
      nameZh: nameZh ?? this.nameZh,
      nameEn: nameEn ?? this.nameEn,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      showSize: showSize ?? this.showSize,
      showSugar: showSugar ?? this.showSugar,
      showIce: showIce ?? this.showIce,
      showToppings: showToppings ?? this.showToppings,
      isActive: isActive ?? this.isActive,
    );
  }

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

  factory Product.fromMap(Map<String, Object?> map) {
    return Product(
      id: map['id'] as int,
      name: map['name'] as String,
      category: map['category'] as String,
      price: (map['price'] as num).toDouble(),
      deliveryPrice: (map['delivery_price'] as num?)?.toDouble(),
      promoType: ProductPromoTypeX.fromCode(
        (map['promo_type'] as String?) ?? 'none',
      ),
      promoValue: (map['promo_value'] as num?)?.toDouble() ?? 0,
      promoActive: (map['promo_active'] as int? ?? 0) == 1,
      nameTh: map['name_th'] as String?,
      nameZh: map['name_zh'] as String?,
      nameEn: map['name_en'] as String?,
      description: map['description'] as String?,
      imageUrl: map['image_url'] as String?,
      showSize: (map['show_size'] as int? ?? 1) == 1,
      showSugar: (map['show_sugar'] as int? ?? 1) == 1,
      showIce: (map['show_ice'] as int? ?? 1) == 1,
      showToppings: (map['show_toppings'] as int? ?? 1) == 1,
      isActive: (map['is_active'] as int? ?? 1) == 1,
    );
  }
}

enum ProductPromoType { none, percentage, amount }

extension ProductPromoTypeX on ProductPromoType {
  String get code => switch (this) {
    ProductPromoType.none => 'none',
    ProductPromoType.percentage => 'percentage',
    ProductPromoType.amount => 'amount',
  };

  static ProductPromoType fromCode(String code) => switch (code) {
    'percentage' => ProductPromoType.percentage,
    'amount' => ProductPromoType.amount,
    _ => ProductPromoType.none,
  };
}
