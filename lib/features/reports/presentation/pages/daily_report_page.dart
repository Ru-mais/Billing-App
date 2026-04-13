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
                  : (tx.data as PurchaseOrderModel)
                      .items
                      .map((i) => i.productName);
              return itemNames.any((name) => name.toLowerCase().contains(q));
            }).toList();

            final isToday = widget.targetDate == null &&
                _date.year == DateTime.now().year &&
                _date.month == DateTime.now().month &&
                _date.day == DateTime.now().day;

            final dateLabel =
                isToday ? 'Today' : DateFormat('dd MMM yyyy').format(_date);

            final totalSales = sales.fold(0.0, (sum, s) => sum + s.totalAmount);
            final totalPurchases =
                purchases.fold(0.0, (sum, p) => sum + p.totalAmount);
            final netBalance = totalSales - totalPurchases;

            return Scaffold(
              appBar: AppBar(
                title: Text(isToday ? 'Daily Dashboard' : 'Report: $dateLabel',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18)),
                centerTitle: true,
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: Icon(Icons.chevron_left,
                      size: 28, color: Theme.of(context).primaryColor),
                  onPressed: () => context.pop(),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.picture_as_pdf,
                        color: AppTheme.primaryColor),
                    tooltip: 'Export Report',
                    onPressed: () async {
                      if (transactions.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('No data to export.')));
                        return;
                      }

                      final shopBox = HiveDatabase.shopBox;
                      final shopDetails = shopBox.get('shop_details');
                      final shopName = shopDetails?.name ?? 'My Shop';

                      // Data Aggregation
                      final salesList = transactions
                          .where((t) => t.type == 'sale')
                          .map((t) => t.data as SaleModel)
                          .toList();
                      final totalCash = salesList
                          .where((s) => s.paymentMethod != 'QR')
                          .fold(0.0, (sum, s) => sum + s.totalAmount);
                      final totalQR = salesList
                          .where((s) => s.paymentMethod == 'QR')
                          .fold(0.0, (sum, s) => sum + s.totalAmount);

                      final itemQuantities = <String, int>{};
                      for (final sale in salesList) {
                        for (final item in sale.items) {
                          itemQuantities[item.productName] =
                              (itemQuantities[item.productName] ?? 0) +
                                  item.quantity;
                        }
                      }
                      final topItemsSorted = itemQuantities.entries.toList()
                        ..sort((a, b) => b.value.compareTo(a.value));
                      final mappedTop = topItemsSorted
                          .take(5)
                          .map((e) => {'name': e.key, 'qty': e.value})
                          .toList();

                      final mappedTx = transactions
                          .map((tx) => {
                                'time':
                                    DateFormat('hh:mm a').format(tx.timestamp),
                                'items': tx.type == 'sale'
                                    ? 'Sale (${(tx.data as SaleModel).items.length} items)'
                                    : 'Purchase (from ${(tx.data as PurchaseOrderModel).supplierName})',
                                'total': tx.amount.toStringAsFixed(2),
                              })
                          .toList();

                      try {
                        await PdfHelper.generateReportSummaryPdf(
                          reportTitle: 'Daily Financial Report',
                          fileNamePrefix: 'daily_report',
                          shopName: shopName,
                          dateString: dateLabel,
                          totalRevenue: totalSales,
                          totalExpense: totalPurchases,
                          totalBills: salesList.length,
                          totalCash: totalCash,
                          totalQR: totalQR,
                          topItems: mappedTop,
                          transactions: mappedTx,
                          isSimple: true, // Always simplified
                        );
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('Failed to export PDF: $e')));
                        }
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.calendar_month,
                        color: AppTheme.primaryColor),
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
                ],
              ),
              body: Column(
                children: [
                  Container(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        _miniSummaryTile('Sales', totalSales, Colors.green),
                        const SizedBox(width: 8),
                        _miniSummaryTile(
                            'Expenses', totalPurchases, Colors.red),
                        const SizedBox(width: 8),
                        _miniSummaryTile('Profit', netBalance,
                            netBalance >= 0 ? Colors.blue : Colors.orange),
                      ],
                    ),
                  ),
                  // Unified Summary Header
                  Container(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4))
                      ],
                      border: Border.all(color: Colors.grey.shade100),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _summaryItem('SALES', totalSales, Colors.green),
                            _summaryItem(
                                'PURCHASES', totalPurchases, Colors.red),
                          ],
                        ),
                        const Divider(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('NET BALANCE',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                    fontSize: 12)),
                            Text(
                              '₹${netBalance.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color:
                                    netBalance >= 0 ? Colors.green : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('TIMELINE',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                              letterSpacing: 1.2)),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Search transaction, supplier, item',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) => setState(() => _query = value),
                    ),
                  ),
                  const SizedBox(height: 8),

                  Expanded(
                    child: filteredTransactions.isEmpty
                        ? const Center(
                            child: Text(
                                'No transactions found for this filter.',
                                style: TextStyle(color: Colors.grey)))
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 24),
                            itemCount: filteredTransactions.length,
                            itemBuilder: (context, index) {
                              final tx = filteredTransactions[index];
                              final isSale = tx.type == 'sale';
                              return ListTile(
                                onTap: () =>
                                    _showTransactionDetails(context, tx),
                                leading: CircleAvatar(
                                  backgroundColor: isSale
                                      ? Colors.green.withValues(alpha: 0.1)
                                      : Colors.red.withValues(alpha: 0.1),
                                  child: Icon(
                                    isSale
                                        ? Icons.south_west
                                        : Icons.north_east,
                                    color: isSale ? Colors.green : Colors.red,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  isSale
                                      ? 'Sale: ${tx.id.substring(0, 5)}'
                                      : 'Purchase Order',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  DateFormat('hh:mm a').format(tx.timestamp),
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: Text(
                                  '${isSale ? '+' : '-'} ₹${tx.amount.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: isSale ? Colors.green : Colors.red,
                                  ),
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

  void _showTransactionDetails(BuildContext context, _UnifiedTransaction tx) {
    final isSale = tx.type == 'sale';
    final items = isSale
        ? (tx.data as SaleModel)
            .items
            .map((i) => {
                  'name': i.productName,
                  'qty': i.quantity,
                  'price': i.price,
                  'total': i.price * i.quantity
                })
            .toList()
        : (tx.data as PurchaseOrderModel)
            .items
            .map((i) => {
                  'name': i.productName,
                  'qty': i.quantity,
                  'price': i.unitCost,
                  'total': i.totalCost
                })
            .toList();
    final netAmount = isSale
        ? items.fold<double>(
            0.0, (sum, item) => sum + (item['total'] as double))
        : tx.amount;
    final discountAmount = isSale
        ? (netAmount - tx.amount).clamp(0, double.infinity).toDouble()
        : 0.0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(isSale ? 'Sale Receipt' : 'Purchase Order',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detailRow(
                    'ID / Supplier',
                    isSale
                        ? tx.id.substring(0, 8)
                        : (tx.data as PurchaseOrderModel).supplierName),
                _detailRow('Date & Time',
                    DateFormat('dd MMM yyyy, hh:mm a').format(tx.timestamp)),
                if (isSale)
                  _detailRow('Payment', (tx.data as SaleModel).paymentMethod),
                const Divider(height: 32),
                const Text('ITEMS',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                        letterSpacing: 1)),
                const SizedBox(height: 8),
                ...items.map((item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                              child: Text(item['name'] as String,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500))),
                          Text(
                              '${item['qty']} x ₹${(item['price'] as double).toStringAsFixed(0)}',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey)),
                          const SizedBox(width: 8),
                          Text(
                              '₹${(item['total'] as double).toStringAsFixed(0)}',
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )),
                const Divider(height: 32),
                if (isSale) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('NET AMOUNT',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                              fontSize: 12)),
                      Text('₹${netAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('DISCOUNT',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                              fontSize: 12)),
                      Text('- ₹${discountAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.redAccent)),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(isSale ? 'TOTAL' : 'TOTAL AMOUNT',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                            fontSize: 12)),
                    Text('₹${tx.amount.toStringAsFixed(2)}',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isSale ? Colors.green : Colors.red)),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              final shopBox = HiveDatabase.shopBox;
              final shopDetails = shopBox.get('shop_details');

              if (isSale) {
                await PdfHelper.generateAndShareReceipt(
                  shopName: shopDetails?.name ?? 'My Shop',
                  invoiceNo: tx.id.substring(0, 8).toUpperCase(),
                  address1: shopDetails?.addressLine1 ?? '',
                  address2: shopDetails?.addressLine2 ?? '',
                  phone: shopDetails?.phoneNumber ?? '',
                  items: items,
                  netAmount: netAmount,
                  discountAmount: discountAmount,
                  total: tx.amount,
                  footer:
                      shopDetails?.footerText ?? 'Thank you for your business!',
                );
              } else {
                // For purchase, we can use the summary generator or generic share
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text(
                        'Use the report export for full purchase ledger.')));
              }
            },
            icon: const Icon(Icons.print),
            label: Text(isSale ? 'Print Receipt' : 'Share'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, double amount, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: Colors.grey,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1)),
        const SizedBox(height: 4),
        Text('₹${amount.toStringAsFixed(2)}',
            style: TextStyle(
                color: color, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _miniSummaryTile(String label, double value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            Text(label,
                style: TextStyle(
                    color: color.withValues(alpha: 0.7),
                    fontSize: 10,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('₹${value.toStringAsFixed(0)}',
                style: TextStyle(
                    color: color, fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
