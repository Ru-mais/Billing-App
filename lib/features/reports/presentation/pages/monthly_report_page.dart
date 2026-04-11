import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/data/hive_database.dart';
import '../../data/models/sale_model.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/utils/pdf_helper.dart';
import '../../../shop/data/models/shop_model.dart';
import 'daily_report_page.dart';

class MonthlyReportPage extends StatelessWidget {
  const MonthlyReportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box<SaleModel>>(
      valueListenable: HiveDatabase.salesBox.listenable(),
      builder: (context, box, _) {
        final now = DateTime.now();
        final thisMonthSales = box.values.where((sale) {
          return sale.timestamp.year == now.year &&
                 sale.timestamp.month == now.month;
        }).toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp)); // Newest first

        final totalThisMonth = thisMonthSales.fold(0.0, (sum, sale) => sum + sale.totalAmount);
        final totalCash = thisMonthSales.where((s) => s.paymentMethod != 'QR').fold(0.0, (sum, sale) => sum + sale.totalAmount);
        final totalQR = thisMonthSales.where((s) => s.paymentMethod == 'QR').fold(0.0, (sum, sale) => sum + sale.totalAmount);

        // Top selling logic
        final itemQuantities = <String, int>{};
        final itemNames = <String, String>{};
        for (final sale in thisMonthSales) {
          for (final item in sale.items) {
            final currentQty = itemQuantities[item.productId] ?? 0;
            itemQuantities[item.productId] = currentQty + item.quantity;
            itemNames[item.productId] = item.productName;
          }
        }
        final topItems = itemQuantities.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final top3 = topItems.take(3).toList();

        final dailyAggregates = <int, Map<String, dynamic>>{};
        for (final sale in thisMonthSales) {
          final day = sale.timestamp.day;
          if (!dailyAggregates.containsKey(day)) {
            dailyAggregates[day] = {'total': 0.0, 'cash': 0.0, 'qr': 0.0, 'bills': 0, 'timestamp': sale.timestamp};
          }
          final isQR = sale.paymentMethod == 'QR';
          dailyAggregates[day]!['total'] += sale.totalAmount;
          if (isQR) {
            dailyAggregates[day]!['qr'] += sale.totalAmount;
          } else {
            dailyAggregates[day]!['cash'] += sale.totalAmount;
          }
          dailyAggregates[day]!['bills'] += 1;
        }
        final sortedDays = dailyAggregates.keys.toList()..sort((a, b) => b.compareTo(a));

        return Scaffold(
          appBar: AppBar(
            title: const Text('Monthly Report', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
                onPressed: () async {
                  if (thisMonthSales.isEmpty) {
                     if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No sales this month to download.')));
                     return;
                  }

                  final shopBox = HiveDatabase.shopBox;
                  final shopDetails = shopBox.get('shop_details') as ShopModel?;
                  final shopName = shopDetails?.name ?? 'My Shop';
                  
                  final dateStr = DateFormat('MMM yyyy').format(now);
                  
                  final mappedTop = top3.map((entry) => {
                     'name': itemNames[entry.key] ?? 'Unknown',
                     'qty': entry.value
                  }).toList();
                  
                  final mappedTx = sortedDays.map((day) {
                     final agg = dailyAggregates[day]!;
                     return {
                       'time': DateFormat('dd MMM yyyy').format(agg['timestamp']),
                       'items': 'Cash: ₹${(agg['cash'] as double).toStringAsFixed(0)} | QR: ₹${(agg['qr'] as double).toStringAsFixed(0)}',
                       'total': (agg['total'] as double).toStringAsFixed(2),
                     };
                  }).toList();

                  try {
                    await PdfHelper.generateReportSummaryPdf(
                       reportTitle: 'Monthly Sales Report',
                       fileNamePrefix: 'monthly_report',
                       shopName: shopName,
                       dateString: dateStr,
                       totalRevenue: totalThisMonth,
                       totalBills: thisMonthSales.length,
                       totalCash: totalCash,
                       totalQR: totalQR,
                       topItems: mappedTop,
                       transactions: mappedTx,
                    );
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to open PDF: $e')));
                    }
                  }
                }
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Column(
            children: [
              // Summary Header
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    )
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                     Column(
                      children: [
                        const Text('THIS MONTH\'S SALES', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                        const SizedBox(height: 8),
                        Text('₹${totalThisMonth.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('Cash: ₹${totalCash.toStringAsFixed(0)} | QR: ₹${totalQR.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white70, fontSize: 10)),
                      ],
                    ),
                    Container(width: 1, height: 40, color: Colors.white24),
                    Column(
                      children: [
                        const Text('BILLS', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                        const SizedBox(height: 8),
                        Text('${thisMonthSales.length}', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),

              // Top Selling Items Section
              if (top3.isNotEmpty)
                 Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                       color: Colors.white,
                       borderRadius: BorderRadius.circular(16),
                       border: Border.all(color: Colors.grey.shade200)
                    ),
                    child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                          const Text('TOP SELLING ITEMS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
                          const SizedBox(height: 12),
                          ...top3.map((entry) {
                             return Padding(
                               padding: const EdgeInsets.only(bottom: 8.0),
                               child: Row(
                                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                 children: [
                                   Expanded(child: Text(itemNames[entry.key] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                   Text('${entry.value} units', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                                 ]
                               ),
                             );
                          }),
                       ]
                    )
                 ),

              const Padding(
                padding: EdgeInsets.only(left: 24, right: 24, top: 16, bottom: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('DAILY BREAKDOWN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
                ),
              ),
              
              Expanded(
                child: sortedDays.isEmpty
                    ? const Center(child: Text('No sales for this month.', style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 32),
                        itemCount: sortedDays.length,
                        itemBuilder: (context, index) {
                          final day = sortedDays[index];
                          final agg = dailyAggregates[day]!;
                          final dayDate = agg['timestamp'] as DateTime;
                          return InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => DailyReportPage(targetDate: dayDate),
                                ),
                              );
                            },
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                                child: Text(
                                  '${day}',
                                  style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(
                                DateFormat('dd MMMM yyyy').format(dayDate),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text('${agg['bills']} bill(s) • QR: ₹${(agg['qr'] as double).toStringAsFixed(0)} • Cash: ₹${(agg['cash'] as double).toStringAsFixed(0)}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '₹${(agg['total'] as double).toStringAsFixed(2)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(Icons.chevron_right, color: Colors.grey[300]),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              )
            ],
          ),
        );
      },
    );
  }
}
