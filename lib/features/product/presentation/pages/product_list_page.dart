import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../bloc/product_bloc.dart';
import '../../domain/entities/product.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_validators.dart';
import '../../../../features/settings/presentation/bloc/printer_bloc.dart';
import '../../../../features/settings/presentation/bloc/printer_event.dart';

class ProductListPage extends StatefulWidget {
  const ProductListPage({super.key});

  @override
  State<ProductListPage> createState() => _ProductListPageState();
}

enum ProductSortOption { name, stockAsc, stockDesc }

class _ProductListPageState extends State<ProductListPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  ProductSortOption _sortOption = ProductSortOption.name;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _scanQR(List<Product> products) async {
    final barcode = await context.push<String>('/scanner');
    if (barcode != null && barcode.isNotEmpty) {
      final matchedProduct =
          products.where((p) => p.barcode == barcode).firstOrNull;
      if (matchedProduct != null) {
        _searchController.text = matchedProduct.name;
      } else {
        _searchController.text =
            barcode; // If not found, just put barcode in search
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = Colors.grey[100]!;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.chevron_left,
              size: 28, color: Theme.of(context).primaryColor),
          onPressed: () => context.pop(),
        ),
        title: const Text('Product Management',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: BlocBuilder<ProductBloc, ProductState>(
                builder: (context, state) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _searchController,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            hintText: 'Scan or enter barcode',
                            prefixIcon: Icon(
                              Icons.search,
                              color: Colors.grey[400],
                            ),
                          ),
                          validator:
                              AppValidators.required('Please enter a barcode'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.qr_code_scanner,
                              color: AppTheme.primaryColor),
                          onPressed: () => _scanQR(state.products),
                          padding: const EdgeInsets.all(13),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: PopupMenuButton<ProductSortOption>(
                          icon: const Icon(Icons.sort, color: AppTheme.primaryColor),
                          padding: const EdgeInsets.all(13),
                          onSelected: (option) {
                            setState(() => _sortOption = option);
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(value: ProductSortOption.name, child: Text('Sort by Name (A-Z)')),
                            PopupMenuItem(value: ProductSortOption.stockAsc, child: Text('Stock: Low to High')),
                            PopupMenuItem(value: ProductSortOption.stockDesc, child: Text('Stock: High to Low')),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text('Tap the icon to open camera scanner',
                      style: TextStyle(fontSize: 12, color: Color(0xFF4C669A))),
                ],
              );
            }),
          ),

          Expanded(
            child: BlocConsumer<ProductBloc, ProductState>(
              listener: (context, state) {
                if (state.status == ProductStatus.success &&
                    state.message != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(state.message!),
                        backgroundColor: Colors.green),
                  );
                } else if (state.status == ProductStatus.error &&
                    state.message != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(state.message!),
                        backgroundColor: Colors.red),
                  );
                }
              },
              builder: (context, state) {
                if (state.status == ProductStatus.loading &&
                    state.products.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state.products.isEmpty) {
                  if (state.status == ProductStatus.error) {
                    return Center(child: Text('Error: ${state.message}'));
                  }
                  return const Center(
                      child: Text('No products found. Add some!'));
                }

                final filteredProducts = state.products
                    .where((product) =>
                        product.name.toLowerCase().contains(_searchQuery) ||
                        product.barcode.toLowerCase().contains(_searchQuery))
                    .toList();

                filteredProducts.sort((a, b) {
                  switch (_sortOption) {
                    case ProductSortOption.name:
                      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
                    case ProductSortOption.stockAsc:
                      return a.totalStock.compareTo(b.totalStock);
                    case ProductSortOption.stockDesc:
                      return b.totalStock.compareTo(a.totalStock);
                  }
                });

                if (filteredProducts.isEmpty) {
                  return const Center(
                      child: Text('No products match your search.'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.only(
                      left: 16, right: 16, top: 8, bottom: 100),
                  itemCount: filteredProducts.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final product = filteredProducts[index];
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor),
                        boxShadow: const [
                          BoxShadow(
                              color: Colors.black12,
                              blurRadius: 4,
                              offset: Offset(0, 2))
                        ],
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '₹${product.price.toStringAsFixed(2)}  |  Total Stock: ${product.totalStock}',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey[600]),
                                ),
                                const SizedBox(height: 4),
                                if (product.sizeStocks.isNotEmpty)
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: product.sizeStocks.entries.map((e) {
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: e.value > 0
                                              ? Colors.green.withValues(alpha: 0.1)
                                              : Colors.red.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: e.value > 0
                                                ? Colors.green.withValues(alpha: 0.4)
                                                : Colors.red.withValues(alpha: 0.4),
                                          ),
                                        ),
                                        child: Text(
                                          'UK ${e.key}: ${e.value}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: e.value > 0
                                                ? Colors.green[700]
                                                : Colors.red[700],
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  )
                                else
                                  Text('No sizes added',
                                      style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.blueGrey.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.print_rounded,
                                      color: Colors.blueGrey, size: 20),
                                  constraints: const BoxConstraints(),
                                  padding: const EdgeInsets.all(8),
                                  onPressed: () => _printLabelDialog(context, product),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.edit_rounded,
                                      color: AppTheme.primaryColor, size: 20),
                                  constraints: const BoxConstraints(),
                                  padding: const EdgeInsets.all(8),
                                  onPressed: () {
                                    context.push('/products/edit/${product.id}',
                                        extra: product);
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded,
                                      color: Colors.red, size: 20),
                                  constraints: const BoxConstraints(),
                                  padding: const EdgeInsets.all(8),
                                  onPressed: () =>
                                      _confirmDelete(context, product),
                                ),
                              ),
                            ],
                          )
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/products/add'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, size: 32),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Product product) {
    showDialog(
      context: context,
      builder: (innerContext) {
        return AlertDialog(
          title: const Text('Delete Product'),
          content: Text('Are you sure you want to delete ${product.name}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(innerContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                context.read<ProductBloc>().add(DeleteProduct(product.id));
                Navigator.pop(innerContext);
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _printLabelDialog(BuildContext context, Product product) {
    final TextEditingController copiesController =
        TextEditingController(text: product.totalStock > 0 ? product.totalStock.toString() : '1');
    showDialog(
      context: context,
      builder: (innerContext) {
        return AlertDialog(
          title: const Text('Print Label'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Print label for ${product.name}?'),
              const SizedBox(height: 16),
              TextField(
                controller: copiesController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Number of copies',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(innerContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final copies = int.tryParse(copiesController.text) ?? 1;
                context.read<PrinterBloc>().add(PrintLabelEvent(
                      name: product.name,
                      barcode: product.barcode,
                      price: product.price,
                      copies: copies,
                    ));
                Navigator.pop(innerContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Printing $copies label(s)...'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: const Text('Print'),
            ),
          ],
        );
      },
    );
  }
}
