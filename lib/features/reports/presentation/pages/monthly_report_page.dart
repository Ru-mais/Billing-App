import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/data/hive_database.dart';
import '../../data/models/sale_model.dart';
import '../../data/models/purchase_order_model.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/utils/pdf_helper.dart';
import 'daily_report_page.dart';

class MonthlyReportPage extends StatelessWidget {
  const MonthlyReportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box<SaleModel>>(
      valueListenable: HiveDatabase.salesBox.listenable(),
      builder: (context, salesBox, _) {
        return ValueListenableBuilder<Box<PurchaseOrderModel>>(
          valueListenable: HiveDatabase.purchaseOrdersBox.listenable(),
          builder: (context, purchaseBox, _) {
            final now = DateTime.now();
            
            final monthSales = salesBox.values.where((s) => s.timestamp.year == now.year && s.timestamp.month == now.month).toList();
            final monthPurchases = purchaseBox.values.where((p) => p.timestamp.year == now.year && p.timestamp.month == now.month).toList();

            final totalSales = monthSales.fold(0.0, (sum, s) => sum + s.totalAmount);
            final totalPurchases = monthPurchases.fold(0.0, (sum, p) => sum + p.totalAmount);
            final netBalance = totalSales - totalPurchases;

            // Aggregate by day
            final dailyAggregates = <int, Map<String, dynamic>>{};
            
            // Add sales to aggregates
            for (final s in monthSales) {
              final day = s.timestamp.day;
              if (!dailyAggregates.containsKey(day)) {
                dailyAggregates[day] = {'sales': 0.0, 'purchases': 0.0, 'timestamp': s.timestamp};
              }
              dailyAggregates[day]!['sales'] += s.totalAmount;
            }

            // Add purchases to aggregates
            for (final p in monthPurchases) {
              final day = p.timestamp.day;
              if (!dailyAggregates.containsKey(day)) {
                dailyAggregates[day] = {'sales': 0.0, 'purchases': 0.0, 'timestamp': p.timestamp};
              }
              dailyAggregates[day]!['purchases'] += p.totalAmount;
            }

            final sortedDays = dailyAggregates.keys.toList()..sort((a, b) => b.compareTo(a));

            return Scaffold(
              appBar: AppBar(
                title: const Text('Monthly Dashboard', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                centerTitle: true,
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: Icon(Icons.chevron_left, size: 28, color: Theme.of(context).primaryColor),
                  onPressed: () => context.pop(),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.picture_as_pdf, color: AppTheme.primaryColor),
                    tooltip: 'Export Report',
                    onPressed: () async {
                      if (monthSales.isEmpty && monthPurchases.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No data to export.')));
                        return;
                      }

                      final shopBox = HiveDatabase.shopBox;
                      final shopDetails = shopBox.get('shop_details');
                      final shopName = shopDetails?.name ?? 'My Shop';

                      final monthStr = DateFormat('MMMM yyyy').format(now);

                      final totalCash = monthSales.where((s) => s.paymentMethod != 'QR').fold(0.0, (sum, s) => sum + s.totalAmount);
                      final totalQR = monthSales.where((s) => s.paymentMethod == 'QR').fold(0.0, (sum, s) => sum + s.totalAmount);

                      final itemQuantities = <String, int>{};
                      for (final sale in monthSales) {
                        for (final item in sale.items) {
                          itemQuantities[item.productName] = (itemQuantities[item.productName] ?? 0) + item.quantity;
                        }
                      }
                      final topItemsSorted = itemQuantities.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
                      final mappedTop = topItemsSorted.take(5).map((e) => {'name': e.key, 'qty': e.value}).toList();

                      final mappedTx = sortedDays.map((day) {
                        final agg = dailyAggregates[day]!;
                        return {
                          'time': DateFormat('dd MMM').format(agg['timestamp']),
                          'items': 'Sales: Rs. ${agg['sales'].toStringAsFixed(0)} | Purchases: Rs. ${agg['purchases'].toStringAsFixed(0)}',
                          'total': (agg['sales'] - agg['purchases']).toStringAsFixed(2),
                        };
                      }).toList();

                      try {
                        await PdfHelper.generateReportSummaryPdf(
                          reportTitle: 'Monthly Growth Report',
                          fileNamePrefix: 'monthly_report',
                          shopName: shopName,
                          dateString: monthStr,
                          totalRevenue: totalSales,
                          totalExpense: totalPurchases,
                          totalBills: monthSales.length,
                          totalCash: totalCash,
                          totalQR: totalQR,
                          topItems: mappedTop,
                          transactions: mappedTx,
                          isSimple: true, // Always simple
                        );
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to export PDF: $e')));
                        }
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                ],
              ),
              body: Column(
                children: [
                  // Monthly Summary Header
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: AppTheme.primaryColor.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _whiteSummaryItem('MONTHLY SALES', totalSales),
                            Container(width: 1, height: 40, color: Colors.white24),
                            _whiteSummaryItem('MONTHLY PURCHASES', totalPurchases),
                          ],
                        ),
                        const Divider(height: 32, color: Colors.white24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('NET BALANCE', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                            Text(
                              '₹${netBalance.toStringAsFixed(2)}',
                              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
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
                      child: Text('DAILY BREAKDOWN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
                    ),
                  ),

                  Expanded(
                    child: sortedDays.isEmpty
                        ? const Center(child: Text('No activity this month.', style: TextStyle(color: Colors.grey)))
                        : ListView.separated(
                            padding: const EdgeInsets.only(bottom: 32, left: 16, right: 16),
                            itemCount: sortedDays.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final day = sortedDays[index];
                              final agg = dailyAggregates[day]!;
                              final daySales = agg['sales'] as double;
                              final dayPurchases = agg['purchases'] as double;
                              final dayNet = daySales - dayPurchases;
                              final dayDate = agg['timestamp'] as DateTime;

                              return InkWell(
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DailyReportPage(targetDate: dayDate))),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey.shade100),
                                    boxShadow: [
                                      BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))
                                    ],
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(DateFormat('dd MMM').format(dayDate), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                          Text(
                                            'Net: ₹${dayNet.toStringAsFixed(0)}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: dayNet >= 0 ? Colors.green : Colors.red,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          _miniStat('Sales', daySales, Colors.green),
                                          _miniStat('Purchases', dayPurchases, Colors.red),
                                        ],
                                      ),
                                    ],
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

  Widget _whiteSummaryItem(String label, double amount) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
        const SizedBox(height: 8),
        Text('₹${amount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _miniStat(String label, double amount, Color color) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text('$label: ', style: const TextStyle(color: Colors.grey, fontSize: 12)),
        Text('₹${amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
      ],
    );
  }
}
