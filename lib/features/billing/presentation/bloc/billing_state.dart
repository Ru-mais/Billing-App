part of 'billing_bloc.dart';

class BillingState extends Equatable {
  final List<CartItem> cartItems;
  final String? error;
  final bool isPrinting;
  final bool printSuccess;
  final Product? pendingSizeProduct; // product waiting for size selection
  final bool discountEnabled;
  final double discountPercent;

  const BillingState({
    this.cartItems = const [],
    this.error,
    this.isPrinting = false,
    this.printSuccess = false,
    this.pendingSizeProduct,
    this.discountEnabled = false,
    this.discountPercent = 0,
  });

  double get netAmount => cartItems.fold(0, (sum, item) => sum + item.total);
  double get discountAmount =>
      discountEnabled ? (netAmount * (discountPercent / 100)) : 0;
  double get totalAmount => (netAmount - discountAmount).clamp(0, double.infinity);

  BillingState copyWith({
    List<CartItem>? cartItems,
    String? error,
    bool clearError = false,
    bool? isPrinting,
    bool? printSuccess,
    Product? pendingSizeProduct,
    bool clearPendingProduct = false,
    bool? discountEnabled,
    double? discountPercent,
  }) {
    return BillingState(
      cartItems: cartItems ?? this.cartItems,
      error: clearError ? null : (error ?? this.error),
      isPrinting: isPrinting ?? this.isPrinting,
      printSuccess: printSuccess ?? this.printSuccess,
      pendingSizeProduct: clearPendingProduct ? null : (pendingSizeProduct ?? this.pendingSizeProduct),
      discountEnabled: discountEnabled ?? this.discountEnabled,
      discountPercent: discountPercent ?? this.discountPercent,
    );
  }

  @override
  List<Object?> get props => [
        cartItems,
        error,
        isPrinting,
        printSuccess,
        pendingSizeProduct,
        discountEnabled,
        discountPercent,
      ];
}
