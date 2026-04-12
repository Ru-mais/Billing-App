import 'package:equatable/equatable.dart';
import 'package:billo/features/product/domain/entities/product.dart';

class CartItem extends Equatable {
  final Product product;
  final int quantity;
  final String selectedSize;

  const CartItem({
    required this.product,
    this.quantity = 1,
    this.selectedSize = '',
  });

  double get total => product.price * quantity;

  // Unique key combining product id + size for separate cart lines
  String get cartKey => '${product.id}_$selectedSize';

  CartItem copyWith({
    Product? product,
    int? quantity,
    String? selectedSize,
  }) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      selectedSize: selectedSize ?? this.selectedSize,
    );
  }

  @override
  List<Object> get props => [product, quantity, selectedSize];
}
