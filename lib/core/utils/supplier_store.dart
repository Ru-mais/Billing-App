import '../data/hive_database.dart';
import 'sync_manager.dart';

class SupplierStore {
  static const String _storageKey = 'supplier_data_v1';

  static List<SupplierModel> getAll() {
    final raw = HiveDatabase.settingsBox.get(_storageKey);
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((item) => SupplierModel.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  static Future<void> saveAll(List<SupplierModel> suppliers) async {
    await HiveDatabase.settingsBox.put(
      _storageKey,
      suppliers.map((supplier) => supplier.toMap()).toList(),
    );
    await SyncManager.syncSuppliersToCloud();
  }

  static Future<void> upsert(SupplierModel supplier) async {
    final suppliers = getAll();
    final index = suppliers.indexWhere((item) => item.id == supplier.id);
    if (index == -1) {
      suppliers.add(supplier);
    } else {
      suppliers[index] = supplier;
    }
    await saveAll(suppliers);
  }

  static Future<void> addPurchaseBill({
    required String supplierName,
    required double billAmount,
    double paidAmount = 0,
    DateTime? date,
    String note = '',
    String? purchaseOrderId,
  }) async {
    final trimmed = supplierName.trim();
    if (trimmed.isEmpty || billAmount <= 0 || paidAmount < 0) return;

    final now = date ?? DateTime.now();
    final suppliers = getAll();
    final index = suppliers.indexWhere(
      (item) => item.name.toLowerCase() == trimmed.toLowerCase(),
    );

    if (index == -1) {
      final paymentEntries = paidAmount > 0
          ? [
              SupplierPayment(
                id: '${now.microsecondsSinceEpoch}_payment',
                amount: paidAmount,
                date: now,
                note: 'Paid with purchase bill',
              )
            ]
          : <SupplierPayment>[];
      final supplier = SupplierModel(
        id: now.microsecondsSinceEpoch.toString(),
        name: trimmed,
        phone: '',
        openingBalance: 0,
        createdAt: now,
        paidAmount: paidAmount,
        bills: [
          SupplierBill(
            id: '${now.microsecondsSinceEpoch}_bill',
            amount: billAmount,
            paidAmount: paidAmount,
            date: now,
            note: note,
            purchaseOrderId: purchaseOrderId,
          ),
        ],
        payments: paymentEntries,
      );
      suppliers.add(supplier);
    } else {
      final current = suppliers[index];
      final nextPayments = List<SupplierPayment>.from(current.payments);
      if (paidAmount > 0) {
        nextPayments.add(
          SupplierPayment(
            id: '${now.microsecondsSinceEpoch}_payment',
            amount: paidAmount,
            date: now,
            note: 'Paid with purchase bill',
          ),
        );
      }
      suppliers[index] = current.copyWith(
        paidAmount: current.paidAmount + paidAmount,
        bills: [
          ...current.bills,
          SupplierBill(
            id: '${now.microsecondsSinceEpoch}_bill',
            amount: billAmount,
            paidAmount: paidAmount,
            date: now,
            note: note,
            purchaseOrderId: purchaseOrderId,
          ),
        ],
        payments: nextPayments,
      );
    }

    await saveAll(suppliers);
  }

  static Future<void> addSupplierPayment({
    required String supplierId,
    required double amount,
    String note = 'Manual payment',
  }) async {
    if (amount <= 0) return;
    final suppliers = getAll();
    final index = suppliers.indexWhere((item) => item.id == supplierId);
    if (index == -1) return;
    final current = suppliers[index];
    final now = DateTime.now();
    suppliers[index] = current.copyWith(
      paidAmount: current.paidAmount + amount,
      payments: [
        ...current.payments,
        SupplierPayment(
          id: '${now.microsecondsSinceEpoch}_payment',
          amount: amount,
          date: now,
          note: note.trim().isEmpty ? 'Manual payment' : note.trim(),
        ),
      ],
    );
    await saveAll(suppliers);
  }
}

class SupplierModel {
  final String id;
  final String name;
  final String phone;
  final double openingBalance;
  final DateTime createdAt;
  final double paidAmount;
  final List<SupplierBill> bills;
  final List<SupplierPayment> payments;

  SupplierModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.openingBalance,
    required this.createdAt,
    required this.paidAmount,
    required this.bills,
    required this.payments,
  });

  double get totalPurchase =>
      bills.fold(0.0, (sum, bill) => sum + bill.amount);

  double get remainingBalance => openingBalance + totalPurchase - paidAmount;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'openingBalance': openingBalance,
      'createdAt': createdAt.toIso8601String(),
      'paidAmount': paidAmount,
      'bills': bills.map((bill) => bill.toMap()).toList(),
      'payments': payments.map((payment) => payment.toMap()).toList(),
    };
  }

  factory SupplierModel.fromMap(Map<String, dynamic> map) {
    final rawBills = map['bills'];
    final rawPayments = map['payments'];
    final bills = rawBills is List
        ? rawBills
            .whereType<Map>()
            .map((item) => SupplierBill.fromMap(Map<String, dynamic>.from(item)))
            .toList()
        : <SupplierBill>[];
    final payments = rawPayments is List
        ? rawPayments
            .whereType<Map>()
            .map((item) => SupplierPayment.fromMap(Map<String, dynamic>.from(item)))
            .toList()
        : <SupplierPayment>[];

    return SupplierModel(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      openingBalance: (map['openingBalance'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      paidAmount: (map['paidAmount'] as num?)?.toDouble() ?? 0,
      bills: bills,
      payments: payments,
    );
  }

  SupplierModel copyWith({
    String? id,
    String? name,
    String? phone,
    double? openingBalance,
    DateTime? createdAt,
    double? paidAmount,
    List<SupplierBill>? bills,
    List<SupplierPayment>? payments,
  }) {
    return SupplierModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      openingBalance: openingBalance ?? this.openingBalance,
      createdAt: createdAt ?? this.createdAt,
      paidAmount: paidAmount ?? this.paidAmount,
      bills: bills ?? this.bills,
      payments: payments ?? this.payments,
    );
  }
}

class SupplierPayment {
  final String id;
  final double amount;
  final DateTime date;
  final String note;

  SupplierPayment({
    required this.id,
    required this.amount,
    required this.date,
    required this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'date': date.toIso8601String(),
      'note': note,
    };
  }

  factory SupplierPayment.fromMap(Map<String, dynamic> map) {
    return SupplierPayment(
      id: map['id']?.toString() ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      date: DateTime.tryParse(map['date']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      note: map['note']?.toString() ?? '',
    );
  }
}

class SupplierBill {
  final String id;
  final double amount;
  final double paidAmount;
  final DateTime date;
  final String note;
  final String? purchaseOrderId;

  SupplierBill({
    required this.id,
    required this.amount,
    required this.paidAmount,
    required this.date,
    required this.note,
    this.purchaseOrderId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'paidAmount': paidAmount,
      'date': date.toIso8601String(),
      'note': note,
      'purchaseOrderId': purchaseOrderId,
    };
  }

  factory SupplierBill.fromMap(Map<String, dynamic> map) {
    return SupplierBill(
      id: map['id']?.toString() ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      paidAmount: (map['paidAmount'] as num?)?.toDouble() ?? 0,
      date: DateTime.tryParse(map['date']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      note: map['note']?.toString() ?? '',
      purchaseOrderId: map['purchaseOrderId']?.toString(),
    );
  }
}
