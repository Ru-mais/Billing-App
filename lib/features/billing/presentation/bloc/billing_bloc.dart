import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/cart_item.dart';
import 'package:billing_app/features/product/domain/entities/product.dart';
import 'package:billing_app/features/product/domain/usecases/product_usecases.dart';
import 'package:billing_app/features/product/data/models/product_model.dart';
import '../../../../core/utils/printer_helper.dart';
import '../../../../core/utils/pdf_helper.dart';
import '../../../../core/data/hive_database.dart';
import 'package:billing_app/features/reports/data/models/sale_model.dart';
import 'package:uuid/uuid.dart';

part 'billing_event.dart';
part 'billing_state.dart';

class BillingBloc extends Bloc<BillingEvent, BillingState> {
  final GetProductByBarcodeUseCase getProductByBarcodeUseCase;

  BillingBloc({required this.getProductByBarcodeUseCase})
      : super(const BillingState()) {
    on<ScanBarcodeEvent>(_onScanBarcode);
    on<AddProductToCartEvent>(_onAddProductToCart);
    on<RemoveProductFromCartEvent>(_onRemoveProductFromCart);
    on<UpdateQuantityEvent>(_onUpdateQuantity);
    on<ClearCartEvent>(_onClearCart);
    on<PrintReceiptEvent>(_onPrintReceipt);
  }

  Future<void> _onScanBarcode(
      ScanBarcodeEvent event, Emitter<BillingState> emit) async {
    final result = await getProductByBarcodeUseCase(event.barcode);
    result.fold(
      (failure) =>
          emit(state.copyWith(error: 'Product not found: ${event.barcode}')),
      (product) {
        add(AddProductToCartEvent(product));
      },
    );
  }

  void _onAddProductToCart(
      AddProductToCartEvent event, Emitter<BillingState> emit) {
    // Clear error when adding
    final cleanState = state.copyWith(error: null);

    final existingIndex = cleanState.cartItems
        .indexWhere((item) => item.product.id == event.product.id);
    if (existingIndex >= 0) {
      final existingItem = cleanState.cartItems[existingIndex];
      final backendItems = List<CartItem>.from(cleanState.cartItems);
      backendItems[existingIndex] =
          existingItem.copyWith(quantity: existingItem.quantity + 1);
      emit(cleanState.copyWith(cartItems: backendItems, error: null));
    } else {
      final newItem = CartItem(product: event.product);
      emit(cleanState.copyWith(
          cartItems: [...cleanState.cartItems, newItem], error: null));
    }
  }

  void _onRemoveProductFromCart(
      RemoveProductFromCartEvent event, Emitter<BillingState> emit) {
    final updatedList = state.cartItems
        .where((item) => item.product.id != event.productId)
        .toList();
    emit(state.copyWith(cartItems: updatedList));
  }

  void _onUpdateQuantity(
      UpdateQuantityEvent event, Emitter<BillingState> emit) {
    if (event.quantity <= 0) {
      add(RemoveProductFromCartEvent(event.productId));
      return;
    }

    final index = state.cartItems
        .indexWhere((item) => item.product.id == event.productId);
    if (index >= 0) {
      final items = List<CartItem>.from(state.cartItems);
      items[index] = items[index].copyWith(quantity: event.quantity);
      emit(state.copyWith(cartItems: items));
    }
  }

  void _onClearCart(ClearCartEvent event, Emitter<BillingState> emit) {
    emit(const BillingState());
  }

  Future<void> _onPrintReceipt(
      PrintReceiptEvent event, Emitter<BillingState> emit) async {
    if (state.cartItems.isEmpty) return;

    emit(state.copyWith(
        isPrinting: true, printSuccess: false, clearError: true));

    try {
      // 1. Save Sale to Database
      final saleId = const Uuid().v4();
      final saleItems = state.cartItems.map((item) => SaleItemModel(
          productId: item.product.id,
          productName: item.product.name,
          quantity: item.quantity,
          price: item.product.price,
      )).toList();
      
      final sale = SaleModel(
         id: saleId,
         timestamp: DateTime.now(),
         items: saleItems,
         totalAmount: state.totalAmount,
      );
      
      await HiveDatabase.salesBox.put(sale.id, sale);

      // Decrement logic for products
      for (final cartItem in state.cartItems) {
        final productModel = HiveDatabase.productBox.get(cartItem.product.id);
        if (productModel != null) {
          final updatedProduct = ProductModel(
            id: productModel.id,
            name: productModel.name,
            barcode: productModel.barcode,
            price: productModel.price,
            stock: (productModel.stock - cartItem.quantity < 0) ? 0 : productModel.stock - cartItem.quantity,
          );
          await HiveDatabase.productBox.put(productModel.id, updatedProduct);
        }
      }

      // Prepare items format for printer/PDF
      final itemsMapList = state.cartItems
          .map((item) => {
                'name': item.product.name,
                'qty': item.quantity,
                'price': item.product.price,
                'total': item.total,
              })
          .toList();

      // 2. Check Printer
      final printerHelper = PrinterHelper();
      bool usePdfFallback = true;
      
      if (!printerHelper.isConnected) {
        final savedMac = HiveDatabase.settingsBox.get('printer_mac');
        if (savedMac != null) {
          final connected = await printerHelper.connect(savedMac);
          if (connected) {
             usePdfFallback = false;
          }
        }
      } else {
        usePdfFallback = false;
      }

      // 3. Print or Generate PDF
      if (usePdfFallback) {
         // Generate PDF
         await PdfHelper.generateAndShareReceipt(
            shopName: event.shopName,
            address1: event.address1,
            address2: event.address2,
            phone: event.phone,
            items: itemsMapList,
            total: state.totalAmount,
            footer: event.footer,
         );
      } else {
         // Thermal Print
         await printerHelper.printReceipt(
            shopName: event.shopName,
            address1: event.address1,
            address2: event.address2,
            phone: event.phone,
            items: itemsMapList,
            total: state.totalAmount,
            footer: event.footer
         );
      }

      emit(state.copyWith(isPrinting: false, printSuccess: true));
    } catch (e) {
      emit(state.copyWith(
          isPrinting: false, error: 'Checkout failed: $e', clearError: false));
      // Reset error instantly avoids sticky error
      emit(state.copyWith(clearError: true));
    }
  }
}
