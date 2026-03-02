import 'product.dart';

class CartItem {
  CartItem({
    required this.product,
    this.quantity = 1,
    this.sizeName = '',
    this.sizeExtraPrice = 0,
    this.sugarName = '',
    this.iceName = '',
    this.toppings = const [],
    this.note = '',
  });

  final Product product;
  int quantity;
  String sizeName;
  double sizeExtraPrice;
  String sugarName;
  String iceName;
  List<ToppingSelection> toppings;
  String note;

  double get toppingTotal =>
      toppings.fold(0, (sum, topping) => sum + topping.price);

  double get unitPrice =>
      product.effectivePrice + sizeExtraPrice + toppingTotal;

  double get subtotal => unitPrice * quantity;

  String get uniqueKey =>
      '${product.id}-${sizeName.trim()}-${sizeExtraPrice.toStringAsFixed(2)}-${sugarName.trim()}-${iceName.trim()}-${_toppingIdsKey()}-${note.trim()}';

  String _toppingIdsKey() {
    final ids = toppings.map((e) => e.id).toList()..sort();
    return ids.join(',');
  }
}

class ToppingSelection {
  const ToppingSelection({
    required this.id,
    required this.name,
    required this.price,
  });

  final int id;
  final String name;
  final double price;
}
