import 'package:hive/hive.dart';

part 'purchase_order_model.g.dart';

@HiveType(typeId: 5)
class PurchaseOrderModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final DateTime timestamp;

  @HiveField(2)
  final String supplierName;

  @HiveField(3)
  final List<PurchaseItemModel> items;

  @HiveField(4)
  final double totalAmount;

  @HiveField(5)
  final String notes;

  PurchaseOrderModel({
    required this.id,
    required this.timestamp,
    required this.supplierName,
    required this.items,
    required this.totalAmount,
    this.notes = '',
  });
}

@HiveType(typeId: 6)
class PurchaseItemModel extends HiveObject {
  @HiveField(0)
  final String productName;

  @HiveField(1)
  final int quantity;

  @HiveField(2)
  final double unitCost;

  PurchaseItemModel({
    required this.productName,
    required this.quantity,
    required this.unitCost,
  });

  double get totalCost => quantity * unitCost;
}
