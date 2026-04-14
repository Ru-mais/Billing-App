// ignore_for_file: overridden_fields, annotate_overrides

import 'package:hive/hive.dart';
import '../../domain/entities/shop.dart';

part 'shop_model.g.dart';

@HiveType(typeId: 1)
class ShopModel extends Shop {
  @HiveField(0)
  final String name;
  @HiveField(1)
  final String addressLine1;
  @HiveField(2)
  final String addressLine2;
  @HiveField(3)
  final String phoneNumber;
  @HiveField(4)
  final String upiId;
  @HiveField(5)
  final String footerText;
  @HiveField(6, defaultValue: '')
  final String gstIn;

  const ShopModel({
    required this.name,
    required this.addressLine1,
    required this.addressLine2,
    required this.phoneNumber,
    required this.upiId,
    required this.footerText,
    this.gstIn = '',
  }) : super(
          name: name,
          addressLine1: addressLine1,
          addressLine2: addressLine2,
          phoneNumber: phoneNumber,
          upiId: upiId,
          footerText: footerText,
          gstIn: gstIn,
        );

  factory ShopModel.fromEntity(Shop shop) {
    return ShopModel(
      name: shop.name,
      addressLine1: shop.addressLine1,
      addressLine2: shop.addressLine2,
      phoneNumber: shop.phoneNumber,
      upiId: shop.upiId,
      footerText: shop.footerText,
      gstIn: shop.gstIn,
    );
  }

  Shop toEntity() => this;
}
