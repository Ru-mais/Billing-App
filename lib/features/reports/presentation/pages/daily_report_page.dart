import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/data/hive_database.dart';
import '../../data/models/sale_model.dart';
import '../../data/models/purchase_order_model.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/utils/pdf_helper.dart';

class _UnifiedTransaction {
  final String id;
  final DateTime timestamp;
  final double amount;
  final String type; // 'sale' or 'purchase'
  final dynamic data; // SaleModel or PurchaseOrderModel

  _UnifiedTransaction({
    required this.id,
    required this.timestamp,
    required this.amount,
    required this.type,
    required this.data,
  });
}

class DailyReportPage extends StatefulWidget {
  final DateTime? targetDate;
  const DailyReportPage({super.key, this.targetDate});

  @override
  State<DailyReportPage> createState() => _DailyReportPageState();
}

class _DailyReportPageState extends State<DailyReportPage> {
  late DateTime _date;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _date = widget.targetDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final scaffoldBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    return ValueListenableBuilder<Box<SaleModel>>(
      valueListenable: HiveDatabase.salesBox.listenable(),
      builder: (context, salesBox, _) {
        return ValueListenableBuilder<Box<PurchaseOrderModel>>(
          valueListenable: HiveDatabase.purchaseOrdersBox.listenable(),
          builder: (context, purchaseBox, _) {
            final sales = salesBox.values.where((sale) {
              return sale.timestamp.year == _date.year &&
                  sale.timestamp.month == _date.month &&
                  sale.timestamp.day == _date.day;
            }).toList();

            final purchases = purchaseBox.values.where((p) {
              return p.timestamp.year == _date.year &&
                  p.timestamp.month == _date.month &&
                  p.timestamp.day == _date.day;
            }).toList();

            final List<_UnifiedTransaction> transactions = [];
            for (final s in sales) {
              transactions.add(_UnifiedTransaction(
                id: s.id,
                timestamp: s.timestamp,
                amount: s.totalAmount,
                type: 'sale',
                data: s,
              ));
            }
            for (final p in purchases) {
              transactions.add(_UnifiedTransaction(
                id: p.id,
                timestamp: p.timestamp,
                amount: p.totalAmount,
                type: 'purchase',
                data: p,
              ));
            }
            transactions.sort((a, b) => b.timestamp.compareTo(a.timestamp));
            
            final filteredTransactions = transactions.where((tx) {
              final q = _query.trim().toLowerCase();
              if (q.isEmpty) return true;
              if (tx.id.toLowerCase().contains(q)) return true;
              if (tx.type == 'purchase') {
                final supplier = (tx.data as PurchaseOrderModel).supplierName;
                if (supplier.toLowerCase().contains(q)) return true;
              }
              final itemNames = tx.type == 'sale'
                  ? (tx.data as SaleModel).items.map((i) => i.productName)
                  : (tx.data as PurchaseOrderModel).items.map((i) => i.productName);
              return itemNames.any((name) => name.toLowerCase().contains(q));
            }).toList();

            final isToday = widget.targetDate == null &&
                _date.year == DateTime.now().year &&
                _date.month == DateTime.now().month &&
                _date.day == DateTime.now().day;

            final dateLabel = isToday ? 'Today' : DateFormat('dd MMM yyyy').format(_date);
            final totalSales = sales.fold(0.0, (sum, s) => sum + s.totalAmount);
            final totalPurchases = purchases.fold(0.0, (sum, p) => sum + p.totalAmount);
            final netBalance = totalSales - totalPurchases;

            return Scaffold(
              backgroundColor: scaffoldBg,
              appBar: AppBar(
                title: Text(isToday ? 'Daily Report' : 'Report: $dateLabel',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                elevation: 0,
                backgroundColor: Colors.transparent,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                  onPressed: () => context.pop(),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.calendar_month_outlined),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setState(() => _date = picked);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.file_download_outlined),
                    onPressed: () => _exportDetailedReport(transactions, dateLabel, totalSales, totalPurchases),
                  ),
                ],
              ),
              body: Column(
                children: [
                  // Summary Box
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _summaryItem('REVENUE', totalSales, Colors.green),
                              _summaryItem('EXPENSES', totalPurchases, Colors.red),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: scaffoldBg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('NET TOTAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                                Text('₹${netBalance.toStringAsFixed(2)}', 
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: netBalance >= 0 ? Colors.green : Colors.red)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Search Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: TextFormField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _query = v),
                      decoration: InputDecoration(
                        hintText: 'Search transactions...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        filled: true,
                        fillColor: cardBg,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Expanded(
                    child: filteredTransactions.isEmpty
                        ? const Center(child: Text('No transactions found', style: TextStyle(color: Colors.grey)))
                        : ListView.separated(
                            padding: const EdgeInsets.all(20),
                            itemCount: filteredTransactions.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final tx = filteredTransactions[index];
                              final isSale = tx.type == 'sale';
                              return Container(
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: borderColor),
                                ),
                                child: ListTile(
                                  onTap: () => _showTransactionDetails(context, tx),
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isSale ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(isSale ? Icons.add_shopping_cart : Icons.inventory_2_outlined, 
                                      size: 20, color: isSale ? Colors.green : Colors.red),
                                  ),
                                  title: Text(isSale ? 'Sale: ${tx.id.substring(0, 6)}' : 'Ref: ${tx.id.substring(0, 6)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  subtitle: Text(DateFormat('hh:mm a').format(tx.timestamp), style: const TextStyle(fontSize: 12)),
                                  trailing: Text('₹${tx.amount.toStringAsFixed(0)}',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isSale ? Colors.green : Colors.red)),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _summaryItem(String label, double amount, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
        const SizedBox(height: 4),
        Text('₹${amount.toStringAsFixed(2)}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Future<void> _exportDetailedReport(List<_UnifiedTransaction> transactions, String dateLabel, double totalSales, double totalPurchases) async {
    if (transactions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No transactions to export.')));
      return;
    }
    
    final shopDetails = HiveDatabase.shopBox.get('shop_details');
    final shopName = shopDetails?.name ?? 'Bilby Billing';

    final mappedTx = transactions.map((tx) {
      final isSale = tx.type == 'sale';
      String desc = '';
      if (isSale) {
        final SaleModel s = tx.data;
        desc = s.items.map((i) => '${i.quantity}x ${i.productName}').join(', ');
      } else {
        final PurchaseOrderModel p = tx.data;
        desc = 'From: ${p.supplierName} (${p.items.length} items)';
      }
      
      // Trim description if too long for PDF table
      if (desc.length > 50) desc = '${desc.substring(0, 47)}...';

      return {
        'time': DateFormat('hh:mm a').format(tx.timestamp),
        'items': desc,
        'total': tx.amount.toStringAsFixed(2),
      };
    }).toList();

    try {
      await PdfHelper.generateReportSummaryPdf(
        reportTitle: 'Daily Financial Summary',
        fileNamePrefix: 'daily_report',
        shopName: shopName,
        dateString: dateLabel,
        totalRevenue: totalSales,
        totalExpense: totalPurchases,
        totalBills: transactions.length,
        totalCash: 0,
        totalQR: 0,
        topItems: [],
        transactions: mappedTx,
        isSimple: true,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _showTransactionDetails(BuildContext context, _UnifiedTransaction tx) {
    final isSale = tx.type == 'sale';
    final items = isSale
        ? (tx.data as SaleModel).items.map((i) => {
              'name': i.productName,
              'qty': i.quantity,
              'price': i.price,
              'total': i.quantity * i.price,
            }).toList()
        : (tx.data as PurchaseOrderModel).items.map((i) => {
              'name': i.productName,
              'qty': i.quantity,
              'price': i.unitCost,
              'total': i.quantity * i.unitCost,
              'size': i.size,
            }).toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: EdgeInsets.zero,
        title: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isSale ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Row(
            children: [
              Icon(isSale ? Icons.receipt_long : Icons.inventory, 
                color: isSale ? Colors.green : Colors.red),
              const SizedBox(width: 12),
              Text(isSale ? 'Sale Details' : 'Purchase Details', 
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Ref: #${tx.id.substring(0, 8).toUpperCase()}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  Text(DateFormat('hh:mm a').format(tx.timestamp), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              if (!isSale) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Supplier: ${(tx.data as PurchaseOrderModel).supplierName}', 
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ],
              const Divider(height: 24),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final item = items[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item['name'] as String, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                if (item['size'] != null)
                                  Text('Size: ${item['size']}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                              ],
                            ),
                          ),
                          Text('${item['qty']} x ₹${(item['price'] as double).toStringAsFixed(0)}', 
                            style: const TextStyle(fontSize: 12)),
                          const SizedBox(width: 12),
                          Text('₹${(item['total'] as double).toStringAsFixed(0)}', 
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('TOTAL AMOUNT', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('₹${tx.amount.toStringAsFixed(2)}', 
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isSale ? Colors.green : Colors.red)),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (isSale)
            ElevatedButton.icon(
              onPressed: () {
                final sale = tx.data as SaleModel;
                final shop = HiveDatabase.shopBox.get('shop_details');
                PdfHelper.generateAndShareReceipt(
                  shopName: shop?.name ?? 'My Shop',
                  invoiceNo: sale.id.substring(0, 8),
                  address1: shop?.addressLine1 ?? '',
                  address2: shop?.addressLine2 ?? '',
                  phone: shop?.phoneNumber ?? '',
                  items: sale.items.map((e) => {
                    'name': e.productName,
                    'qty': e.quantity,
                    'price': e.price,
                    'total': e.quantity * e.price,
                  }).toList(),
                  netAmount: sale.totalAmount,
                  discountAmount: 0,
                  total: sale.totalAmount,
                  footer: shop?.footerText ?? '',
                );
              }, 
              icon: const Icon(Icons.print, size: 18),
              label: const Text('Re-Print Bill'),
            ),
        ],
      ),
    );
  }
}
