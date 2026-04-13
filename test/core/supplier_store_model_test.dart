import 'package:billo/core/utils/supplier_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Supplier model regression', () {
    test('remaining balance uses opening + purchase - paid', () {
      final supplier = SupplierModel(
        id: 's1',
        name: 'ABC',
        phone: '1234567890',
        openingBalance: 100,
        createdAt: DateTime(2026, 1, 1),
        paidAmount: 120,
        bills: [
          SupplierBill(
            id: 'b1',
            amount: 80,
            paidAmount: 20,
            date: DateTime(2026, 1, 2),
            note: 'bill',
          ),
        ],
        payments: const [],
      );

      expect(supplier.totalPurchase, 80);
      expect(supplier.remainingBalance, 60);
    });

    test('toMap/fromMap preserves bills and payments', () {
      final source = SupplierModel(
        id: 's2',
        name: 'XYZ',
        phone: '9999999999',
        openingBalance: 50,
        createdAt: DateTime(2026, 2, 1),
        paidAmount: 20,
        bills: [
          SupplierBill(
            id: 'b2',
            amount: 40,
            paidAmount: 5,
            date: DateTime(2026, 2, 2),
            note: 'PO-1',
          ),
        ],
        payments: [
          SupplierPayment(
            id: 'p1',
            amount: 20,
            date: DateTime(2026, 2, 3),
            note: 'manual',
          ),
        ],
      );

      final restored = SupplierModel.fromMap(source.toMap());
      expect(restored.name, source.name);
      expect(restored.bills.length, 1);
      expect(restored.payments.length, 1);
      expect(restored.remainingBalance, source.remainingBalance);
    });
  });
}
