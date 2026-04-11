import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/data/hive_database.dart';
import '../../data/models/sale_model.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/utils/pdf_helper.dart';
import '../../../shop/data/models/shop_model.dart';

class DailyReportPage extends StatelessWidget {
  /// If provided, shows report for that specific date. Defaults to today.
  final DateTime? targetDate;
  const DailyReportPage({super.key, this.targetDate});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box<SaleModel>>(
      valueListenable: HiveDatabase.salesBox.listenable(),
      builder: (context, box, _) {
        final now = DateTime.now();
        final date = targetDate ?? now;
        final todaySales = box.values.where((sale) {
          return sale.timestamp.year == date.year &&
                 sale.timestamp.month == date.month &&
                 sale.timestamp.day == date.day;
        }).toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

        final isToday = targetDate == null;
        final dateLabel = isToday
            ? 'Today'
            : DateFormat('dd MMM yyyy').format(date); // Newest first

        final totalToday = todaySales.fold(0.0, (sum, sale) => sum + sale.totalAmount);
        final totalCash = todaySales.where((s) => s.paymentMethod != 'QR').fold(0.0, (sum, sale) => sum + sale.totalAmount);
        final totalQR = todaySales.where((s) => s.paymentMethod == 'QR').fold(0.0, (sum, sale) => sum + sale.totalAmount);

        // Top selling logic
        final itemQuantities = <String, int>{};
        final itemNames = <String, String>{};
        for (final sale in todaySales) {
          for (final item in sale.items) {
            final currentQty = itemQuantities[item.productId] ?? 0;
            itemQuantities[item.productId] = currentQty + item.quantity;
            itemNames[item.productId] = item.productName;
          }
        }
        final topItems = itemQuantities.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final top3 = topItems.take(3).toList();

        return Scaffold(
          appBar: AppBar(
            title: Text(
              isToday ? 'Daily Report' : 'Report: $dateLabel',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
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
                  if (todaySales.isEmpty) {
                     if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No sales on $dateLabel to download.')));
                     return;
                  }

                  final shopBox = HiveDatabase.shopBox;
                  final shopDetails = shopBox.get('shop_details') as ShopModel?;
                  final shopName = shopDetails?.name ?? 'My Shop';
                  
                  final dateStr = DateFormat('dd-MM-yyyy').format(date);
                  
                  final mappedTop = top3.map((entry) => {
                     'name': itemNames[entry.key] ?? 'Unknown',
                     'qty': entry.value
                  }).toList();
                  
                  final mappedTx = todaySales.map((sale) => {
                     'time': DateFormat('hh:mm a').format(sale.timestamp),
                     'items': '${sale.items.length} items (${sale.paymentMethod})',
                     'total': sale.totalAmount.toStringAsFixed(2),
                  }).toList();

                  try {
                    await PdfHelper.generateReportSummaryPdf(
                       reportTitle: 'Daily Sales Report',
                       fileNamePrefix: 'daily_report',
                       shopName: shopName,
                       dateString: dateStr,
                       totalRevenue: totalToday,
                       totalBills: todaySales.length,
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
                        Text(
                          isToday ? 'TODAY\'S SALES' : '${dateLabel.toUpperCase()} SALES',
                          style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                        ),
                        const SizedBox(height: 8),
                        Text('₹${totalToday.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('Cash: ₹${totalCash.toStringAsFixed(0)} | QR: ₹${totalQR.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white70, fontSize: 10)),
                      ],
                    ),
                    Container(width: 1, height: 40, color: Colors.white24),
                    Column(
                      children: [
                        const Text('BILLS', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                        const SizedBox(height: 8),
                        Text('${todaySales.length}', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
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
                  child: Text('TRANSACTIONS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
                ),
              ),
              
              Expanded(
                child: todaySales.isEmpty
                    ? const Center(child: Text('No sales for today.', style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        itemCount: todaySales.length,
                        itemBuilder: (context, index) {
                          final sale = todaySales[index];
                          return ListTile(
                            leading: CircleAvatar(
                               backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                               child: const Icon(Icons.receipt, color: AppTheme.primaryColor)
                            ),
                            title: Text('Bill at ${DateFormat('hh:mm a').format(sale.timestamp)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('${sale.items.length} items • ${sale.paymentMethod}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('₹${sale.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(width: 8),
                                Container(
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.download, color: AppTheme.primaryColor, size: 20),
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.all(8),
                                    onPressed: () async {
                                      final settingsBox = HiveDatabase.settingsBox;
                                      final shopBox = HiveDatabase.shopBox;
                                      
                                      final shopDetails = shopBox.get('shop_details') as ShopModel?;
                                      
                                      final shopName = shopDetails?.name ?? 'My Shop';
                                      final address1 = shopDetails?.addressLine1 ?? '';
                                      final address2 = shopDetails?.addressLine2 ?? '';
                                      final phone = shopDetails?.phoneNumber ?? '';
                                      final footer = shopDetails?.footerText ?? 'Thank you for visiting!';
                                      
                                      final mappedItems = sale.items.map((item) => {
                                        'name': item.productName,
                                        'qty': item.quantity,
                                        'price': item.price,
                                        'total': item.price * item.quantity,
                                      }).toList();
                                      
                                      try {
                                        await PdfHelper.generateAndShareReceipt(
                                          shopName: shopName,
                                          address1: address1,
                                          address2: address2,
                                          phone: phone,
                                          items: mappedItems,
                                          total: sale.totalAmount,
                                          footer: footer,
                                        );
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to open PDF: $e')));
                                        }
                                      }
                                    }
                                  )
                                )
                              ]
                            )
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
