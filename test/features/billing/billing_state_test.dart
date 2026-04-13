import 'package:billo/features/billing/presentation/bloc/billing_bloc.dart';
import 'package:billo/features/billing/domain/entities/cart_item.dart';
import 'package:billo/features/product/domain/entities/product.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BillingState math regression', () {
    const product = Product(
      id: 'p1',
      name: 'Item 1',
      category: 'General',
      barcode: '111',
      price: 100,
      isSizeSpecific: false,
      baseStock: 10,
    );

    test('calculates net, discount and total correctly', () {
      final cartItem = CartItem(product: product, selectedSize: '')
          .copyWith(quantity: 2); // 200
      const discountPercent = 10.0;
      final state = BillingState(
        cartItems: [cartItem],
        discountEnabled: true,
        discountPercent: discountPercent,
      );

      expect(state.netAmount, 200);
      expect(state.discountAmount, 20);
      expect(state.totalAmount, 180);
    });

    test('never allows negative total', () {
      final cartItem =
          CartItem(product: product, selectedSize: '').copyWith(quantity: 1);
      final state = BillingState(
        cartItems: [cartItem],
        discountEnabled: true,
        discountPercent: 200, // intentionally large
      );

      expect(state.totalAmount, 0);
    });
  });
}
