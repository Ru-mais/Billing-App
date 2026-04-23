import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:ui';

import '../../../billing/presentation/bloc/billing_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../domain/entities/cart_item.dart';
import '../../../../features/product/presentation/bloc/product_bloc.dart';
import '../../../../features/product/domain/entities/product.dart';
import '../../../settings/presentation/bloc/theme_bloc.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    returnImage: false,
  );

  bool _isCameraOn = false;
  bool _isFlashOn = false;

  // Cooldown mapping to prevent rapid firing of the same barcode
  final Map<String, DateTime> _lastScanTimes = {};

  final TextEditingController _manualCodeController = TextEditingController();
  final TextEditingController _discountController =
      TextEditingController(text: '0');
  final FocusNode _manualCodeFocusNode = FocusNode();

  @override
  void dispose() {
    _manualCodeFocusNode.dispose();
    _manualCodeController.dispose();
    _discountController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    final List<Barcode> barcodes = capture.barcodes;
    final now = DateTime.now();

    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        final rawValue = barcode.rawValue!;

        // Cooldown logic: 2 seconds per identical barcode
        if (_lastScanTimes.containsKey(rawValue)) {
          final lastScan = _lastScanTimes[rawValue]!;
          if (now.difference(lastScan).inSeconds < 2) {
            continue;
          }
        }

        _lastScanTimes[rawValue] = now;

        // Vibrate Natively
        HapticFeedback.lightImpact();

        if (mounted) {
          context.read<BillingBloc>().add(ScanBarcodeEvent(rawValue));
        }
        break; // Process one barcode at a time per frame
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bilby', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(
              _isCameraOn ? Icons.videocam : Icons.videocam_off,
              color: _isCameraOn ? Theme.of(context).primaryColor : null,
            ),
            onPressed: () {
              setState(() {
                _isCameraOn = !_isCameraOn;
                if (_isCameraOn) {
                  _scannerController.start();
                } else {
                  _scannerController.stop();
                }
              });
            },
            style: IconButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
            style: IconButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1)),
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: BlocListener<BillingBloc, BillingState>(
        listenWhen: (previous, current) =>
            (previous.error != current.error && current.error != null) ||
            (previous.pendingSizeProduct != current.pendingSizeProduct &&
                current.pendingSizeProduct != null),
        listener: (context, state) {
          if (state.error != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.error!), backgroundColor: Colors.red),
            );
          }
          if (state.pendingSizeProduct != null) {
            _showSizePicker(context, state.pendingSizeProduct!);
          }
        },
        child: Column(
          children: [
            if (_isCameraOn)
              Container(
                height: MediaQuery.of(context).size.height * 0.35,
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                child: _buildScannerSection(),
              ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    if (!_isCameraOn) ...[
                      _buildTopCard(context),
                      const SizedBox(height: 16),
                    ],
                    _buildProductsCard(context),
                    const SizedBox(height: 16),
                    _buildBottomCard(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
      ),
      padding: const EdgeInsets.all(16),
      child: BlocBuilder<ProductBloc, ProductState>(
        builder: (context, productState) {
          void submitProductCode(String val) {
            if (val.trim().isEmpty) return;
            String barcodeToScan = val.trim();
            final lowerVal = barcodeToScan.toLowerCase();
            // Check if input matches name or barcode
            final match = productState.products.where((p) => 
                p.name.toLowerCase() == lowerVal || p.barcode.toLowerCase() == lowerVal).firstOrNull;
            if (match != null) {
              barcodeToScan = match.barcode;
            }
            context.read<BillingBloc>().add(ScanBarcodeEvent(barcodeToScan));
            _manualCodeController.clear();
            _manualCodeFocusNode.requestFocus();
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RawAutocomplete<Product>(
                focusNode: _manualCodeFocusNode,
                textEditingController: _manualCodeController,
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.isEmpty) return const Iterable<Product>.empty();
                  final query = textEditingValue.text.toLowerCase();
                  return productState.products.where((product) =>
                      product.name.toLowerCase().contains(query) || product.barcode.toLowerCase().contains(query));
                },
                displayStringForOption: (Product option) => option.name,
                onSelected: (Product selection) {
                  context.read<BillingBloc>().add(ScanBarcodeEvent(selection.barcode));
                  _manualCodeController.clear();
                  _manualCodeFocusNode.requestFocus();
                },
                fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                  return TextField(
                    controller: textEditingController,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      hintText: 'Enter product name or code',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1)),
                      ),
                    ),
                    onSubmitted: submitProductCode,
                  );
                },
                optionsViewBuilder: (context, onSelected, options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4.0,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 250),
                        width: MediaQuery.of(context).size.width - 64,
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: options.length,
                          itemBuilder: (context, index) {
                            final option = options.elementAt(index);
                            return ListTile(
                              title: Text(option.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('Code: ${option.barcode} - ₹${option.price.toStringAsFixed(2)}'),
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
              Row(
                children: [
                  ElevatedButton(
                    onPressed: () => submitProductCode(_manualCodeController.text),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text('Add Product', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() => _isCameraOn = true);
                      _scannerController.start();
                    },
                    icon: const Icon(Icons.qr_code_scanner, size: 18),
                    label: const Text('Scan'),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1)),
                      foregroundColor: Theme.of(context).textTheme.bodyLarge?.color,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProductsCard(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Products', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          BlocBuilder<BillingBloc, BillingState>(
            builder: (context, state) {
              if (state.cartItems.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('No products added', style: TextStyle(color: Colors.grey[500])),
                );
              }
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: state.cartItems.length,
                separatorBuilder: (context, index) => BorderSide.none == BorderSide.none ? Divider(color: Theme.of(context).dividerColor.withOpacity(0.05), height: 1) : SizedBox(height: 8),
                itemBuilder: (context, index) => _buildCartItemCard(context, state.cartItems[index]),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBottomCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
      ),
      padding: const EdgeInsets.all(16),
      child: BlocBuilder<BillingBloc, BillingState>(
        builder: (context, state) {
          final currentVal = double.tryParse(_discountController.text) ?? 0.0;
          if (currentVal != state.discountValue) {
            _discountController.text = state.discountValue == 0 ? '' : state.discountValue.toString();
          }

          return Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Apply Discount', style: TextStyle(fontWeight: FontWeight.w500)),
                  Switch(
                    value: state.discountEnabled,
                    onChanged: (value) => context.read<BillingBloc>().add(ToggleDiscountEvent(value)),
                  ),
                ],
              ),
              if (state.discountEnabled) ...[
                const SizedBox(height: 12),
                SegmentedButton<DiscountType>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: DiscountType.percentage, label: Text('Percent (%)', style: TextStyle(fontSize: 12))),
                    ButtonSegment(value: DiscountType.amount, label: Text('Flat (₹)', style: TextStyle(fontSize: 12))),
                  ],
                  selected: {state.discountType},
                  onSelectionChanged: (set) => context.read<BillingBloc>().add(SetDiscountTypeEvent(set.first)),
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith<Color>(
                      (Set<WidgetState> states) {
                        if (states.contains(WidgetState.selected)) {
                          return Theme.of(context).primaryColor.withOpacity(0.15);
                        }
                        return Colors.transparent;
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _discountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: state.discountType == DiscountType.percentage ? 'Discount Percentage' : 'Discount Amount (₹)',
                    hintText: 'Enter value',
                    prefixIcon: Icon(state.discountType == DiscountType.percentage ? Icons.percent : Icons.currency_rupee),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: (value) {
                    final parsed = double.tryParse(value) ?? 0;
                    context.read<BillingBloc>().add(SetDiscountValueEvent(parsed));
                  },
                ),
              ],
              if (state.cartItems.isNotEmpty) ...[
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total Due', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    Text('₹${state.totalAmount.toStringAsFixed(0)}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      _scannerController.stop();
                      await context.push('/checkout');
                      if (context.mounted && _isCameraOn) {
                        _scannerController.start();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Review Order', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildScannerSection() {
    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: _onDetect,
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
            ),
          ),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white.withOpacity(0.4), width: 2),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Stack(
                children: [
                  Align(alignment: Alignment.topLeft, child: _buildCorner(Alignment.topLeft)),
                  Align(alignment: Alignment.topRight, child: _buildCorner(Alignment.topRight)),
                  Align(alignment: Alignment.bottomLeft, child: _buildCorner(Alignment.bottomLeft)),
                  Align(alignment: Alignment.bottomRight, child: _buildCorner(Alignment.bottomRight)),
                ],
              ),
            ),
          ),
          Positioned(
            top: 40,
            right: 20,
            child: IconButton(
              icon: Icon(_isFlashOn ? Icons.flash_on : Icons.flash_off, color: Colors.white, size: 28),
              onPressed: () {
                setState(() => _isFlashOn = !_isFlashOn);
                _scannerController.toggleTorch();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCorner(Alignment alignment) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        border: Border(
          top: (alignment == Alignment.topLeft || alignment == Alignment.topRight) ? const BorderSide(color: Colors.greenAccent, width: 4) : BorderSide.none,
          bottom: (alignment == Alignment.bottomLeft || alignment == Alignment.bottomRight) ? const BorderSide(color: Colors.greenAccent, width: 4) : BorderSide.none,
          left: (alignment == Alignment.topLeft || alignment == Alignment.bottomLeft) ? const BorderSide(color: Colors.greenAccent, width: 4) : BorderSide.none,
          right: (alignment == Alignment.topRight || alignment == Alignment.bottomRight) ? const BorderSide(color: Colors.greenAccent, width: 4) : BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildCartItemCard(
    BuildContext context,
    CartItem item,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Theme.of(context).cardTheme.shape is RoundedRectangleBorder
            ? Border.fromBorderSide((Theme.of(context).cardTheme.shape as RoundedRectangleBorder).side)
            : Border.all(color: Colors.transparent),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark ? Colors.black26 : Colors.black.withOpacity(0.05), 
            blurRadius: 10, 
            offset: const Offset(0, 4)
          )
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        spacing: 1,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.product.name}${item.selectedSize.isNotEmpty ? " · Size ${item.selectedSize}" : ""}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '₹${item.product.price.toStringAsFixed(2)}',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark ? Colors.white12 : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _circularIconButton(
                    icon: Icons.remove,
                    onPressed: () {
                      if (item.quantity > 1) {
                        context.read<BillingBloc>().add(UpdateQuantityEvent(
                            item.cartKey, item.quantity - 1));
                      } else {
                        context
                            .read<BillingBloc>()
                            .add(RemoveProductFromCartEvent(item.cartKey));
                      }
                    }),
                SizedBox(
                  width: 32,
                  child: Text(
                    '${item.quantity}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                _circularIconButton(
                    icon: Icons.add,
                    onPressed: () {
                      context.read<BillingBloc>().add(UpdateQuantityEvent(
                          item.cartKey, item.quantity + 1));
                    }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _circularIconButton(
      {required IconData icon, required VoidCallback onPressed}) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Icon(icon, size: 20, color: Colors.grey[600]),
      ),
    );
  }

  void _showSizePicker(BuildContext context, product) {
    final sizeEntries = (product.sizeStocks as Map<String, int>).entries.toList();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog<void>(
        context: context,
        builder: (dialogCtx) {
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.straighten, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Select Size - ${product.name}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: sizeEntries.map((entry) {
                  final isOutOfStock = entry.value <= 0;
                  return GestureDetector(
                    onTap: isOutOfStock
                        ? null
                        : () {
                            Navigator.pop(dialogCtx);
                            context
                                .read<BillingBloc>()
                                .add(SizeSelectedEvent(entry.key));
                          },
                    child: Container(
                      width: 72,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isOutOfStock
                            ? Colors.grey[50]
                            : Theme.of(context)
                                .primaryColor
                                .withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isOutOfStock
                              ? Colors.grey[200]!
                              : Theme.of(context)
                                  .primaryColor
                                  .withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            entry.key,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              color: isOutOfStock
                                  ? Colors.grey[300]
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isOutOfStock ? 'Out' : 'Qty: ${entry.value}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isOutOfStock
                                  ? Colors.red[200]
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      ).then((_) {
        // If dismissed without picking, clear the pending product
        if (context.mounted) {
          context.read<BillingBloc>().add(const SizeSelectedEvent('__cancel__'));
        }
      });
    });
  }

  // A floating Details/Checkout Button at the very bottom
  // Added a Stack wrapper below to overlay this button
}
