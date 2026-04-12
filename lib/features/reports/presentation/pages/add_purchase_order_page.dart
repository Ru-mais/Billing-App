import 'package:flutter/material.dart';
import '../../../../core/utils/sync_manager.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/data/hive_database.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/purchase_order_model.dart';
import '../../../product/data/models/product_model.dart';

class AddPurchaseOrderPage extends StatefulWidget {
  const AddPurchaseOrderPage({super.key});

  @override
  State<AddPurchaseOrderPage> createState() => _AddPurchaseOrderPageState();
}

class _AddPurchaseOrderPageState extends State<AddPurchaseOrderPage> {
  final _formKey = GlobalKey<FormState>();
  final _supplierController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  final List<_ItemRow> _items = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _addItem(); // Start with one empty row
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
    return _items.fold(0.0, (sum, row) {
      final qty = int.tryParse(row.qtyController.text) ?? 0;
      final cost = double.tryParse(row.costController.text) ?? 0.0;
      return sum + (qty * cost);
    });
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

    // Validate at least one item is filled
    final filledItems = _items.where((row) =>
        row.nameController.text.trim().isNotEmpty &&
        (int.tryParse(row.qtyController.text) ?? 0) > 0 &&
        (double.tryParse(row.costController.text) ?? 0) > 0);

