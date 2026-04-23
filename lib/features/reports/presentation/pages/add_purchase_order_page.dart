import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/utils/sync_manager.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/data/hive_database.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/supplier_store.dart';
import '../../data/models/purchase_order_model.dart';
import '../../../product/data/models/product_model.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../product/presentation/bloc/product_bloc.dart';
import 'package:intl/intl.dart';

class AddPurchaseOrderPage extends StatefulWidget {
  const AddPurchaseOrderPage({super.key});

  @override
  State<AddPurchaseOrderPage> createState() => _AddPurchaseOrderPageState();
}

class _AddPurchaseOrderPageState extends State<AddPurchaseOrderPage> {
  final _formKey = GlobalKey<FormState>();
  final _supplierController = TextEditingController();
  final _supplierFocusNode = FocusNode();
  final _paidAmountController = TextEditingController(text: '0');
  final _notesController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  List<SupplierModel> _suppliers = [];

  final List<_ItemRow> _items = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _suppliers = SupplierStore.getAll();
    _addItem(); 
  }

  @override
  void dispose() {
    _supplierController.dispose();
    _supplierFocusNode.dispose();
    _paidAmountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _addItem() {
    setState(() {
      _items.add(_ItemRow());
    });
  }

  void _removeItem(int index) {
    if (_items.length > 1) {
      setState(() => _items.removeAt(index));
    }
  }

  double get _calculatedTotal {
    double total = 0;
    for (final row in _items) {
      final qty = int.tryParse(row.qtyController.text) ?? 0;
      final cost = double.tryParse(row.costController.text) ?? 0.0;
      total += (qty * cost);
    }
    return total;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    final paidAmount = double.tryParse(_paidAmountController.text.trim()) ?? 0;
    final totalAmount = _calculatedTotal;

    if (paidAmount < 0 || paidAmount > totalAmount) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Paid amount must be between 0 and total amount.'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    final filledItems = _items.where((row) =>
        row.productId != null &&
        (int.tryParse(row.qtyController.text) ?? 0) > 0 &&
        (double.tryParse(row.costController.text) ?? 0) > 0).toList();

    if (filledItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please add at least one valid product with quantity and cost.'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    // Size Validation
    for (var row in filledItems) {
      if (row.isSizeSpecific && row.selectedSize == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Please pick a size for ${row.nameController.text}'),
          backgroundColor: Colors.orange,
        ));
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final List<PurchaseItemModel> purchaseItems = [];
      // Use a local map to track product updates to handle multiple sizes of the same product
      final Map<String, ProductModel> productsToUpdate = {};

      for (final row in filledItems) {
        final qty = int.parse(row.qtyController.text);
        final cost = double.parse(row.costController.text);
        final pid = row.productId!;

        // Load from our tracker first, then from DB
        ProductModel? product = productsToUpdate[pid] ?? HiveDatabase.productBox.get(pid);
        
        if (product != null) {
          if (product.isSizeSpecific && row.selectedSize != null) {
            final currentStock = product.sizeStocks[row.selectedSize] ?? 0;
            final updatedStocks = Map<String, int>.from(product.sizeStocks);
            updatedStocks[row.selectedSize!] = currentStock + qty;
            product = product.copyWith(
              sizeStocks: updatedStocks, 
              purchasedRate: cost,
            );
          } else {
            product = product.copyWith(
              baseStock: product.baseStock + qty, 
              purchasedRate: cost,
            );
          }
          // Store in tracker
          productsToUpdate[pid] = product;
        }

        purchaseItems.add(PurchaseItemModel(
          productName: row.nameController.text.trim(),
          quantity: qty,
          unitCost: cost,
          productId: pid,
          size: row.selectedSize,
        ));
      }

      // Now save all updated products to Hive
      for (final pid in productsToUpdate.keys) {
        final up = productsToUpdate[pid]!;
        await HiveDatabase.productBox.put(pid, up);
        SyncManager.pushProduct(up);
      }

      final order = PurchaseOrderModel(
        id: const Uuid().v4(),
        timestamp: _selectedDate,
        supplierName: _supplierController.text.trim(),
        items: purchaseItems,
        totalAmount: totalAmount,
        notes: _notesController.text.trim(),
      );

      await HiveDatabase.purchaseOrdersBox.add(order);
      await SupplierStore.addPurchaseBill(
        supplierName: _supplierController.text.trim(),
        billAmount: totalAmount,
        paidAmount: paidAmount,
        date: _selectedDate,
        note: _notesController.text.trim().isEmpty ? 'Purchase Order' : _notesController.text.trim(),
        purchaseOrderId: order.id,
      );
      
      SyncManager.pushPurchaseOrder(order);
      if (mounted) context.read<ProductBloc>().add(LoadProducts());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Stock updated successfully!'),
          backgroundColor: Colors.green,
        ));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showQuickAddProductDialog(_ItemRow row) {
    final nameCtrl = TextEditingController(text: row.nameController.text.trim());
    final barcodeCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    
    final existingCategories = {
      ...HiveDatabase.categoryBox.values,
      ...HiveDatabase.productBox.values.map((p) => p.category),
    }.where((c) => c.isNotEmpty).toList();
    
    String? selectedCategory;
    bool isSizeSpecific = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setDS) {
        return AlertDialog(
          title: const Text('Add New Product'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: _inputDec(label: 'Name', icon: Icons.abc)),
                const SizedBox(height: 12),
                TextField(controller: barcodeCtrl, decoration: _inputDec(label: 'Barcode (Optional)', icon: Icons.qr_code)),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: _inputDec(label: 'Category', icon: Icons.category),
                  hint: const Text('Pick Category'),
                  items: [
                    ...existingCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))),
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
                      final newCat = await _showCreateCategoryDialog();
                      if (newCat != null && newCat.isNotEmpty) {
                        // Persist to Category Box so it shows up next time too
                        await HiveDatabase.categoryBox.add(newCat);
                        setDS(() {
                          if (!existingCategories.contains(newCat)) existingCategories.add(newCat);
                          selectedCategory = newCat;
                        });
                      }
                    } else {
                      setDS(() => selectedCategory = v);
                    }
                  },
                ),
                TextField(controller: priceCtrl, decoration: _inputDec(label: 'Sale Price', icon: Icons.payments), keyboardType: TextInputType.number),
                SwitchListTile(
                  title: const Text('Has Sizes?'),
                  value: isSizeSpecific,
                  onChanged: (val) => setDS(() => isSizeSpecific = val),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.isEmpty || priceCtrl.text.isEmpty || selectedCategory == null) return;
                final newProduct = ProductModel(
                  id: const Uuid().v4(),
                  name: nameCtrl.text.trim(),
                  barcode: barcodeCtrl.text.isEmpty ? DateTime.now().millisecondsSinceEpoch.toString() : barcodeCtrl.text,
                  category: selectedCategory!,
                  price: double.parse(priceCtrl.text),
                  purchasedRate: double.tryParse(row.costController.text) ?? 0.0,
                  sizeStocks: {},
                  isSizeSpecific: isSizeSpecific,
                  baseStock: 0,
                );
                await HiveDatabase.productBox.put(newProduct.id, newProduct);
                SyncManager.pushProduct(newProduct);
                if (mounted) context.read<ProductBloc>().add(LoadProducts());
                setState(() {
                  row.productId = newProduct.id;
                  row.nameController.text = newProduct.name;
                  row.isSizeSpecific = newProduct.isSizeSpecific;
                });
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        );
      }),
    );
  }

  Future<String?> _showCreateCategoryDialog() async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Category'),
        content: TextField(
          controller: ctrl, 
          decoration: const InputDecoration(hintText: 'Enter category name (e.g. Shoes)'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Create')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(title: const Text('Restock Inventory')),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _card(child: Column(children: [
                    _buildSupplierField(),
                    const SizedBox(height: 12),
                    _buildDateField(),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _paidAmountController, 
                      decoration: _inputDec(label: 'Paid to Supplier', icon: Icons.payments), 
                      keyboardType: TextInputType.number
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _notesController,
                      decoration: _inputDec(label: 'Notes (Optional)', icon: Icons.note_alt_outlined),
                    ),
                  ])),
                  const SizedBox(height: 20),
                  const Text('PRODUCTS TO RESTOCK', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
                  const SizedBox(height: 8),
                  ..._items.asMap().entries.map((e) => _buildItemRow(e.value, e.key)),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _addItem, 
                    icon: const Icon(Icons.add), 
                    label: const Text('Add Product'),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                  ),
                ],
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildSupplierField() {
    return RawAutocomplete<String>(
      textEditingController: _supplierController,
      focusNode: _supplierFocusNode,
      optionsBuilder: (v) => _suppliers.map((s) => s.name).where((n) => n.toLowerCase().contains(v.text.toLowerCase())),
      fieldViewBuilder: (ctx, ctrl, focus, _) => TextFormField(
        controller: ctrl, focusNode: focus,
        decoration: _inputDec(label: 'Supplier Name', icon: Icons.person),
        validator: (v) => v!.isEmpty ? 'Required' : null,
      ),
      optionsViewBuilder: (context, onSelected, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200, maxWidth: 300),
            child: ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: options.length,
              itemBuilder: (ctx, i) {
                final opt = options.elementAt(i);
                return ListTile(dense: true, title: Text(opt), onTap: () => onSelected(opt));
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateField() {
    return InkWell(
      onTap: _pickDate,
      child: InputDecorator(
        decoration: _inputDec(label: 'Date', icon: Icons.calendar_today),
        child: Text(DateFormat('dd / MM / yyyy').format(_selectedDate)),
      ),
    );
  }

  Widget _buildItemRow(_ItemRow row, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: _card(child: Column(children: [
        Row(children: [
          Expanded(child: RawAutocomplete<ProductModel>(
            textEditingController: row.nameController,
            focusNode: row.focusNode,
            optionsBuilder: (v) => v.text.isEmpty ? [] : HiveDatabase.productBox.values.where((p) => p.name.toLowerCase().contains(v.text.toLowerCase()) || p.barcode.contains(v.text)),
            displayStringForOption: (p) => p.name,
            onSelected: (p) => setState(() {
              row.productId = p.id;
              row.nameController.text = p.name;
              row.isSizeSpecific = p.isSizeSpecific;
              row.costController.text = p.purchasedRate.toString();
            }),
            fieldViewBuilder: (ctx, ctrl, focus, _) {
              return TextField(
                controller: ctrl, focusNode: focus,
                decoration: _inputDec(label: 'Search Product', icon: Icons.search).copyWith(
                  suffixIcon: row.productId != null 
                    ? TextButton(onPressed: () {
                        final nr = _ItemRow();
                        nr.productId = row.productId;
                        nr.nameController.text = row.nameController.text;
                        nr.isSizeSpecific = row.isSizeSpecific;
                        nr.costController.text = row.costController.text;
                        setState(() => _items.insert(index + 1, nr));
                      }, child: const Text('+ SIZE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)))
                    : IconButton(icon: const Icon(Icons.add_box_outlined, color: Colors.blue), onPressed: () => _showQuickAddProductDialog(row)),
                ),
              );
            },
            optionsViewBuilder: (context, onSelected, options) => Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200, maxWidth: 300),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (ctx, i) {
                      final opt = options.elementAt(i);
                      return ListTile(
                        dense: true,
                        title: Text(opt.name),
                        subtitle: Text('Cat: ${opt.category}', style: const TextStyle(fontSize: 10)),
                        onTap: () => onSelected(opt),
                      );
                    },
                  ),
                ),
              ),
            ),
          )),
          if (_items.length > 1) IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => _removeItem(index)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          if (row.isSizeSpecific) Expanded(child: DropdownButtonFormField<String>(
            value: row.selectedSize,
            decoration: _inputDec(label: 'Size', icon: Icons.straighten),
            hint: const Text('Size'),
            items: ['6','7','8','9','10','11'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (v) => setState(() => row.selectedSize = v),
          )),
          if (row.isSizeSpecific) const SizedBox(width: 8),
          Expanded(child: TextFormField(controller: row.qtyController, decoration: _inputDec(label: 'Qty', icon: Icons.plus_one), keyboardType: TextInputType.number, onChanged: (_) => setState((){}))),
          const SizedBox(width: 8),
          Expanded(child: TextFormField(controller: row.costController, decoration: _inputDec(label: 'Rate', icon: Icons.currency_rupee), keyboardType: TextInputType.number, onChanged: (_) => setState((){}))),
        ]),
      ])),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: Colors.white, 
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          const Text('ORDER TOTAL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
          Text('₹${_calculatedTotal.toStringAsFixed(0)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue)),
        ])),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor, 
            foregroundColor: Colors.white, 
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16), 
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
          ),
          child: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('SAVE RESTOCK'),
        ),
      ]),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(16), 
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)]
      ),
      child: child,
    );
  }

  InputDecoration _inputDec({required String label, required IconData icon}) {
    return InputDecoration(
      labelText: label, prefixIcon: Icon(icon, size: 18),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      filled: true, fillColor: Colors.grey[50],
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }
}

class _ItemRow {
  String? productId;
  final nameController = TextEditingController();
  final focusNode = FocusNode();
  final qtyController = TextEditingController(text: '1');
  final costController = TextEditingController(text: '0');
  String? selectedSize;
  bool isSizeSpecific = true;
}
