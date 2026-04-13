import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../../features/product/data/models/product_model.dart';
import '../../features/reports/data/models/sale_model.dart';
import '../../features/reports/data/models/purchase_order_model.dart';
import '../../features/shop/data/models/shop_model.dart';
import '../data/hive_database.dart';

class SyncManager {
  static final _supabase = Supabase.instance.client;
  static const String _supplierStorageKey = 'supplier_data_v1';
  static const String _lastSyncAtKey = 'last_sync_at';
  static const String _lastSyncStatusKey = 'last_sync_status';
  static const String _syncMissingTablesKey = 'sync_missing_tables';
  static const String _syncLastMessageKey = 'sync_last_message';
  static const List<String> _requiredTables = [
    'shop_settings',
    'categories',
    'products',
    'sales',
    'purchase_orders',
    'suppliers',
  ];

  static final ValueNotifier<SyncHealth> syncHealthNotifier =
      ValueNotifier(const SyncHealth());

  static void _setHealth({
    DateTime? lastSyncAt,
    String? status,
    List<String>? missingTables,
    String? message,
  }) {
    final next = SyncHealth(
      lastSyncAt: lastSyncAt ?? syncHealthNotifier.value.lastSyncAt,
      status: status ?? syncHealthNotifier.value.status,
      missingTables: missingTables ?? syncHealthNotifier.value.missingTables,
      message: message ?? syncHealthNotifier.value.message,
    );
    syncHealthNotifier.value = next;
  }

  static Future<void> _persistHealth(SyncHealth health) async {
    await HiveDatabase.settingsBox.put(
      _lastSyncAtKey,
      health.lastSyncAt?.toIso8601String(),
    );
    await HiveDatabase.settingsBox.put(_lastSyncStatusKey, health.status);
    await HiveDatabase.settingsBox.put(
      _syncMissingTablesKey,
      health.missingTables,
    );
    await HiveDatabase.settingsBox.put(_syncLastMessageKey, health.message);
  }

  static Future<SyncHealth> loadPersistedHealth() async {
    final rawAt = HiveDatabase.settingsBox.get(_lastSyncAtKey);
    final rawStatus = HiveDatabase.settingsBox.get(_lastSyncStatusKey);
    final rawMissing = HiveDatabase.settingsBox.get(_syncMissingTablesKey);
    final rawMessage = HiveDatabase.settingsBox.get(_syncLastMessageKey);
    final health = SyncHealth(
      lastSyncAt: rawAt is String ? DateTime.tryParse(rawAt) : null,
      status: rawStatus is String ? rawStatus : 'idle',
      missingTables: rawMissing is List
          ? rawMissing.whereType<String>().toList()
          : const [],
      message: rawMessage is String ? rawMessage : null,
    );
    syncHealthNotifier.value = health;
    return health;
  }

