import 'package:billing_app/core/widgets/input_label.dart';
import 'package:billing_app/core/widgets/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

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
  late String _name;
  late double _price;
  late List<_SizeStockRow> _sizeRows;

  @override
  void initState() {
    super.initState();
    _name = widget.product.name;
    _price = widget.product.price;
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
    for (final r in _sizeRows) { r.dispose(); }
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final Map<String, int> sizeStocks = {};
      for (final row in _sizeRows) {
        final size = row.sizeCtrl.text.trim();
        final stock = int.tryParse(row.stockCtrl.text.trim()) ?? 0;
        if (size.isNotEmpty) {
          sizeStocks[size] = stock;
        }
      }

      final updatedProduct = Product(
        id: widget.product.id,
        name: _name,
        barcode: widget.product.barcode,
        price: _price,
        sizeStocks: sizeStocks,
      );

      context.read<ProductBloc>().add(UpdateProduct(updatedProduct));
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.chevron_left,
                size: 32, color: Theme.of(context).primaryColor),
            onPressed: () => context.pop(),
          ),
          title: const Text('Edit Product',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Display Barcode (immutable)
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.qr_code_scanner,
                            color: AppTheme.primaryColor, size: 28),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('BARCODE',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryColor
                                        .withValues(alpha: 0.7))),
                            const SizedBox(height: 2),
                            Text(widget.product.barcode,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'monospace')),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const InputLabel(text: 'Product Name'),
                  TextFormField(
                    initialValue: _name,
                    textCapitalization: TextCapitalization.words,
                    validator: AppValidators.required('Please enter a name'),
                    onSaved: (value) => _name = value!,
                  ),
                  const SizedBox(height: 24),

                  const InputLabel(text: 'Price'),
                  TextFormField(
                    initialValue: _price.toStringAsFixed(2),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
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

                  // Sizes & Stock section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const InputLabel(text: 'Sizes & Stock'),
                      TextButton.icon(
                        onPressed: () => setState(() => _sizeRows.add(_SizeStockRow())),
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

                  Row(
                    children: const [
                      Expanded(flex: 3, child: Text('Size', style: TextStyle(fontSize: 12, color: Colors.grey))),
                      SizedBox(width: 8),
                      Expanded(flex: 3, child: Text('Available Stock', style: TextStyle(fontSize: 12, color: Colors.grey))),
                      SizedBox(width: 36),
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
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              validator: (val) =>
                                  val == null || val.trim().isEmpty ? 'Required' : null,
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
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return 'Required';
                                if (int.tryParse(val) == null) return 'Invalid';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 22),
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
              ),
            ),
          ),
        ),
        bottomNavigationBar: PrimaryButton(
          onPressed: _submit,
          icon: Icons.save,
          label: 'Save Changes',
        ));
  }
}
