import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
                                children: [
                                  Row(
                                    children: [
                                      _infoBox('Total Credit', '₹${supplier.totalPurchase.toInt()}', Colors.blue),
                                      const SizedBox(width: 8),
                                      _infoBox('Total Paid', '₹${supplier.paidAmount.toInt()}', Colors.green),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextButton.icon(
                                          onPressed: () => _printAnalysis(supplier),
                                          icon: const Icon(Icons.file_download_outlined, size: 18),
                                          label: const Text('Report'),
                                        ),
                                      ),
                                      Expanded(
                                        child: TextButton.icon(
                                          onPressed: () => _deleteSupplier(supplier),
                                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                                          label: const Text('Delete', style: TextStyle(color: Colors.grey)),
                                        ),
                                      ),
                                    ],
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

  Widget _infoBox(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _styledDialog({required String title, required Widget content, required VoidCallback onConfirm}) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      content: content,
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
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
    // Re-use logic for PDF generation
  }
}
