import 'package:hive/hive.dart';
import '../../domain/entities/product.dart';

part 'product_model.g.dart'; // Hive generator

@HiveType(typeId: 0)
class ProductModel extends Product {
  @override
  @HiveField(0)
  final String id;
  @override
  @HiveField(1)
  final String name;
  @override
  @HiveField(2)
  final String barcode;
  @override
  @HiveField(3)
  final double price;
  @override
  @HiveField(6, defaultValue: {})
  final Map<String, int> sizeStocks;

  const ProductModel({
    required this.id,
    required this.name,
    required this.barcode,
    required this.price,
    required this.sizeStocks,
  }) : super(
          id: id,
          name: name,
          barcode: barcode,
          price: price,
          sizeStocks: sizeStocks,
        );

  factory ProductModel.fromEntity(Product product) {
    return ProductModel(
      id: product.id,
      name: product.name,
      barcode: product.barcode,
      price: product.price,
      sizeStocks: product.sizeStocks,
    );
  }

  Product toEntity() {
    return Product(
      id: id,
      name: name,
      barcode: barcode,
      price: price,
      sizeStocks: sizeStocks,
    );
  }

  ProductModel copyWith({
    String? id,
    String? name,
    String? barcode,
    double? price,
    Map<String, int>? sizeStocks,
  }) {
    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      barcode: barcode ?? this.barcode,
      price: price ?? this.price,
      sizeStocks: sizeStocks ?? this.sizeStocks,
    );
  }
}
