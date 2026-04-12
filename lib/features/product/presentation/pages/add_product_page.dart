import 'package:billo/core/widgets/input_label.dart';
import 'package:billo/core/widgets/primary_button.dart';
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
  String _name = '';
  String _barcode = '';
  double _price = 0.0;
  double _purchasedRate = 0.0;
  int _unifiedStock = 0;
  bool _isSizeSpecific = true;
  String? _selectedCategory;
  final List<_SizeStockRow> _sizeRows = [_SizeStockRow()];

  @override
  void dispose() {
    for (final r in _sizeRows) {
      r.dispose();
    }
    super.dispose();
  }

  void _scanBarcode() async {
    final result = await context.push<String>('/scanner');
    if (result != null && result.isNotEmpty) {
      setState(() => _barcode = result);
    }
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      if (_selectedCategory == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select or add a category'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Build sizeStocks map from rows if size specific
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

      final productState = context.read<ProductBloc>().state;
      final existingProduct =
          productState.products.where((p) => p.barcode == _barcode).firstOrNull;

      if (existingProduct != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Product with barcode "$_barcode" already exists!'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final product = Product(
        id: const Uuid().v4(),
        name: _name,
        category: _selectedCategory!,
        barcode: _barcode,
        price: _price,
        purchasedRate: _purchasedRate,
        baseStock: _isSizeSpecific ? 0 : _unifiedStock,
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
          TextButton(
              onPressed: () => context.pop(), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isNotEmpty) {
                if (HiveDatabase.categoryBox.values.contains(name)) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(content: Text('Category already exists')));
                  return;
                }
                HiveDatabase.categoryBox.add(name);
                
                // Sync Categories to Cloud
                SyncManager.syncCategories();

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
    return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.chevron_left,
                size: 28, color: Theme.of(context).primaryColor),
            onPressed: () => context.pop(),
          ),
          title: const Text('Add Product',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const InputLabel(text: 'Barcode'),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          key: ValueKey(_barcode),
                          initialValue: _barcode,
                          decoration: const InputDecoration(
                            hintText: 'Scan or enter barcode',
                          ),
                          validator: AppValidators.required('Please enter a barcode'),
                          onSaved: (value) => _barcode = value!,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.qr_code_scanner,
                              color: AppTheme.primaryColor),
                          onPressed: _scanBarcode,
                          padding: const EdgeInsets.all(14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text('Tap the icon to open camera scanner',
                      style: TextStyle(fontSize: 12, color: Color(0xFF4C669A))),
                  const SizedBox(height: 24),
                  const InputLabel(text: 'Product Name'),
                  TextFormField(
                    decoration: const InputDecoration(hintText: 'e.g. Footwear Name'),
                    textCapitalization: TextCapitalization.words,
                    validator: AppValidators.required('Please enter a name'),
                    onSaved: (value) => _name = value!,
                  ),
                  const SizedBox(height: 24),
                  const InputLabel(text: 'Category'),
                  Row(
                    children: [
                      Expanded(
                        child: ValueListenableBuilder<Box<String>>(
                          valueListenable: HiveDatabase.categoryBox.listenable(),
                          builder: (context, box, _) {
                            final categories = box.values.toList();
                            return DropdownButtonFormField<String>(
                              initialValue: _selectedCategory,
                              decoration: const InputDecoration(
                                hintText: 'Select Category',
                              ),
                              items: categories
                                  .map((c) => DropdownMenuItem(
                                      value: c, child: Text(c)))
                                  .toList(),
                              onChanged: (val) =>
                                  setState(() => _selectedCategory = val),
                              validator: (val) => val == null
                                  ? 'Category is mandatory'
                                  : null,
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.add,
                              color: AppTheme.primaryColor),
                          onPressed: _showAddCategoryDialog,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const InputLabel(text: 'Purchased Rate'),
                  TextFormField(
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      hintText: '0.00',
                      prefixText: '₹ ',
                      prefixStyle: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black),
                    ),
                    onSaved: (value) => _purchasedRate =
                        value != null && value.isNotEmpty
                            ? double.parse(value)
                            : 0.0,
                  ),
                  const SizedBox(height: 24),
                  const InputLabel(text: 'Selling Price'),
                  TextFormField(
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      hintText: '0.00',
                      prefixText: '₹ ',
                      prefixStyle: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black),
                    ),
                    validator: AppValidators.price,
                    onSaved: (value) => _price = double.parse(value!),
                  ),
                  const SizedBox(height: 24),
                  SwitchListTile(
                    title: const Text('Specify Sizes & Stocks',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: const Text(
                        'Disable to manage stock as a single unified quantity',
                        style: TextStyle(fontSize: 12)),
                    value: _isSizeSpecific,
                    onChanged: (val) => setState(() => _isSizeSpecific = val),
                    activeColor: AppTheme.primaryColor,
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 16),

                  if (!_isSizeSpecific) ...[
                    const InputLabel(text: 'Available Stock'),
                    TextFormField(
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(hintText: 'e.g. 100'),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter stock';
                        }
                        if (int.tryParse(val) == null) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
                      onSaved: (value) => _unifiedStock = int.parse(value!),
                    ),
                  ],

                  if (_isSizeSpecific) ...[
                    // Sizes & Stock section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const InputLabel(text: 'Sizes & Stock'),
                        TextButton.icon(
                          onPressed: () =>
                              setState(() => _sizeRows.add(_SizeStockRow())),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Size'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.primaryColor,
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Header row
                    Row(
                      children: [
                        const Expanded(
                            flex: 3,
                            child: Text('Size',
                                style:
                                    TextStyle(fontSize: 12, color: Colors.grey))),
                        const SizedBox(width: 8),
                        const Expanded(
                            flex: 3,
                            child: Text('Available Stock',
                                style:
                                    TextStyle(fontSize: 12, color: Colors.grey))),
                        const SizedBox(width: 36),
                      ],
                    ),
                    const SizedBox(height: 4),

                    ...List.generate(_sizeRows.length, (index) {
                      final row = _sizeRows[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: row.sizeCtrl,
                                decoration: const InputDecoration(
                                  hintText: 'e.g. 7',
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                ),
                                validator: (val) =>
                                    _isSizeSpecific && (val == null || val.trim().isEmpty)
                                        ? 'Required'
                                        : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: row.stockCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  hintText: '0',
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                ),
                                validator: (val) {
                                  if (!_isSizeSpecific) return null;
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Required';
                                  }
                                  if (int.tryParse(val) == null) return 'Invalid';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline,
                                  color: Colors.red, size: 22),
                              onPressed: _sizeRows.length > 1
                                  ? () => setState(() {
                                        _sizeRows[index].dispose();
                                        _sizeRows.removeAt(index);
                                      })
                                  : null,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: PrimaryButton(
          onPressed: _submit,
          icon: Icons.add_circle,
          label: 'Add Product',
        ));
  }
}
