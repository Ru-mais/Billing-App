import 'package:billo/core/error/failure.dart';
import 'package:billo/features/billing/presentation/bloc/billing_bloc.dart';
import 'package:billo/features/product/domain/entities/product.dart';
import 'package:billo/features/product/domain/repositories/product_repository.dart';
import 'package:billo/features/product/domain/usecases/product_usecases.dart';
import 'package:fpdart/fpdart.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeProductRepository implements ProductRepository {
  _FakeProductRepository(this._productsByBarcode);

  final Map<String, Product> _productsByBarcode;

  @override
  Future<Either<Failure, void>> addProduct(Product product) async =>
      right(null);

  @override
  Future<Either<Failure, void>> deleteProduct(String id) async => right(null);

  @override
  Future<Either<Failure, Product>> getProductByBarcode(String barcode) async {
    final product = _productsByBarcode[barcode];
    if (product == null) return left(const CacheFailure('not found'));
    return right(product);
  }

  @override
  Future<Either<Failure, List<Product>>> getProducts() async =>
      right(_productsByBarcode.values.toList());

  @override
  Future<Either<Failure, void>> updateProduct(Product product) async =>
      right(null);
}

void main() {
  group('BillingBloc flows', () {
    late BillingBloc bloc;

    const normalProduct = Product(
      id: 'p1',
      name: 'Shoe',
      category: 'Footwear',
      barcode: '111',
      price: 100,
      isSizeSpecific: false,
      baseStock: 20,
    );
    const multiSizeProduct = Product(
      id: 'p2',
      name: 'Tee',
      category: 'Apparel',
      barcode: '222',
      price: 200,
      isSizeSpecific: true,
      sizeStocks: {'M': 3, 'L': 2},
    );

    setUp(() {
      final useCase = GetProductByBarcodeUseCase(
        _FakeProductRepository({
          normalProduct.barcode: normalProduct,
          multiSizeProduct.barcode: multiSizeProduct,
        }),
      );
      bloc = BillingBloc(getProductByBarcodeUseCase: useCase);
    });

    tearDown(() async {
      await bloc.close();
    });

    test('scan adds non-size product directly to cart', () async {
      bloc.add(const ScanBarcodeEvent('111'));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(bloc.state.cartItems.length, 1);
      expect(bloc.state.cartItems.first.product.id, normalProduct.id);
      expect(bloc.state.pendingSizeProduct, isNull);
    });

    test('scan keeps multi-size product pending until size selection',
        () async {
      bloc.add(const ScanBarcodeEvent('222'));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(bloc.state.pendingSizeProduct?.id, multiSizeProduct.id);
      expect(bloc.state.cartItems, isEmpty);

      bloc.add(const SizeSelectedEvent('M'));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(bloc.state.pendingSizeProduct, isNull);
      expect(bloc.state.cartItems.length, 1);
      expect(bloc.state.cartItems.first.selectedSize, 'M');
    });

    test('discount percent is clamped and impacts total', () async {
      bloc.add(AddProductToCartEvent(normalProduct, selectedSize: ''));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      bloc.add(const ToggleDiscountEvent(true));
      bloc.add(const SetDiscountPercentEvent(150));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(bloc.state.discountPercent, 100);
      expect(bloc.state.totalAmount, 0);
    });
  });
}
