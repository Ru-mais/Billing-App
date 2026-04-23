import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:billo/core/data/hive_database.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../bloc/product_bloc.dart';
import '../../domain/entities/product.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_validators.dart';

class EditProductPage extends StatefulWidget {
  final Product product;
  const EditProductPage({super.key, required this.product});

  @override
  State<EditProductPage> createState() => _EditProductPageState();
}

class _SizeStockRow {
  final TextEditingController sizeCtrl;
  final TextEditingController stockCtrl;
  _SizeStockRow({String size = '', int stock = 0})
      : sizeCtrl = TextEditingController(text: size),
        stockCtrl = TextEditingController(text: stock.toString());

  void dispose() {
    sizeCtrl.dispose();
    stockCtrl.dispose();
  }
}

class _EditProductPageState extends State<EditProductPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _purchaseRateController;
  late TextEditingController _sellingRateController;
  late TextEditingController _unifiedStockController;
  
  late bool _isSizeSpecific;
  String? _selectedCategory;
  late List<_SizeStockRow> _sizeRows;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product.name);
    _purchaseRateController = TextEditingController(text: widget.product.purchasedRate.toStringAsFixed(2));
    _sellingRateController = TextEditingController(text: widget.product.price.toStringAsFixed(2));
    _unifiedStockController = TextEditingController(text: widget.product.baseStock.toString());
    _isSizeSpecific = widget.product.isSizeSpecific;
    _selectedCategory = widget.product.category;

    if (widget.product.sizeStocks.isNotEmpty) {
      _sizeRows = widget.product.sizeStocks.entries
          .map((e) => _SizeStockRow(size: e.key, stock: e.value))
          .toList();
    } else {
      _sizeRows = [_SizeStockRow()];
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _purchaseRateController.dispose();
    _sellingRateController.dispose();
    _unifiedStockController.dispose();
    for (final r in _sizeRows) {
      r.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
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

      final updatedProduct = Product(
        id: widget.product.id,
        name: _nameController.text.trim(),
        category: _selectedCategory!,
        barcode: widget.product.barcode,
        price: double.tryParse(_sellingRateController.text) ?? 0.0,
        purchasedRate: double.tryParse(_purchaseRateController.text) ?? 0.0,
        baseStock: _isSizeSpecific ? 0 : (int.tryParse(_unifiedStockController.text) ?? 0),
        isSizeSpecific: _isSizeSpecific,
        sizeStocks: sizeStocks,
      );

      context.read<ProductBloc>().add(UpdateProduct(updatedProduct));
      context.pop();
    }
  }

  Future<String?> _showCreateCategoryDialogDirect() async {
    final TextEditingController ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Category'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'Enter category name (e.g. Shoes)'),
          autofocus: true,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showAddCategoryDialog() {
    // Replaced by _showCreateCategoryDialogDirect
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
        title: const Text('Edit Product', style: TextStyle(fontWeight: FontWeight.bold)),
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
                          // Read-only Barcode
                          const Text('Product Code', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
                          const SizedBox(height: 6),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A).withOpacity(0.5) : Colors.grey[100],
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: borderColor),
                            ),
                            child: Text(widget.product.barcode, style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                          ),
                          const SizedBox(height: 20),

                          _buildTextField('Product Name', _nameController, 'e.g. Nike Air Max', validator: AppValidators.required('Required')),
                          
                          const Text('Select Category', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
                          const SizedBox(height: 6),
                          ValueListenableBuilder(
                            valueListenable: HiveDatabase.categoryBox.listenable(),
                            builder: (context, box, _) {
                              final boxCats = box.values.map((s) => s.toString()).toList();
                              final productCats = HiveDatabase.productBox.values.map((p) => p.category).toList();
                              final allCats = {...boxCats, ...productCats}.toList()..sort();
                              
                              return DropdownButtonFormField<String>(
                                value: allCats.contains(_selectedCategory) ? _selectedCategory : null,
                                decoration: _fieldDecoration('Category'),
                                items: [
                                  ...allCats.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                                  const DropdownMenuItem(
                                    value: '__add_new__',
                                    child: Row(
                                      children: [
                                        Icon(Icons.add, size: 16, color: Colors.blue),
                                        SizedBox(width: 8),
                                        Text('Add New...', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ],
                                onChanged: (v) async {
                                  if (v == '__add_new__') {
                                    final newCat = await _showCreateCategoryDialogDirect();
                                    if (newCat != null && newCat.isNotEmpty) {
                                      if (!HiveDatabase.categoryBox.values.contains(newCat)) {
                                        await HiveDatabase.categoryBox.add(newCat);
                                      }
                                      setState(() => _selectedCategory = newCat);
                                    }
                                  } else {
                                    setState(() => _selectedCategory = v);
                                  }
                                },
                              );
                            },
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
                      child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
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

  Widget _buildCircularAddButton(VoidCallback onTap) {
    // Replaced by inline entry
    return const SizedBox();
  }
}
