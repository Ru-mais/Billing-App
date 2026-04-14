import 'package:hive/hive.dart';

part 'sale_model.g.dart';

@HiveType(typeId: 3)
class SaleModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final DateTime timestamp;

  @HiveField(2)
  final List<SaleItemModel> items;

  @HiveField(3)
  final double totalAmount;

  @HiveField(4, defaultValue: 'Cash')
  final String paymentMethod;

  @HiveField(5)
  final String? customerName;

  @HiveField(6)
  final String? customerPhone;

  SaleModel({
    required this.id,
    required this.timestamp,
    required this.items,
    required this.totalAmount,
    required this.paymentMethod,
    this.customerName,
    this.customerPhone,
  });
}

@HiveType(typeId: 4)
class SaleItemModel extends HiveObject {
  @HiveField(0)
  final String productId;

  @HiveField(1)
  final String productName;

  @HiveField(2)
  final int quantity;

  @HiveField(3)
  final double price;

  SaleItemModel({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.price,
  });
}
