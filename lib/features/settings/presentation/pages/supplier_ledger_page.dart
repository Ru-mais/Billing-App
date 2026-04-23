import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/pdf_helper.dart';
import '../../../../core/utils/supplier_store.dart';
import '../../../../core/data/hive_database.dart';
import '../../../reports/data/models/purchase_order_model.dart';

class SupplierLedgerPage extends StatefulWidget {
  const SupplierLedgerPage({super.key});

  @override
  State<SupplierLedgerPage> createState() => _SupplierLedgerPageState();
}

class _SupplierLedgerPageState extends State<SupplierLedgerPage> {
  final List<SupplierModel> _suppliers = [];
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
  }

  void _loadSuppliers() {
    final loaded = SupplierStore.getAll();
    setState(() {
      _suppliers
        ..clear()
        ..addAll(loaded);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _persistSuppliers() async {
    await SupplierStore.saveAll(_suppliers);
  }

  Future<void> _showAddSupplierDialog() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final openingBalanceController = TextEditingController();

    final added = await showDialog<bool>(
      context: context,
      builder: (context) {
        return _styledDialog(
          title: 'Add Supplier',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogField('Supplier Name', nameController, 'Enter name', icon: Icons.store_outlined),
              _buildDialogField('Phone Number', phoneController, 'Optional', icon: Icons.phone_outlined, keyboardType: TextInputType.phone),
              _buildDialogField('Opening Balance', openingBalanceController, '0.00', icon: Icons.account_balance_wallet_outlined, keyboardType: TextInputType.number),
            ],
          ),
          onConfirm: () {
            if (nameController.text.trim().isEmpty) return;
            Navigator.pop(context, true);
          },
        );
      },
    );

    if (added != true) return;

    final now = DateTime.now();
    final supplier = SupplierModel(
      id: now.microsecondsSinceEpoch.toString(),
      name: nameController.text.trim(),
      phone: phoneController.text.trim(),
      openingBalance: double.tryParse(openingBalanceController.text) ?? 0,
      createdAt: now,
      bills: [],
      paidAmount: 0,
      payments: [],
    );

    setState(() => _suppliers.add(supplier));
    await _persistSuppliers();
  }

  Future<void> _deleteSupplier(SupplierModel supplier) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Supplier'),
        content: Text('Are you sure you want to delete ${supplier.name}? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;
    setState(() => _suppliers.removeWhere((item) => item.id == supplier.id));
    await _persistSuppliers();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final scaffoldBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    final filtered = _suppliers.where((supplier) {
      final q = _query.trim().toLowerCase();
      if (q.isEmpty) return true;
      return supplier.name.toLowerCase().contains(q) || supplier.phone.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: const Text('Suppliers', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: _showAddSupplierDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: TextFormField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search suppliers...',
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: cardBg,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
              ),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('No suppliers found', style: TextStyle(color: Colors.grey)))
                : ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final supplier = filtered[index];
                      // Combine and sort transactions
                      final List<dynamic> transactions = [
                        ...supplier.bills.map((b) => {'type': 'bill', 'data': b, 'date': b.date}),
                        ...supplier.payments.map((p) => {'type': 'payment', 'data': p, 'date': p.date}),
                      ];
                      transactions.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

                      return Container(
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor),
                        ),
                        child: ExpansionTile(
                          shape: const RoundedRectangleBorder(side: BorderSide.none),
                          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                          leading: CircleAvatar(
                            backgroundColor: (isDark ? Colors.blue : Colors.blue[50])!,
                            child: const Icon(Icons.storefront_outlined, size: 20),
                          ),
                          title: Text(supplier.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Text('Bal: ₹${supplier.remainingBalance.toStringAsFixed(0)}', 
                            style: TextStyle(color: supplier.remainingBalance > 0 ? Colors.red : Colors.green, fontWeight: FontWeight.w600, fontSize: 12)),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      _infoBox('Total Credit', '₹${supplier.totalPurchase.toInt()}', Colors.blue),
                                      const SizedBox(width: 8),
                                      _infoBox(
                                        'Total Paid', 
                                        '₹${supplier.paidAmount.toInt()}', 
                                        Colors.green,
                                        onTap: () => _showPaymentHistory(supplier),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  const Text('RECENT TRANSACTIONS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
                                  const SizedBox(height: 8),
                                  if (transactions.isEmpty)
                                    const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 8.0),
                                      child: Text('No transactions yet.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                    )
                                  else
                                    ...transactions.take(5).map((tx) {
                                      final bool isBill = tx['type'] == 'bill';
                                      final date = tx['date'] as DateTime;
                                      final amount = isBill ? (tx['data'] as SupplierBill).amount : (tx['data'] as SupplierPayment).amount;
                                      
                                      return Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () {
                                            if (isBill) {
                                              final bill = tx['data'] as SupplierBill;
                                              final orderId = bill.purchaseOrderId;
                                              if (orderId != null && orderId.trim().isNotEmpty) {
                                                final order = HiveDatabase.purchaseOrdersBox.get(orderId);
                                                if (order != null) {
                                                  _showPurchaseDetailsPopup(context, order);
                                                  return;
                                                }
                                              }
                                              _showBillDetailsPopup(context, bill);
                                            } else {
                                              final payment = tx['data'] as SupplierPayment;
                                              _showPaymentDetailsPopup(context, payment);
                                            }
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                                            child: Row(
                                              children: [
                                                Icon(isBill ? Icons.receipt_outlined : Icons.payment_outlined, 
                                                  size: 16, color: isBill ? Colors.red : Colors.green),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(isBill ? 'Bill Received' : 'Payment Made', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                                      Text(DateFormat('dd MMM yyyy').format(date), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                                    ],
                                                  ),
                                                ),
                                                Text('₹${amount.toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.bold, color: isBill ? Colors.red : Colors.green)),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    }),
                                  const Divider(),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextButton.icon(
                                          onPressed: () => _showAddPaymentDialog(supplier),
                                          icon: const Icon(Icons.add_card_outlined, size: 18, color: Colors.green),
                                          label: const Text('Add Payment', style: TextStyle(color: Colors.green)),
                                        ),
                                      ),
                                      Expanded(
                                        child: TextButton.icon(
                                          onPressed: () => _printAnalysis(supplier),
                                          icon: const Icon(Icons.file_download_outlined, size: 18),
                                          label: const Text('Export PDF'),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(),
                                  Center(
                                    child: TextButton.icon(
                                      onPressed: () => _deleteSupplier(supplier),
                                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                                      label: const Text('Delete Supplier', style: TextStyle(color: Colors.grey)),
                                    ),
                                  )
                                ],
                              ),
                            )
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showPaymentHistory(SupplierModel supplier) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        final payments = supplier.payments.reversed.toList();
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Payment History: ${supplier.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const Divider(height: 32),
              if (payments.isEmpty)
                const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('No payments recorded.')))
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: payments.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, i) {
                      final p = payments[i];
                      return ListTile(
                        leading: const Icon(Icons.check_circle_outline, color: Colors.green),
                        title: Text('₹${p.amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(p.note.isEmpty ? 'Manual Payment' : p.note),
                        trailing: Text(DateFormat('dd MMM yyyy').format(p.date), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showAddPaymentDialog(SupplierModel supplier) async {
    final amountController = TextEditingController();
    final noteController = TextEditingController();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogCtx) => _styledDialog(
        title: 'Add Payment',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Paying: ${supplier.name}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 16),
            _buildDialogField('Amount Paid', amountController, '₹ 0.00', keyboardType: TextInputType.number, icon: Icons.payments),
            _buildDialogField('Notes (Optional)', noteController, 'e.g. UPI, Cash', icon: Icons.note_alt),
          ],
        ),
        onConfirm: () {
          final amt = double.tryParse(amountController.text) ?? 0;
          if (amt <= 0) return;
          Navigator.pop(dialogCtx, {'amount': amt, 'note': noteController.text});
        },
      ),
    );

    if (result != null) {
      await SupplierStore.addSupplierPayment(
        supplierId: supplier.id,
        amount: result['amount'],
        note: result['note'],
      );
      if (mounted) {
        _loadSuppliers();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment recorded successfully!')));
      }
    }
  }

  void _showPurchaseDetailsPopup(BuildContext context, PurchaseOrderModel order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Purchase Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
              ],
            ),
            Text('Date: ${DateFormat('dd MMM yyyy').format(order.timestamp)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const Divider(height: 32),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: order.items.length,
                itemBuilder: (context, i) {
                  final item = order.items[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(child: Text(item.productName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                        Text('${item.quantity} x ₹${item.unitCost.toInt()}'),
                        const SizedBox(width: 12),
                        Text('₹${(item.quantity * item.unitCost).toInt()}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('TOTAL AMOUNT', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('₹${order.totalAmount.toInt()}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red)),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showBillDetailsPopup(BuildContext context, SupplierBill bill) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Bill Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
              ],
            ),
            Text('Date: ${DateFormat('dd MMM yyyy').format(bill.date)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Bill Amount:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text('₹${bill.amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            const SizedBox(height: 12),
            if (bill.note.isNotEmpty) ...[
              const Text('Note:', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(bill.note, style: const TextStyle(fontSize: 14)),
            ],
            const SizedBox(height: 24),
            const Text('Note: This is a standalone bill entry without a linked item list.', 
              style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic)),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showPaymentDetailsPopup(BuildContext context, SupplierPayment payment) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Payment Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
              ],
            ),
            Text('Date: ${DateFormat('dd MMM yyyy hh:mm a').format(payment.date)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Amount Paid:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text('₹${payment.amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.green)),
              ],
            ),
            const SizedBox(height: 12),
            if (payment.note.isNotEmpty) ...[
              const Text('Note:', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(payment.note, style: const TextStyle(fontSize: 14)),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _infoBox(String label, String value, Color color, {VoidCallback? onTap}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
                  if (onTap != null) Icon(Icons.arrow_drop_down, size: 16, color: color),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _styledDialog({required String title, required Widget content, required VoidCallback onConfirm}) {
    return Builder(
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: content,
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: onConfirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogField(String label, TextEditingController controller, String hint, {IconData? icon, TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: icon != null ? Icon(icon, size: 20) : null,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Future<void> _printAnalysis(SupplierModel supplier) async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generating PDF Report...'), duration: Duration(seconds: 1)));
    try {
      final mappedBills = supplier.bills.map((b) => <String, String>{
        'date': DateFormat('dd MMM yyyy').format(b.date),
        'amount': b.amount.toStringAsFixed(2),
        'paid': b.paidAmount.toStringAsFixed(2),
        'note': b.note,
      }).toList();

      final mappedPayments = supplier.payments.map((p) => <String, String>{
        'date': DateFormat('dd MMM yyyy').format(p.date),
        'amount': p.amount.toStringAsFixed(2),
        'note': p.note,
      }).toList();

      await PdfHelper.generateSupplierAnalysisPdf(
        supplierName: supplier.name,
        phone: supplier.phone,
        openingBalance: supplier.openingBalance,
        totalCredit: supplier.totalPurchase,
        totalPaid: supplier.paidAmount,
        remainingBalance: supplier.remainingBalance,
        bills: mappedBills,
        payments: mappedPayments,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to generate PDF: $e'), backgroundColor: Colors.red));
      }
    }
  }
}
