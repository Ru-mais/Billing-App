import 'package:equatable/equatable.dart';

class Shop extends Equatable {
  final String name;
  final String addressLine1;
  final String addressLine2;
  final String phoneNumber;
  final String upiId;
  final String footerText;
  final String logoPath;
  final String gstIn;

  const Shop({
    this.name = '',
    this.addressLine1 = '',
    this.addressLine2 = '',
    this.phoneNumber = '',
    this.upiId = '',
    this.footerText = '',
    this.logoPath = '',
    this.gstIn = '',
  });

  Shop copyWith({
    String? name,
    String? addressLine1,
    String? addressLine2,
    String? phoneNumber,
    String? upiId,
    String? footerText,
    String? logoPath,
    String? gstIn,
  }) {
    return Shop(
      name: name ?? this.name,
      addressLine1: addressLine1 ?? this.addressLine1,
      addressLine2: addressLine2 ?? this.addressLine2,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      upiId: upiId ?? this.upiId,
      footerText: footerText ?? this.footerText,
      logoPath: logoPath ?? this.logoPath,
      gstIn: gstIn ?? this.gstIn,
    );
  }

  @override
  List<Object?> get props => [
        name,
        addressLine1,
        addressLine2,
        phoneNumber,
        upiId,
        footerText,
        logoPath,
        gstIn
      ];
}
