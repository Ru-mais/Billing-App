import 'package:equatable/equatable.dart';

class Product extends Equatable {
  final String
      id; // Using barcode as ID usually, but keeping separate ID is safer
  final String name;
  final String category;
  final String barcode;
  final double price;
  final double purchasedRate;
  final int baseStock;
  final bool isSizeSpecific;
  final Map<String, int> sizeStocks; // e.g., {'7': 10, '8': 5}

  const Product({
    required this.id,
    required this.name,
    required this.category,
    required this.barcode,
    required this.price,
    this.purchasedRate = 0.0,
    this.baseStock = 0,
    this.isSizeSpecific = true,
    this.sizeStocks = const {},
  });

  int get totalStock => isSizeSpecific
      ? sizeStocks.values.fold(0, (a, b) => a + b)
      : baseStock;

  @override
  List<Object?> get props => [
        id,
        name,
        category,
        barcode,
        price,
        purchasedRate,
        baseStock,
        isSizeSpecific,
        sizeStocks
      ];
}
