import 'package:equatable/equatable.dart';

class Product extends Equatable {
  final String
      id; // Using barcode as ID usually, but keeping separate ID is safer
  final String name;
  final String barcode;
  final double price;
  final Map<String, int> sizeStocks; // e.g., {'7': 10, '8': 5}

  const Product({
    required this.id,
    required this.name,
    required this.barcode,
    required this.price,
    this.sizeStocks = const {},
  });

  int get totalStock => sizeStocks.values.fold(0, (a, b) => a + b);

  @override
  List<Object?> get props => [id, name, barcode, price, sizeStocks];
}
