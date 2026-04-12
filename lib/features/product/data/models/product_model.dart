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
  @HiveField(4)
  final double purchasedRate;
  @override
  @HiveField(5)
  final int baseStock;
  @override
  @HiveField(6, defaultValue: {})
  final Map<String, int> sizeStocks;
  @override
  @HiveField(7, defaultValue: true)
  final bool isSizeSpecific;
  @override
  @HiveField(8, defaultValue: 'General')
  final String category;

  const ProductModel({
    required this.id,
    required this.name,
    required this.barcode,
    required this.price,
    this.purchasedRate = 0.0,
    this.baseStock = 0,
    this.isSizeSpecific = true,
    required this.sizeStocks,
    required this.category,
  }) : super(
          id: id,
          name: name,
          barcode: barcode,
          price: price,
          purchasedRate: purchasedRate,
          baseStock: baseStock,
          isSizeSpecific: isSizeSpecific,
          sizeStocks: sizeStocks,
          category: category,
        );

  factory ProductModel.fromEntity(Product product) {
    return ProductModel(
      id: product.id,
      name: product.name,
      barcode: product.barcode,
      price: product.price,
      purchasedRate: product.purchasedRate,
      baseStock: product.baseStock,
      isSizeSpecific: product.isSizeSpecific,
      sizeStocks: product.sizeStocks,
      category: product.category,
    );
  }

  Product toEntity() {
    return Product(
      id: id,
      name: name,
      barcode: barcode,
      price: price,
      purchasedRate: purchasedRate,
      baseStock: baseStock,
      isSizeSpecific: isSizeSpecific,
      sizeStocks: sizeStocks,
      category: category,
    );
  }

  ProductModel copyWith({
    String? id,
    String? name,
    String? barcode,
    double? price,
    double? purchasedRate,
    int? baseStock,
    bool? isSizeSpecific,
    Map<String, int>? sizeStocks,
    String? category,
  }) {
    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      barcode: barcode ?? this.barcode,
      price: price ?? this.price,
      purchasedRate: purchasedRate ?? this.purchasedRate,
      baseStock: baseStock ?? this.baseStock,
      isSizeSpecific: isSizeSpecific ?? this.isSizeSpecific,
      sizeStocks: sizeStocks ?? this.sizeStocks,
      category: category ?? this.category,
    );
  }
}
