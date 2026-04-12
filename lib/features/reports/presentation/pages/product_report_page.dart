import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../product/presentation/bloc/product_bloc.dart';

enum _StockSortMode { lowToHigh, highToLow }

class ProductReportPage extends StatefulWidget {
  const ProductReportPage({super.key});

  @override
  State<ProductReportPage> createState() => _ProductReportPageState();
}

// Flat row: one entry per product-size combination
class _StockRow {
  final String productName;
  final String barcode;
  final String size;
  final int stock;
  const _StockRow({
    required this.productName,
    required this.barcode,
    required this.size,
    required this.stock,
  });
}

class _ProductReportPageState extends State<ProductReportPage> {
  _StockSortMode _sortMode = _StockSortMode.lowToHigh;
  String _searchQuery = '';
  String? _selectedCategory;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.chevron_left, size: 28, color: Theme.of(context).primaryColor),
          onPressed: () => context.pop(),
        ),
        title: const Text('Product Report',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        actions: [
          PopupMenuButton<_StockSortMode>(
            icon: Icon(Icons.sort, color: AppTheme.primaryColor),
            onSelected: (mode) => setState(() => _sortMode = mode),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _StockSortMode.lowToHigh,
                child: Row(
                  children: [
                    Icon(Icons.arrow_upward, size: 16,
                        color: _sortMode == _StockSortMode.lowToHigh
                            ? AppTheme.primaryColor
                            : Colors.grey),
                    const SizedBox(width: 8),
                    const Text('Stock: Low to High'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: _StockSortMode.highToLow,
                child: Row(
                  children: [
                    Icon(Icons.arrow_downward, size: 16,
                        color: _sortMode == _StockSortMode.highToLow
                            ? AppTheme.primaryColor
                            : Colors.grey),
                    const SizedBox(width: 8),
                    const Text('Stock: High to Low'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: BlocBuilder<ProductBloc, ProductState>(
        builder: (context, state) {
          if (state.status == ProductStatus.loading && state.products.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.products.isEmpty) {
            return const Center(child: Text('No products found.'));
          }

          // Flatten product × size into rows
          final List<_StockRow> rows = [];
          for (final product in state.products) {
            if (_selectedCategory != null && product.category != _selectedCategory) {
              continue;
            }
            if (!product.isSizeSpecific) {
              rows.add(_StockRow(
                productName: product.name,
                barcode: product.barcode,
                size: 'Unified',
                stock: product.baseStock,
              ));
            } else {
              if (product.sizeStocks.isEmpty) {
                rows.add(_StockRow(
                  productName: product.name,
                  barcode: product.barcode,
                  size: '—',
                  stock: 0,
                ));
              } else {
                for (final entry in product.sizeStocks.entries) {
                  rows.add(_StockRow(
                    productName: product.name,
                    barcode: product.barcode,
                    size: entry.key,
                    stock: entry.value,
                  ));
                }
              }
            }
          }

          // Filter
          final filtered = _searchQuery.isEmpty
              ? rows
              : rows
                  .where((r) =>
                      r.productName.toLowerCase().contains(_searchQuery) ||
                      r.barcode.toLowerCase().contains(_searchQuery) ||
                      r.size.toLowerCase().contains(_searchQuery))
                  .toList();

          // Sort
          filtered.sort((a, b) => _sortMode == _StockSortMode.lowToHigh
              ? a.stock.compareTo(b.stock)
              : b.stock.compareTo(a.stock));

          // Stats for summary header
          final int outOfStock = filtered.where((r) => r.stock == 0).length;
          final int lowStock = filtered.where((r) => r.stock > 0 && r.stock <= 3).length;
          final int totalItems = filtered.length;

          return Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search by name, barcode or size…',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                ),
              ),

              // Category Filter Chips
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: const Text('All'),
                        selected: _selectedCategory == null,
                        onSelected: (selected) {
                          if (selected) setState(() => _selectedCategory = null);
                        },
                        selectedColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                        checkmarkColor: AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 8),
                      ...state.products.map((p) => p.category).toSet().map((cat) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(cat),
                            selected: _selectedCategory == cat,
                            onSelected: (selected) {
                              setState(() {
                                _selectedCategory = selected ? cat : null;
                              });
                            },
                            selectedColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                            checkmarkColor: AppTheme.primaryColor,
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),

              // Summary chips
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    _statChip('$totalItems Entries', Colors.blue),
                    const SizedBox(width: 8),
                    _statChip('$outOfStock Out', Colors.red),
                    const SizedBox(width: 8),
                    _statChip('$lowStock Low (≤3)', Colors.orange),
                  ],
                ),
              ),

              // Table header
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: const [
                    Expanded(flex: 4, child: Text('Product', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    Expanded(flex: 1, child: Text('Size', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    Expanded(flex: 1, child: Text('Stock', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  ],
                ),
              ),

              // Rows
              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text('No results match your search.'))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          final row = filtered[index];
                          final isOut = row.stock == 0;
                          final isLow = row.stock > 0 && row.stock <= 3;
                          final Color stockColor = isOut
                              ? Colors.red
                              : isLow
                                  ? Colors.orange
                                  : Colors.green;

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isOut
                                    ? Colors.red.withValues(alpha: 0.25)
                                    : isLow
                                        ? Colors.orange.withValues(alpha: 0.25)
                                        : Colors.grey[100]!,
                              ),
                              boxShadow: const [
                                BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 1)),
                              ],
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 4,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(row.productName,
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
                                      Text(row.barcode,
                                          style: TextStyle(fontSize: 11, color: Colors.grey[500], fontFamily: 'monospace')),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryColor.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        row.size,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: AppTheme.primaryColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: stockColor.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '${row.stock}',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: stockColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _statChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
    );
  }
}
