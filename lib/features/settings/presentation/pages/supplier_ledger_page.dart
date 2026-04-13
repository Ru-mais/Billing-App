import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/pdf_helper.dart';
import '../../../../core/utils/supplier_store.dart';

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
        return AlertDialog(
          title: const Text('Add Supplier'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Supplier Name',
                    prefixIcon: Icon(Icons.store_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone (optional)',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: openingBalanceController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Opening Balance',
                    prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty) return;
                Navigator.pop(context, true);
              },
              child: const Text('Save'),
            ),
          ],
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

  Future<void> _addPayment(SupplierModel supplier) async {
    final amountController = TextEditingController();
    final noteController = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Paid Amount'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Paid Amount',
                    prefixIcon: Icon(Icons.currency_rupee),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(amountController.text);
                if (amount == null || amount <= 0) return;
                Navigator.pop(context, true);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (saved != true) return;

    await SupplierStore.addSupplierPayment(
      supplierId: supplier.id,
      amount: double.parse(amountController.text),
      note: noteController.text,
    );
    _loadSuppliers();
  }

  void _showBillDetails(SupplierModel supplier, SupplierBill bill) {
    final due = bill.amount - bill.paidAmount;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bill Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Supplier: ${supplier.name}'),
            const SizedBox(height: 8),
            Text(
              'Date: ${bill.date.day.toString().padLeft(2, '0')}/${bill.date.month.toString().padLeft(2, '0')}/${bill.date.year}',
            ),
            const SizedBox(height: 8),
            Text('Bill Amount: ₹${bill.amount.toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            Text('Paid: ₹${bill.paidAmount.toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            Text(
              'Due: ₹${due.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: due > 0 ? Colors.redAccent : Colors.green,
              ),
            ),
            if (bill.note.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Note: ${bill.note}'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showPaidHistory(SupplierModel supplier) {
    final history = supplier.payments.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${supplier.name} - Paid History'),
        content: SizedBox(
          width: double.maxFinite,
          child: history.isEmpty
              ? const Text('No paid amount history yet.')
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: history.length,
                  separatorBuilder: (_, __) => const Divider(height: 12),
                  itemBuilder: (context, index) {
                    final item = history[index];
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${item.date.day.toString().padLeft(2, '0')}/${item.date.month.toString().padLeft(2, '0')}/${item.date.year}',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[600]),
                              ),
                              Text(
                                item.note,
                                style: const TextStyle(fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '₹${item.amount.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSupplier(SupplierModel supplier) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Supplier'),
        content: Text('Delete ${supplier.name} and all ledger data?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    setState(() => _suppliers.removeWhere((item) => item.id == supplier.id));
    await _persistSuppliers();
  }

  Future<void> _printSupplierAnalysis(SupplierModel supplier) async {
    final bills = supplier.bills
        .map((bill) => {
              'date':
                  '${bill.date.day.toString().padLeft(2, '0')}/${bill.date.month.toString().padLeft(2, '0')}/${bill.date.year}',
              'amount': '₹${bill.amount.toStringAsFixed(2)}',
              'paid': '₹${bill.paidAmount.toStringAsFixed(2)}',
              'note': bill.note.isEmpty ? 'Bill' : bill.note,
            })
        .toList();

    final payments = supplier.payments
        .map((payment) => {
              'date':
                  '${payment.date.day.toString().padLeft(2, '0')}/${payment.date.month.toString().padLeft(2, '0')}/${payment.date.year}',
              'amount': '₹${payment.amount.toStringAsFixed(2)}',
              'note': payment.note,
            })
        .toList();

    try {
      await PdfHelper.generateSupplierAnalysisPdf(
        supplierName: supplier.name,
        phone: supplier.phone,
        openingBalance: supplier.openingBalance,
        totalCredit: supplier.totalPurchase,
        totalPaid: supplier.paidAmount,
        remainingBalance: supplier.remainingBalance,
        bills: bills,
        payments: payments,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to export analysis: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Supplier',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.chevron_left,
            size: 28,
            color: Theme.of(context).primaryColor,
          ),
          onPressed: () => context.pop(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddSupplierDialog,
        backgroundColor: AppTheme.primaryColor,
        icon: const Icon(Icons.add_business, color: Colors.white),
        label:
            const Text('Add Supplier', style: TextStyle(color: Colors.white)),
      ),
      body: _suppliers.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No suppliers yet.\nAdd supplier with phone and opening balance.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ),
            )
          : Builder(builder: (context) {
              final filtered = _suppliers.where((supplier) {
                final q = _query.trim().toLowerCase();
                if (q.isEmpty) return true;
                return supplier.name.toLowerCase().contains(q) ||
                    supplier.phone.toLowerCase().contains(q);
              }).toList();
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Search supplier by name or phone',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) => setState(() => _query = value),
                    ),
                  ),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(
                            child: Text(
                              'No suppliers match your search.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final supplier = filtered[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ExpansionTile(
                                  tilePadding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  title: Text(
                                    supplier.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700),
                                  ),
                                  subtitle: Text(
                                    'Remaining: ${supplier.remainingBalance.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      color: supplier.remainingBalance > 0
                                          ? Colors.redAccent
                                          : Colors.green,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  trailing: IconButton(
                                    onPressed: () => _deleteSupplier(supplier),
                                    icon: const Icon(Icons.delete_outline,
                                        color: Colors.red),
                                  ),
                                  childrenPadding:
                                      const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _statChip(
                                            label: 'Remaining',
                                            value: supplier.remainingBalance,
                                            color: Colors.orange,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: _statChip(
                                            label: 'Credit',
                                            value: supplier.totalPurchase,
                                            color: Colors.blue,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: _statChip(
                                            label: 'Paid',
                                            value: supplier.paidAmount,
                                            color: Colors.green,
                                            onTap: () =>
                                                _showPaidHistory(supplier),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (supplier.phone.isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Icon(Icons.phone_outlined,
                                              size: 16,
                                              color: Colors.grey[600]),
                                          const SizedBox(width: 6),
                                          Text(supplier.phone),
                                        ],
                                      ),
                                    ],
                                    const SizedBox(height: 12),
                                    if (supplier.bills.isNotEmpty)
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'PURCHASE BILLS',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 1,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          ...supplier.bills.reversed
                                              .take(8)
                                              .map(
                                                (bill) => InkWell(
                                                  onTap: () => _showBillDetails(
                                                      supplier, bill),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  child: Padding(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        vertical: 6,
                                                        horizontal: 4),
                                                    child: Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .spaceBetween,
                                                      children: [
                                                        Expanded(
                                                          flex: 3,
                                                          child: Text(
                                                            '${bill.date.day.toString().padLeft(2, '0')}/${bill.date.month.toString().padLeft(2, '0')}/${bill.date.year}',
                                                            style: TextStyle(
                                                                fontSize: 12,
                                                                color: Colors
                                                                    .grey[600]),
                                                          ),
                                                        ),
                                                        Expanded(
                                                          flex: 4,
                                                          child: Text(
                                                            bill.note.isEmpty
                                                                ? 'Bill'
                                                                : bill.note,
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style:
                                                                const TextStyle(
                                                                    fontSize:
                                                                        12),
                                                          ),
                                                        ),
                                                        Expanded(
                                                          flex: 3,
                                                          child: Text(
                                                            '₹${bill.amount.toStringAsFixed(2)}',
                                                            textAlign:
                                                                TextAlign.right,
                                                            style:
                                                                const TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                        ],
                                      ),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        OutlinedButton.icon(
                                          onPressed: () =>
                                              _addPayment(supplier),
                                          icon: const Icon(
                                              Icons.account_balance_outlined),
                                          label: const Text('Add Paid Amount'),
                                        ),
                                        OutlinedButton.icon(
                                          onPressed: () =>
                                              _printSupplierAnalysis(supplier),
                                          icon: const Icon(
                                              Icons.picture_as_pdf_outlined),
                                          label: const Text('Print Analysis'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            }),
    );
  }

  Widget _statChip({
    required String label,
    required double value,
    required Color color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value.toStringAsFixed(2),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
