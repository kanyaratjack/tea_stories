import 'package:flutter_test/flutter_test.dart';
import 'package:tea_store_pos/models/cart_item.dart';
import 'package:tea_store_pos/models/product.dart';

void main() {
  test('cart item subtotal includes size extra', () {
    const product = Product(id: 1, name: '珍珠奶茶', category: '奶茶', price: 16);
    final item = CartItem(
      product: product,
      quantity: 2,
      sizeName: '大杯',
      sizeExtraPrice: 2,
    );

    expect(item.unitPrice, 18);
    expect(item.subtotal, 36);
  });
}
