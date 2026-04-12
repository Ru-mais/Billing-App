import 'package:hive_flutter/hive_flutter.dart';
import '../../features/product/data/models/product_model.dart';
import '../../features/shop/data/models/shop_model.dart';
import '../../features/reports/data/models/sale_model.dart';
import '../../features/reports/data/models/purchase_order_model.dart';

class HiveDatabase {
  static const String productBoxName = 'products';
  static const String shopBoxName = 'shop';
  static const String settingsBoxName = 'settings';
  static const String salesBoxName = 'sales';
  static const String purchaseOrdersBoxName = 'purchase_orders';
  static const String categoryBoxName = 'categories';

  static Future<void> init() async {
    await Hive.initFlutter();

    // Register Adapters
    Hive.registerAdapter(ProductModelAdapter());
    Hive.registerAdapter(ShopModelAdapter());
    Hive.registerAdapter(SaleModelAdapter());
    Hive.registerAdapter(SaleItemModelAdapter());
    Hive.registerAdapter(PurchaseOrderModelAdapter());
    Hive.registerAdapter(PurchaseItemModelAdapter());

    // Open Boxes
    await Hive.openBox<ProductModel>(productBoxName);
    await Hive.openBox<ShopModel>(shopBoxName);
    await Hive.openBox(settingsBoxName); // Generic box for simple key-value
    await Hive.openBox<SaleModel>(salesBoxName);
    await Hive.openBox<PurchaseOrderModel>(purchaseOrdersBoxName);
    await Hive.openBox<String>(categoryBoxName);
  }

  static Box<ProductModel> get productBox =>
      Hive.box<ProductModel>(productBoxName);
  static Box<ShopModel> get shopBox => Hive.box<ShopModel>(shopBoxName);
  static Box get settingsBox => Hive.box(settingsBoxName);
  static Box<SaleModel> get salesBox => Hive.box<SaleModel>(salesBoxName);
  static Box<PurchaseOrderModel> get purchaseOrdersBox =>
      Hive.box<PurchaseOrderModel>(purchaseOrdersBoxName);
  static Box<String> get categoryBox => Hive.box<String>(categoryBoxName);
}
