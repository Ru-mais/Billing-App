part of 'billing_bloc.dart';

enum DiscountType { percentage, amount }

class BillingState extends Equatable {
  final List<CartItem> cartItems;
  final String? error;
  final bool isPrinting;
  final bool printSuccess;
  final Product? pendingSizeProduct; // product waiting for size selection
  final bool discountEnabled;
  final double discountValue;
  final DiscountType discountType;

  const BillingState({
    this.cartItems = const [],
    this.error,
    this.isPrinting = false,
    this.printSuccess = false,
    this.pendingSizeProduct,
    this.discountEnabled = false,
    this.discountValue = 0,
    this.discountType = DiscountType.percentage,
  });

  double get netAmount => cartItems.fold(0.0, (sum, item) => sum + item.total);
  
  double get discountAmount {
    if (!discountEnabled) return 0.0;
    if (discountType == DiscountType.percentage) {
      return netAmount * (discountValue / 100);
    } else {
      return discountValue;
    }
  }

  double get totalAmount => (netAmount - discountAmount).clamp(0.0, double.infinity);

  BillingState copyWith({
    List<CartItem>? cartItems,
    String? error,
    bool clearError = false,
    bool? isPrinting,
    bool? printSuccess,
    Product? pendingSizeProduct,
    bool clearPendingProduct = false,
    bool? discountEnabled,
    double? discountValue,
    DiscountType? discountType,
  }) {
    return BillingState(
      cartItems: cartItems ?? this.cartItems,
      error: clearError ? null : (error ?? this.error),
      isPrinting: isPrinting ?? this.isPrinting,
      printSuccess: printSuccess ?? this.printSuccess,
      pendingSizeProduct: clearPendingProduct ? null : (pendingSizeProduct ?? this.pendingSizeProduct),
      discountEnabled: discountEnabled ?? this.discountEnabled,
      discountValue: discountValue ?? this.discountValue,
      discountType: discountType ?? this.discountType,
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
        discountValue,
        discountType,
      ];
}