    if (filledItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please add at least one valid item.'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    setState(() => _isSaving = true);

    try {
      final List<PurchaseItemModel> purchaseItems = [];

      for (final row in filledItems) {
        final qty = int.parse(row.qtyController.text);
        final cost = double.parse(row.costController.text);

        // If it's a known product, we automatically update SIT (Stock in Trade)
        if (row.productId != null) {
          final product = HiveDatabase.productBox.get(row.productId);
          if (product != null) {
            ProductModel updatedProduct;

            if (product.isSizeSpecific && row.selectedSize != null) {
              // Restock specific size
              final currentStock = product.sizeStocks[row.selectedSize] ?? 0;
              final updatedStocks = Map<String, int>.from(product.sizeStocks);
              updatedStocks[row.selectedSize!] = currentStock + qty;
              
              updatedProduct = product.copyWith(
                sizeStocks: updatedStocks,
                purchasedRate: cost, // Auto-update purchased rate
              );
            } else {
              // Restock unified product
              updatedProduct = product.copyWith(
                baseStock: product.baseStock + qty,
                purchasedRate: cost,
              );
            }

            // Save and Sync updated product
            await HiveDatabase.productBox.put(updatedProduct.id, updatedProduct);
            SyncManager.pushProduct(updatedProduct);
          }
        }

        purchaseItems.add(PurchaseItemModel(
          productName: row.nameController.text.trim(),
          quantity: qty,
          unitCost: cost,
          productId: row.productId,
          size: row.selectedSize,
        ));
      }

      final order = PurchaseOrderModel(
        id: const Uuid().v4(),
        timestamp: _selectedDate,
        supplierName: _supplierController.text.trim(),
        items: purchaseItems,
        totalAmount: _calculatedTotal,
        notes: _notesController.text.trim(),
      );

      await HiveDatabase.purchaseOrdersBox.add(order);
      
      // Sync Purchase Order to Cloud
      SyncManager.pushPurchaseOrder(order);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Restock successful! Inventory levels updated.'),
          backgroundColor: Colors.green,
        ));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Restock error: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showQuickAddProductDialog(_ItemRow row) {
    final name = row.nameController.text.trim();
    final nameCtrl = TextEditingController(text: name);
    final barcodeCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final rateCtrl = TextEditingController(text: row.costController.text);
    String? selectedCategory;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(builder: (context, setDialogState) {
        return AlertDialog(
          title: const Text('Add New Product'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('This product is not in your list. Let\'s add it.',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  decoration: _inputDec(label: 'Product Name', icon: Icons.abc),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: barcodeCtrl,
                  decoration: _inputDec(label: 'Barcode', icon: Icons.qr_code),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  decoration: _inputDec(label: 'Category', icon: Icons.category),
                  items: HiveDatabase.categoryBox.values
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (val) => selectedCategory = val,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceCtrl,
                  decoration:
                      _inputDec(label: 'Selling Price', icon: Icons.payments),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedCategory == null ||
                    priceCtrl.text.isEmpty ||
                    nameCtrl.text.isEmpty) {
                  return;
                }
                final newProduct = ProductModel(
                  id: const Uuid().v4(),
                  name: nameCtrl.text.trim(),
                  barcode: barcodeCtrl.text.trim(),
                  category: selectedCategory!,
                  price: double.parse(priceCtrl.text),
                  purchasedRate: double.tryParse(rateCtrl.text) ?? 0.0,
                  sizeStocks: {},
                  isSizeSpecific: true, // Default to size specific
                  baseStock: 0,
                );

                await HiveDatabase.productBox.put(newProduct.id, newProduct);
                SyncManager.pushProduct(newProduct);

                setState(() {
                  row.productId = newProduct.id;
                  row.nameController.text = newProduct.name;
                  if (newProduct.isSizeSpecific) {
                    row.isSizeSpecific = true;
                  }
                });
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Create'),
            ),
          ],
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Purchase Order',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.chevron_left,
              size: 28, color: Theme.of(context).primaryColor),
          onPressed: () => context.pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Supplier & Date ─────────────────────────────────
                    _sectionLabel('ORDER DETAILS'),
                    const SizedBox(height: 8),
                    _card(
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _supplierController,
                            decoration: _inputDec(
                              label: 'Supplier Name',
                              icon: Icons.store_outlined,
                            ),
                            textCapitalization: TextCapitalization.words,
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Enter supplier name'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          InkWell(
                            onTap: _pickDate,
                            borderRadius: BorderRadius.circular(12),
                            child: InputDecorator(
                              decoration: _inputDec(
                                label: 'Order Date',
                                icon: Icons.calendar_today_outlined,
                              ),
                              child: Text(
                                '${_selectedDate.day.toString().padLeft(2, '0')} / '
                                '${_selectedDate.month.toString().padLeft(2, '0')} / '
                                '${_selectedDate.year}',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Items ─────────────────────────────────────────────
                    _sectionLabel('ITEMS PURCHASED'),
                    const SizedBox(height: 8),

                    ..._items.asMap().entries.map((entry) {
                      final i = entry.key;
                      final row = entry.value;
                      return _card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text('Item ${i + 1}',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: AppTheme.primaryColor)),
                                ),
                                if (_items.length > 1)
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline,
                                        color: Colors.red, size: 20),
                                    onPressed: () => _removeItem(i),
                                    constraints: const BoxConstraints(),
                                    padding: EdgeInsets.zero,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // ── Product Search ───────────────────────────────
                            RawAutocomplete<ProductModel>(
                              textEditingController: row.nameController,
                              focusNode: FocusNode(),
                              optionsBuilder: (TextEditingValue textValue) {
                                if (textValue.text.isEmpty) {
                                  return const Iterable<ProductModel>.empty();
                                }
                                return HiveDatabase.productBox.values.where(
                                    (p) =>
                                        p.name.toLowerCase().contains(
                                            textValue.text.toLowerCase()) ||
                                        p.barcode.contains(textValue.text));
                              },
                              displayStringForOption: (option) => option.name,
                              onSelected: (option) {
                                setState(() {
                                  row.productId = option.id;
                                  row.isSizeSpecific = option.isSizeSpecific;
                                  row.costController.text =
                                      option.purchasedRate.toString();
                                });
                              },
                              fieldViewBuilder: (context, controller, focusNode,
                                  onFieldSubmitted) {
                                return TextFormField(
                                  controller: controller,
                                  focusNode: focusNode,
                                  decoration: _inputDec(
                                    label: 'Product Name',
                                    icon: Icons.inventory_2_outlined,
                                  ).copyWith(
                                    suffixIcon: row.productId == null &&
                                            row.nameController.text.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.add_business,
                                                color: Colors.orange),
                                            onPressed: () =>
                                                _showQuickAddProductDialog(row),
                                            tooltip: 'Create New Product',
                                          )
                                        : (row.productId != null
                                            ? const Icon(Icons.verified,
                                                color: Colors.green, size: 16)
                                            : null),
                                  ),
                                  onChanged: (val) {
                                    if (row.productId != null) {
                                      setState(() {
                                        row.productId = null;
                                        row.selectedSize = null;
                                      });
                                    }
                                  },
                                );
                              },
                              optionsViewBuilder:
                                  (context, onSelected, options) {
                                return Align(
                                  alignment: Alignment.topLeft,
                                  child: Material(
                                    elevation: 4,
                                    child: SizedBox(
                                      width: MediaQuery.of(context).size.width -
                                          64,
                                      child: ListView.builder(
                                        shrinkWrap: true,
                                        itemCount: options.length,
                                        itemBuilder: (context, index) {
                                          final option =
                                              options.elementAt(index);
                                          return ListTile(
                                            title: Text(option.name),
                                            subtitle: Text(
                                                'Stock: ${option.isSizeSpecific ? 'Multi-size' : option.baseStock}'),
                                            onTap: () => onSelected(option),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),

                            const SizedBox(height: 12),

                            // ── Size Toggle ───────────────────────────────
                            SwitchListTile(
                              title: const Text('Specify Sizes',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                              value: row.isSizeSpecific,
                              onChanged: (val) =>
                                  setState(() => row.isSizeSpecific = val),
                              activeColor: AppTheme.primaryColor,
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                            ),

                            // ── Size & Qty & Cost ──────────────────────────
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (row.isSizeSpecific)
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      value: row.selectedSize,
                                      decoration: _inputDec(
                                          label: 'Size', icon: Icons.straighten),
                                      items: const [
                                        '6', '7', '8', '9', '10', '11'
                                      ].map((s) => DropdownMenuItem(
                                          value: s, child: Text(s))).toList(),
                                      onChanged: (val) =>
                                          setState(() => row.selectedSize = val),
                                      validator: (val) =>
                                          (row.isSizeSpecific && val == null)
                                              ? 'Pick size'
                                              : null,
                                    ),
                                  ),
                                if (row.isSizeSpecific) const SizedBox(width: 8),
                                Expanded(
                                  child: TextFormField(
                                    controller: row.qtyController,
                                    decoration: _inputDec(
                                        label: 'Qty', icon: Icons.numbers),
                                    keyboardType: TextInputType.number,
                                    onChanged: (_) => setState(() {}),
                                    validator: (val) => (val == null ||
                                            int.tryParse(val) == null)
                                        ? 'Error'
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextFormField(
                                    controller: row.costController,
                                    decoration: _inputDec(
                                        label: 'Cost',
                                        icon: Icons.currency_rupee),
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    onChanged: (_) => setState(() {}),
                                    validator: (val) => (val == null ||
                                            double.tryParse(val) == null)
                                        ? 'Error'
                                        : null,
                                  ),
                                ),
                              ],
                            ),

                            // Line total
                            Builder(builder: (_) {
                              final qty =
                                  int.tryParse(row.qtyController.text) ?? 0;
                              final cost =
                                  double.tryParse(row.costController.text) ??
                                      0.0;
                              final lineTotal = qty * cost;
                              return Align(
                                alignment: Alignment.centerRight,
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    'Line Total: ₹${lineTotal.toStringAsFixed(2)}',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      );
                    }),

                    // Add item button
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: OutlinedButton.icon(
                        onPressed: _addItem,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Another Item'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryColor,
                          side: BorderSide(color: AppTheme.primaryColor),
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Notes ─────────────────────────────────────────────
                    _sectionLabel('NOTES (OPTIONAL)'),
                    const SizedBox(height: 8),
                    _card(
                      child: TextFormField(
                        controller: _notesController,
                        maxLines: 3,
                        decoration: _inputDec(
                            label: 'Notes', icon: Icons.notes_outlined),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // ── Bottom bar ────────────────────────────────────────────────
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 12,
                      offset: const Offset(0, -4))
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('TOTAL AMOUNT',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                              letterSpacing: 1.0)),
                      Text(
                        '₹${_calculatedTotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _save,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save_outlined),
                      label:
                          Text(_isSaving ? 'Saving…' : 'Save Purchase Order'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        textStyle: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(text,
        style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
            letterSpacing: 1.2));
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ]),
      child: child,
    );
  }

  InputDecoration _inputDec({required String label, required IconData icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 18, color: AppTheme.primaryColor),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppTheme.primaryColor, width: 1.5)),
    );
  }
}

/// Simple data holder for each item row's controllers.
class _ItemRow {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController qtyController = TextEditingController();
  final TextEditingController costController = TextEditingController();
  String? productId;
  String? selectedSize;
  bool isSizeSpecific = true;
}
