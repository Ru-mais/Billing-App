import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:billo/core/data/hive_database.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../bloc/product_bloc.dart';
import '../../domain/entities/product.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_validators.dart';
import '../../../../core/utils/sync_manager.dart';

class AddProductPage extends StatefulWidget {
  const AddProductPage({super.key});

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _SizeStockRow {
  final TextEditingController sizeCtrl;
  final TextEditingController stockCtrl;
  _SizeStockRow()
      : sizeCtrl = TextEditingController(),
        stockCtrl = TextEditingController();

  void dispose() {
    sizeCtrl.dispose();
    stockCtrl.dispose();
  }
}

class _AddProductPageState extends State<AddProductPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _barcodeController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _purchaseRateController = TextEditingController();
  final TextEditingController _sellingRateController = TextEditingController();
  final TextEditingController _unifiedStockController = TextEditingController();
  
  bool _isSizeSpecific = false;
  String? _selectedCategory;
  final List<_SizeStockRow> _sizeRows = [_SizeStockRow()];

  @override
  void dispose() {
    _barcodeController.dispose();
    _nameController.dispose();
    _purchaseRateController.dispose();
    _sellingRateController.dispose();
    _unifiedStockController.dispose();
    for (final r in _sizeRows) {
      r.dispose();
    }
    super.dispose();
  }

  void _scanBarcode() async {
    final result = await context.push<String>('/scanner');
    if (result != null && result.isNotEmpty) {
      setState(() => _barcodeController.text = result);
    }
  }

  String _generateBarcode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(
            9, (index) => chars[random.nextInt(chars.length)])
        .join();
  }

  void _generateUniqueBarcode() {
    String newBarcode;
    bool exists;
    final products = context.read<ProductBloc>().state.products;
    do {
      newBarcode = _generateBarcode();
      exists = products.any((p) => p.barcode == newBarcode);
    } while (exists);
    setState(() => _barcodeController.text = newBarcode);
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      if (_selectedCategory == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a category'), backgroundColor: Colors.red),
        );
        return;
      }

      final Map<String, int> sizeStocks = {};
      if (_isSizeSpecific) {
        for (final row in _sizeRows) {
          final size = row.sizeCtrl.text.trim();
          final stock = int.tryParse(row.stockCtrl.text.trim()) ?? 0;
          if (size.isNotEmpty) {
            sizeStocks[size] = stock;
          }
        }
      }

      final products = context.read<ProductBloc>().state.products;
      if (products.any((p) => p.barcode == _barcodeController.text)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Barcode "${_barcodeController.text}" already exists!'), backgroundColor: Colors.red),
        );
        return;
      }

      final product = Product(
        id: const Uuid().v4(),
        name: _nameController.text.trim(),
        category: _selectedCategory!,
        barcode: _barcodeController.text.trim(),
        price: double.tryParse(_sellingRateController.text) ?? 0.0,
        purchasedRate: double.tryParse(_purchaseRateController.text) ?? 0.0,
        baseStock: _isSizeSpecific ? 0 : (int.tryParse(_unifiedStockController.text) ?? 0),
        isSizeSpecific: _isSizeSpecific,
        sizeStocks: sizeStocks,
      );

      context.read<ProductBloc>().add(AddProduct(product));
      context.pop();
    }
  }

  void _showAddCategoryDialog() {
    final TextEditingController ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Category'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'Category Name'),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(onPressed: () => context.pop(), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isNotEmpty) {
                if (!HiveDatabase.categoryBox.values.contains(name)) {
                  HiveDatabase.categoryBox.add(name);
                  SyncManager.syncCategories();
                }
                setState(() => _selectedCategory = name);
                context.pop();
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final scaffoldBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: const Text('Add Product', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTextField('Product Code', _barcodeController, 'Scan or enter code', validator: AppValidators.required('Required')),
                          Row(
                            children: [
                              _buildInlineButton(Icons.camera_alt_outlined, 'Scan', _scanBarcode),
                              const SizedBox(width: 12),
                              _buildInlineButton(Icons.auto_fix_high_outlined, 'Auto Generate', _generateUniqueBarcode),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _buildTextField('Product Name', _nameController, 'e.g. Nike Air Max', validator: AppValidators.required('Required')),
                          
                          const Text('Select Category', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: ValueListenableBuilder(
                                  valueListenable: HiveDatabase.categoryBox.listenable(),
                                  builder: (context, box, _) {
                                    final list = box.values.toList();
                                    return DropdownButtonFormField<String>(
                                      value: _selectedCategory,
                                      items: list.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                                      onChanged: (v) => setState(() => _selectedCategory = v),
                                      decoration: _fieldDecoration('Category'),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              _buildCircularAddButton(_showAddCategoryDialog),
                            ],
                          ),
                          const SizedBox(height: 20),
                          
                          _buildTextField('Purchase Rate', _purchaseRateController, '0.00', keyboardType: TextInputType.number),
                          _buildTextField('Selling Rate', _sellingRateController, '0.00', keyboardType: TextInputType.number, validator: AppValidators.required('Required')),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Has Size', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                              Switch(
                                value: _isSizeSpecific,
                                onChanged: (v) => setState(() => _isSizeSpecific = v),
                                activeColor: const Color(0xFF0F172A),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          if (!_isSizeSpecific)
                            _buildTextField('Total Stock', _unifiedStockController, 'e.g. 100', keyboardType: TextInputType.number),

                          if (_isSizeSpecific) ...[
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Sizes & Stocks', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
                                TextButton(
                                  onPressed: () => setState(() => _sizeRows.add(_SizeStockRow())),
                                  child: const Text('+ Add Size', style: TextStyle(fontSize: 12)),
                                )
                              ],
                            ),
                            ..._sizeRows.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final row = entry.value;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Row(
                                  children: [
                                    Expanded(child: TextFormField(controller: row.sizeCtrl, decoration: _fieldDecoration('Size'))),
                                    const SizedBox(width:  12),
                                    Expanded(child: TextFormField(controller: row.stockCtrl, keyboardType: TextInputType.number, decoration: _fieldDecoration('Stock'))),
                                    if (_sizeRows.length > 1)
                                      IconButton(onPressed: () => setState(() => _sizeRows.removeAt(idx)), icon: const Icon(Icons.remove_circle_outline, color: Colors.red)),
                                  ],
                                ),
                              );
                            }),
                          ]
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Bottom Actions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: cardBg, border: Border(top: BorderSide(color: borderColor))),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => context.pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: borderColor),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: isDark ? Colors.black : Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          elevation: 0,
                        ),
                        child: const Text('Save Product', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, String hint, {
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          decoration: _fieldDecoration(hint),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  InputDecoration _fieldDecoration(String hint) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? const Color(0xFF475569) : const Color(0xFFE2E8F0);
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
      filled: true,
      fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: borderColor)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: borderColor)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 1.5)),
    );
  }

  Widget _buildInlineButton(IconData icon, String label, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18, color: isDark ? Colors.white : Colors.black),
      label: Text(label, style: TextStyle(fontSize: 12, color: isDark ? Colors.white : Colors.black)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: BorderSide(color: isDark ? const Color(0xFF475569) : const Color(0xFFE2E8F0)),
      ),
    );
  }

  Widget _buildCircularAddButton(VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF475569) : const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Icon(Icons.add, size: 20),
      ),
    );
  }
}
