part of 'billing_bloc.dart';

abstract class BillingEvent extends Equatable {
  const BillingEvent();
  @override
  List<Object> get props => [];
}

class ScanBarcodeEvent extends BillingEvent {
  final String barcode;
  const ScanBarcodeEvent(this.barcode);
  @override
  List<Object> get props => [barcode];
}

class AddProductToCartEvent extends BillingEvent {
  final Product product;
  final String selectedSize;
  const AddProductToCartEvent(this.product, {required this.selectedSize});
  @override
  List<Object> get props => [product, selectedSize];
}

class SizeSelectedEvent extends BillingEvent {
  final String selectedSize;
  const SizeSelectedEvent(this.selectedSize);
  @override
  List<Object> get props => [selectedSize];
}

class RemoveProductFromCartEvent extends BillingEvent {
  final String productId;
  const RemoveProductFromCartEvent(this.productId);
  @override
  List<Object> get props => [productId];
}

class UpdateQuantityEvent extends BillingEvent {
  final String productId;
  final int quantity;
  const UpdateQuantityEvent(this.productId, this.quantity);
  @override
  List<Object> get props => [productId, quantity];
}

class ClearCartEvent extends BillingEvent {}

class ToggleDiscountEvent extends BillingEvent {
  final bool enabled;
  const ToggleDiscountEvent(this.enabled);

  @override
  List<Object> get props => [enabled];
}

class SetDiscountValueEvent extends BillingEvent {
  final double value;
  const SetDiscountValueEvent(this.value);

  @override
  List<Object> get props => [value];
}

class SetDiscountTypeEvent extends BillingEvent {
  final DiscountType type;
  const SetDiscountTypeEvent(this.type);

  @override
  List<Object> get props => [type];
}

class PrintReceiptEvent extends BillingEvent {
  final String shopName;
  final String address1;
  final String address2;
  final String phone;
  final String footer;
  final String paymentMethod;
  final String gstIn;

  const PrintReceiptEvent({
    required this.shopName,
    required this.address1,
    required this.address2,
    required this.phone,
    required this.footer,
    this.paymentMethod = 'Cash',
    this.gstIn = '',
  });

  @override
  List<Object> get props =>
      [shopName, address1, address2, phone, footer, paymentMethod, gstIn];
}
