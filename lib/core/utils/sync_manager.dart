import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/product/data/models/product_model.dart';
import '../../features/reports/data/models/sale_model.dart';
import '../../features/reports/data/models/purchase_order_model.dart';
import '../../features/shop/data/models/shop_model.dart';
import '../data/hive_database.dart';

class SyncManager {
  static final _supabase = Supabase.instance.client;

  /// Pulls all data from Supabase and updates local Hive storage.
  /// This is the "Auto-Restore" logic.
  static Future<void> pullAll() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      // 0. Pull Shop Settings
      final shopData = await _supabase.from('shop_settings').select().maybeSingle();
      if (shopData != null) {
        final model = ShopModel(
          name: shopData['name'] ?? '',
          addressLine1: shopData['address_line1'] ?? '',
          addressLine2: shopData['address_line2'] ?? '',
          phoneNumber: shopData['phone_number'] ?? '',
          upiId: shopData['upi_id'] ?? '',
          footerText: shopData['footer_text'] ?? '',
        );
        await HiveDatabase.shopBox.put('shop_details', model);
      }

      // 1. Pull Categories
      final catData = await _supabase.from('categories').select('name');
      final categories = catData.map((e) => e['name'] as String).toList();
      await HiveDatabase.categoryBox.clear();
      if (categories.isNotEmpty) {
        await HiveDatabase.categoryBox.addAll(categories);
      }

      // 2. Pull Products
      final prodData = await _supabase.from('products').select();
      await HiveDatabase.productBox.clear();
      for (var p in prodData) {
        final model = ProductModel(
          id: p['id'],
          name: p['name'],
          barcode: p['barcode'] ?? '',
          price: (p['price'] as num).toDouble(),
          purchasedRate: (p['purchased_rate'] as num).toDouble(),
          baseStock: p['base_stock'] as int,
          sizeStocks: Map<String, int>.from(p['size_stocks']),
          isSizeSpecific: p['is_size_specific'] as bool,
          category: p['category'] ?? 'General',
        );
        await HiveDatabase.productBox.put(model.id, model);
      }

      // 3. Pull Sales
      final salesData = await _supabase.from('sales').select();
      await HiveDatabase.salesBox.clear();
      for (var s in salesData) {
        final model = SaleModel(
          id: s['id'],
          timestamp: DateTime.parse(s['timestamp']),
          totalAmount: (s['total_amount'] as num).toDouble(),
          paymentMethod: s['payment_method'],
          items: (s['items'] as List).map((i) => SaleItemModel(
            productId: i['productId'],
            productName: i['productName'],
            quantity: i['quantity'],
            price: (i['price'] as num).toDouble(),
          )).toList(),
        );
        await HiveDatabase.salesBox.put(model.id, model);
      }

      // 4. Pull Purchases
      final purchaseData = await _supabase.from('purchase_orders').select();
      await HiveDatabase.purchaseOrdersBox.clear();
      for (var p in purchaseData) {
        final model = PurchaseOrderModel(
          id: p['id'],
          timestamp: DateTime.parse(p['timestamp']),
          supplierName: p['supplier_name'] ?? '',
          totalAmount: (p['total_amount'] as num).toDouble(),
          notes: p['notes'] ?? '',
          items: (p['items'] as List).map((i) => PurchaseItemModel(
            productName: i['productName'],
            quantity: i['quantity'],
            unitCost: (i['unitCost'] as num).toDouble(),
            productId: i['productId'],
            size: i['size'],
          )).toList(),
        );
        await HiveDatabase.purchaseOrdersBox.put(model.id, model);
      }

      print('✅ All data pulled and synced from cloud');
    } catch (e) {
      print('❌ Sync Pull Failed: $e');
    }
  }

  /// Pushes shop settings to the cloud
  static Future<void> pushShop(ShopModel shop) async {
    try {
      await _supabase.from('shop_settings').upsert({
        'id': 'shop_details',
        'name': shop.name,
        'address_line1': shop.addressLine1,
        'address_line2': shop.addressLine2,
        'phone_number': shop.phoneNumber,
        'upi_id': shop.upiId,
        'footer_text': shop.footerText,
      });
    } catch (e) {
      print('❌ Shop Sync Failed: $e');
    }
  }

  /// Pushes a specific purchase order to the cloud
  static Future<void> pushPurchaseOrder(PurchaseOrderModel order) async {
    try {
      await _supabase.from('purchase_orders').upsert({
        'id': order.id,
        'timestamp': order.timestamp.toIso8601String(),
        'supplier_name': order.supplierName,
        'total_amount': order.totalAmount,
        'notes': order.notes,
        'items': order.items.map((i) => {
          'productName': i.productName,
          'quantity': i.quantity,
          'unitCost': i.unitCost,
          'productId': i.productId,
          'size': i.size,
        }).toList(),
      });
    } catch (e) {
      print('❌ Purchase Sync Failed: $e');
    }
  }

  /// Pushes a specific product to the cloud
  static Future<void> pushProduct(ProductModel product) async {
    try {
      await _supabase.from('products').upsert({
        'id': product.id,
        'name': product.name,
        'barcode': product.barcode,
        'price': product.price,
        'purchased_rate': product.purchasedRate,
        'base_stock': product.baseStock,
        'size_stocks': product.sizeStocks,
        'is_size_specific': product.isSizeSpecific,
        'category': product.category,
      });
    } catch (e) {
      print('❌ Product Push Failed: $e');
    }
  }

  /// Pushes a specific sale to the cloud
  static Future<void> pushSale(SaleModel sale) async {
    try {
      await _supabase.from('sales').insert({
        'id': sale.id,
        'timestamp': sale.timestamp.toIso8601String(),
        'total_amount': sale.totalAmount,
        'payment_method': sale.paymentMethod,
        'items': sale.items.map((i) => {
          'productId': i.productId,
          'productName': i.productName,
          'quantity': i.quantity,
          'price': i.price,
        }).toList(),
      });
    } catch (e) {
      print('❌ Sale Push Failed: $e');
    }
  }

  /// Synchronizes Kategorien
  static Future<void> syncCategories() async {
    try {
      final localCats = HiveDatabase.categoryBox.values.toList();
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      
      await _supabase.from('categories').delete().eq('user_id', user.id);
      for (var cat in localCats) {
        await _supabase.from('categories').insert({'name': cat});
      }
    } catch (e) {
      print('❌ Category Sync Failed: $e');
    }
  }

  /// Handles deletions
  static Future<void> deleteProduct(String id) async {
    try {
      await _supabase.from('products').delete().eq('id', id);
    } catch (e) {
      print('❌ Product Delete Sync Failed: $e');
    }
  }
}