  static Future<List<String>> checkRequiredTables() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];
    final missing = <String>[];
    for (final table in _requiredTables) {
      try {
        await _supabase.from(table).select().limit(1);
      } catch (_) {
        missing.add(table);
      }
    }
    return missing;
  }

  /// Pulls all data from Supabase and updates local Hive storage.
  /// This is the "Auto-Restore" logic.
  static Future<void> pullAll() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final missingTables = await checkRequiredTables();
      if (missingTables.isNotEmpty) {
        _setHealth(
          status: 'degraded',
          missingTables: missingTables,
          message: 'Missing Supabase tables: ${missingTables.join(', ')}',
        );
      }

      // 0. Pull Shop Settings
      if (!missingTables.contains('shop_settings')) {
        final shopData =
            await _supabase.from('shop_settings').select().maybeSingle();
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
      }

      // 1. Pull Categories
      if (!missingTables.contains('categories')) {
        final catData = await _supabase.from('categories').select('name');
        final categories = catData.map((e) => e['name'] as String).toList();
        await HiveDatabase.categoryBox.clear();
        if (categories.isNotEmpty) {
          await HiveDatabase.categoryBox.addAll(categories);
        }
      }

      // 2. Pull Products
      if (!missingTables.contains('products')) {
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
      }

      // 3. Pull Sales
      if (!missingTables.contains('sales')) {
        final salesData = await _supabase.from('sales').select();
        await HiveDatabase.salesBox.clear();
        for (var s in salesData) {
          final model = SaleModel(
            id: s['id'],
            timestamp: DateTime.parse(s['timestamp']),
            totalAmount: (s['total_amount'] as num).toDouble(),
            paymentMethod: s['payment_method'],
            items: (s['items'] as List)
                .map((i) => SaleItemModel(
                      productId: i['productId'],
                      productName: i['productName'],
                      quantity: i['quantity'],
                      price: (i['price'] as num).toDouble(),
                    ))
                .toList(),
          );
          await HiveDatabase.salesBox.put(model.id, model);
        }
      }

      // 4. Pull Purchases
      if (!missingTables.contains('purchase_orders')) {
        final purchaseData = await _supabase.from('purchase_orders').select();
        await HiveDatabase.purchaseOrdersBox.clear();
        for (var p in purchaseData) {
          final model = PurchaseOrderModel(
            id: p['id'],
            timestamp: DateTime.parse(p['timestamp']),
            supplierName: p['supplier_name'] ?? '',
            totalAmount: (p['total_amount'] as num).toDouble(),
            notes: p['notes'] ?? '',
            items: (p['items'] as List)
                .map((i) => PurchaseItemModel(
                      productName: i['productName'],
                      quantity: i['quantity'],
                      unitCost: (i['unitCost'] as num).toDouble(),
                      productId: i['productId'],
                      size: i['size'],
                    ))
                .toList(),
          );
          await HiveDatabase.purchaseOrdersBox.put(model.id, model);
        }
      }

      // 5. Pull Suppliers
      if (!missingTables.contains('suppliers')) {
        final supplierData =
            await _supabase.from('suppliers').select().eq('user_id', user.id);
        final localSuppliers = supplierData.map((s) {
          return {
            'id': s['id']?.toString() ?? '',
            'name': s['name'] ?? '',
            'phone': s['phone'] ?? '',
            'openingBalance': (s['opening_balance'] as num?)?.toDouble() ?? 0,
            'createdAt':
                s['created_at']?.toString() ?? DateTime.now().toIso8601String(),
            'paidAmount': (s['paid_amount'] as num?)?.toDouble() ?? 0,
            'bills': s['bills'] ?? <dynamic>[],
            'payments': s['payments'] ?? <dynamic>[],
          };
        }).toList();
        await HiveDatabase.settingsBox.put(_supplierStorageKey, localSuppliers);
      }

      final syncedAt = DateTime.now();
      final message = missingTables.isEmpty
          ? 'Cloud sync successful'
          : 'Synced with missing tables: ${missingTables.join(', ')}';
      _setHealth(
        lastSyncAt: syncedAt,
        status: missingTables.isEmpty ? 'success' : 'degraded',
        missingTables: missingTables,
        message: message,
      );
      await _persistHealth(syncHealthNotifier.value);
    } catch (e) {
      _setHealth(
        status: 'failed',
        message: 'Sync failed: $e',
      );
      await _persistHealth(syncHealthNotifier.value);
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
        'items': order.items
            .map((i) => {
                  'productName': i.productName,
                  'quantity': i.quantity,
                  'unitCost': i.unitCost,
                  'productId': i.productId,
                  'size': i.size,
                })
            .toList(),
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
        'items': sale.items
            .map((i) => {
                  'productId': i.productId,
                  'productName': i.productName,
                  'quantity': i.quantity,
                  'price': i.price,
                })
            .toList(),
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

  /// Pushes all local supplier details to cloud as a full backup set.
  static Future<void> syncSuppliersToCloud() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      final missingTables = await checkRequiredTables();
      if (missingTables.contains('suppliers')) {
        _setHealth(
          status: 'degraded',
          missingTables: missingTables,
          message: 'Supplier sync skipped: missing suppliers table',
        );
        await _persistHealth(syncHealthNotifier.value);
        return;
      }

      final raw = HiveDatabase.settingsBox.get(_supplierStorageKey);
      final suppliers = raw is List ? raw.whereType<Map>().toList() : <Map>[];

      if (suppliers.isEmpty) return;

      final payload = suppliers.map((s) {
        return {
          'id': s['id']?.toString().isNotEmpty == true
              ? s['id']
              : DateTime.now().microsecondsSinceEpoch.toString(),
          'user_id': user.id,
          'name': s['name'] ?? '',
          'phone': s['phone'] ?? '',
          'opening_balance': (s['openingBalance'] as num?)?.toDouble() ?? 0,
          'created_at':
              s['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
          'paid_amount': (s['paidAmount'] as num?)?.toDouble() ?? 0,
          'bills': s['bills'] ?? <dynamic>[],
          'payments': s['payments'] ?? <dynamic>[],
        };
      }).toList();

      await _supabase.from('suppliers').upsert(payload);
    } catch (e) {
      _setHealth(status: 'failed', message: 'Supplier sync failed: $e');
      await _persistHealth(syncHealthNotifier.value);
    }
  }
}

class SyncHealth {
  final DateTime? lastSyncAt;
  final String status;
  final List<String> missingTables;
  final String? message;

  const SyncHealth({
    this.lastSyncAt,
    this.status = 'idle',
    this.missingTables = const [],
    this.message,
  });
}
