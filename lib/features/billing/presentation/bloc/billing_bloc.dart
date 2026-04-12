import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/cart_item.dart';
import 'package:billo/features/product/domain/entities/product.dart';
import 'package:billo/features/product/domain/usecases/product_usecases.dart';
import '../../../../core/utils/printer_helper.dart';
import '../../../../core/utils/pdf_helper.dart';
import '../../../../core/data/hive_database.dart';
import 'package:billo/features/reports/data/models/sale_model.dart';
import 'package:billo/features/product/data/models/product_model.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/utils/sync_manager.dart';

part 'billing_event.dart';
part 'billing_state.dart';

class BillingBloc extends Bloc<BillingEvent, BillingState> {
  final GetProductByBarcodeUseCase getProductByBarcodeUseCase;

  BillingBloc({required this.getProductByBarcodeUseCase})
      : super(const BillingState()) {
    on<ScanBarcodeEvent>(_onScanBarcode);
    on<AddProductToCartEvent>(_onAddProductToCart);
    on<SizeSelectedEvent>(_onSizeSelected);
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
        if (!product.isSizeSpecific) {
          // Unified product — add directly
          add(AddProductToCartEvent(product, selectedSize: ''));
        } else if (product.sizeStocks.length == 1) {
          // Only one size — add directly
          final size = product.sizeStocks.keys.first;
          add(AddProductToCartEvent(product, selectedSize: size));
        } else {
          // Multiple sizes — ask user to pick
          emit(state.copyWith(pendingSizeProduct: product, clearError: true));
        }
      },
    );
  }

  void _onSizeSelected(
      SizeSelectedEvent event, Emitter<BillingState> emit) {
    // __cancel__ means user dismissed the picker without selecting
    if (event.selectedSize == '__cancel__') {
      emit(state.copyWith(clearPendingProduct: true));
      return;
    }
    final product = state.pendingSizeProduct;
    if (product == null) return;
    emit(state.copyWith(clearPendingProduct: true));
    add(AddProductToCartEvent(product, selectedSize: event.selectedSize));
  }

  void _onAddProductToCart(
      AddProductToCartEvent event, Emitter<BillingState> emit) {
    final cleanState = state.copyWith(clearError: true, clearPendingProduct: true);
    final cartKey = '${event.product.id}_${event.selectedSize}';

    final existingIndex = cleanState.cartItems
        .indexWhere((item) => item.cartKey == cartKey);
    if (existingIndex >= 0) {
      final existingItem = cleanState.cartItems[existingIndex];
      final updatedItems = List<CartItem>.from(cleanState.cartItems);
      updatedItems[existingIndex] =
          existingItem.copyWith(quantity: existingItem.quantity + 1);
      emit(cleanState.copyWith(cartItems: updatedItems));
    } else {
      final newItem = CartItem(
        product: event.product,
        selectedSize: event.selectedSize,
      );
      emit(cleanState.copyWith(
          cartItems: [...cleanState.cartItems, newItem]));
    }
    // Stock is deducted at checkout, not when adding to cart
  }

  void _deductSizeStock(String productId, String size, {int by = 1}) {
    final productModel = HiveDatabase.productBox.get(productId);
    if (productModel == null) return;

    if (!productModel.isSizeSpecific) {
      // Deduct from baseStock
      final updatedProduct = productModel.copyWith(
        baseStock: (productModel.baseStock - by).clamp(0, 999999),
      );
      HiveDatabase.productBox.put(productId, updatedProduct);
    } else {
      // Deduct from sizeStocks map
      if (size.isEmpty || size == '__cancel__') return;
      final currentStock = productModel.sizeStocks[size] ?? 0;
      final updatedStocks = Map<String, int>.from(productModel.sizeStocks);
      updatedStocks[size] = (currentStock - by).clamp(0, 999999);
      final updatedProduct = productModel.copyWith(sizeStocks: updatedStocks);
      HiveDatabase.productBox.put(productId, updatedProduct);
      
      // Sync Stock to Cloud
      SyncManager.pushProduct(updatedProduct);
    }
  }

  void _onRemoveProductFromCart(
      RemoveProductFromCartEvent event, Emitter<BillingState> emit) {
    final updatedList = state.cartItems
        .where((item) => item.cartKey != event.productId)
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
        .indexWhere((item) => item.cartKey == event.productId);
    if (index >= 0) {
      final currentItem = state.cartItems[index];
      final items = List<CartItem>.from(state.cartItems);
      items[index] = currentItem.copyWith(quantity: event.quantity);
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
         paymentMethod: event.paymentMethod,
      );
      
      await HiveDatabase.salesBox.put(sale.id, sale);
      
      // Sync Sale to Cloud
      SyncManager.pushSale(sale);

      // Deduct stock per size at checkout (sale finalization)
      for (final item in state.cartItems) {
        _deductSizeStock(item.product.id, item.selectedSize, by: item.quantity);
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
