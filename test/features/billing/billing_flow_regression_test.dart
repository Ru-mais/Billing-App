import 'package:billo/core/error/failure.dart';
import 'package:billo/features/billing/presentation/bloc/billing_bloc.dart';
import 'package:billo/features/product/domain/entities/product.dart';
import 'package:billo/features/product/domain/repositories/product_repository.dart';
import 'package:billo/features/product/domain/usecases/product_usecases.dart';
import 'package:fpdart/fpdart.dart';
import 'package:flutter_test/flutter_test.dart';

class _InMemoryProductRepository implements ProductRepository {
  _InMemoryProductRepository(this.products);
  final Map<String, Product> products;

  @override
  Future<Either<Failure, void>> addProduct(Product product) async =>
      right(null);

  @override
  Future<Either<Failure, void>> deleteProduct(String id) async => right(null);

  @override
  Future<Either<Failure, Product>> getProductByBarcode(String barcode) async {
    final value = products[barcode];
    if (value == null) return left(const CacheFailure('missing'));
    return right(value);
  }

  @override
  Future<Either<Failure, List<Product>>> getProducts() async =>
      right(products.values.toList());

  @override
  Future<Either<Failure, void>> updateProduct(Product product) async =>
      right(null);
}

void main() {
  test('cart + discount regression flow', () async {
    const product = Product(
      id: 'sneaker',
      name: 'Sneaker',
      category: 'Shoes',
      barcode: 'SNK-1',
      price: 1200,
      isSizeSpecific: true,
      sizeStocks: {'8': 4, '9': 2},
    );
    final bloc = BillingBloc(
      getProductByBarcodeUseCase: GetProductByBarcodeUseCase(
        _InMemoryProductRepository({'SNK-1': product}),
      ),
    );

    bloc.add(const ScanBarcodeEvent('SNK-1'));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(bloc.state.pendingSizeProduct?.id, 'sneaker');

    bloc.add(const SizeSelectedEvent('9'));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(bloc.state.cartItems.length, 1);
    expect(bloc.state.cartItems.first.selectedSize, '9');

    bloc.add(const ToggleDiscountEvent(true));
    bloc.add(const SetDiscountPercentEvent(15));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(bloc.state.netAmount, 1200);
    expect(bloc.state.discountAmount, 180);
    expect(bloc.state.totalAmount, 1020);

    await bloc.close();
  });
}
