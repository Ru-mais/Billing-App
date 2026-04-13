import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/data/hive_database.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/pdf_helper.dart';
import '../../data/models/purchase_order_model.dart';
import 'daily_purchase_report_page.dart';

class MonthlyPurchaseReportPage extends StatefulWidget {
  const MonthlyPurchaseReportPage({super.key});

  @override
  State<MonthlyPurchaseReportPage> createState() =>
      _MonthlyPurchaseReportPageState();
}

class _MonthlyPurchaseReportPageState
    extends State<MonthlyPurchaseReportPage> {
  late DateTime _viewMonth;

  @override
  void initState() {
    super.initState();
    _viewMonth = DateTime.now();
  }

  void _previousMonth() {
    setState(() {
      _viewMonth = DateTime(_viewMonth.year, _viewMonth.month - 1);
    });
  }

  void _nextMonth() {
    final now = DateTime.now();
    if (_viewMonth.year < now.year ||
        (_viewMonth.year == now.year && _viewMonth.month < now.month)) {
      setState(() {
        _viewMonth = DateTime(_viewMonth.year, _viewMonth.month + 1);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box<PurchaseOrderModel>>(
      valueListenable: HiveDatabase.purchaseOrdersBox.listenable(),
      builder: (context, box, _) {
        final monthOrders = box.values.where((order) {
          return order.timestamp.year == _viewMonth.year &&
              order.timestamp.month == _viewMonth.month;
        }).toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

        final totalSpend =
            monthOrders.fold(0.0, (sum, o) => sum + o.totalAmount);

        // Top purchased items
        final itemQtys = <String, int>{};
        for (final order in monthOrders) {
          for (final item in order.items) {
            itemQtys[item.productName] =
                (itemQtys[item.productName] ?? 0) + item.quantity;
          }
        }
        final topItems = itemQtys.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final top3 = topItems.take(3).toList();

        // Daily aggregates
        final dailyAggregates = <int, Map<String, dynamic>>{};
        for (final order in monthOrders) {
          final day = order.timestamp.day;
          if (!dailyAggregates.containsKey(day)) {
            dailyAggregates[day] = {
              'total': 0.0,
              'orders': 0,
              'timestamp': order.timestamp,
              'suppliers': <String>{},
            };
          }
          dailyAggregates[day]!['total'] += order.totalAmount;
          dailyAggregates[day]!['orders'] += 1;
          (dailyAggregates[day]!['suppliers'] as Set<String>)
              .add(order.supplierName.isEmpty ? 'Unknown' : order.supplierName);
        }
        final sortedDays = dailyAggregates.keys.toList()
          ..sort((a, b) => b.compareTo(a));

        final monthLabel = DateFormat('MMMM yyyy').format(_viewMonth);
        final isCurrentMonth = _viewMonth.year == DateTime.now().year &&
            _viewMonth.month == DateTime.now().month;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Monthly Purchase Report',
                style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
                onPressed: () async {
                  if (monthOrders.isEmpty) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(
                              'No purchases in $monthLabel to download.')));
                    }
                    return;
                  }
                  final shopBox = HiveDatabase.shopBox;
                  final shopDetails =
                      shopBox.get('shop_details');
                  final shopName = shopDetails?.name ?? 'My Shop';

                  final mappedTop = top3
                      .map((e) => {'name': e.key, 'qty': e.value}).toList();

                  final mappedTx = sortedDays.map((day) {
                    final agg = dailyAggregates[day]!;
                    final suppliers = (agg['suppliers'] as Set<String>).toList();
                    final supplierLabel = suppliers.isEmpty
                        ? 'Unknown'
                        : suppliers.take(3).join(', ');
                    return {
                      'time': DateFormat('dd MMM yyyy')
                          .format(agg['timestamp']),
                      'items':
                          '${agg['orders']} order(s) • Suppliers: $supplierLabel',
                      'total':
                          (agg['total'] as double).toStringAsFixed(2),
                    };
                  }).toList();

                  try {
                    await PdfHelper.generateReportSummaryPdf(
                      reportTitle: 'Monthly Purchase Report',
                      fileNamePrefix: 'monthly_purchase_report',
                      shopName: shopName,
                      dateString: monthLabel,
                      totalRevenue: 0.0,
                      totalExpense: totalSpend,
                      totalBills: monthOrders.length,
                      topItems: mappedTop,
                      transactions: mappedTx,
                    );
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Failed to open PDF: $e')));
                    }
                  }
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Column(
            children: [
              // ── Month selector ────────────────────────────────────────
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: _previousMonth,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      monthLabel,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: isCurrentMonth ? null : _nextMonth,
                      color: isCurrentMonth
                          ? Colors.grey[300]
                          : AppTheme.primaryColor,
                    ),
                  ],
                ),
              ),

              // ── Summary header ────────────────────────────────────────
              Container(
                margin:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1B5E20), Color(0xFF388E3C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1B5E20).withValues(alpha: 0.3),
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
                        const Text('TOTAL PURCHASES',
                            style: TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1)),
                        const SizedBox(height: 8),
                        Text('₹${totalSpend.toStringAsFixed(2)}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Container(
                        width: 1, height: 40, color: Colors.white24),
                    Column(
                      children: [
                        const Text('ORDERS',
                            style: TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1)),
                        const SizedBox(height: 8),
                        Text('${monthOrders.length}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Top purchased items ───────────────────────────────────
              if (top3.isNotEmpty)
                Container(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 4),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('TOP PURCHASED ITEMS',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                              letterSpacing: 1.2)),
                      const SizedBox(height: 12),
                      ...top3.map((entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                    child: Text(entry.key,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis)),
                                Text('${entry.value} units',
                                    style: const TextStyle(
                                        color: Color(0xFF2E7D32),
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),

              const Padding(
                padding:
                    EdgeInsets.only(left: 24, right: 24, top: 12, bottom: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('DAILY BREAKDOWN',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                          letterSpacing: 1.2)),
                ),
              ),

              // ── Daily list ────────────────────────────────────────────
              Expanded(
                child: sortedDays.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.shopping_cart_outlined,
                                size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text(
                              'No purchases recorded for $monthLabel.',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
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
                                  builder: (_) => DailyPurchaseReportPage(
                                      targetDate: dayDate),
                                ),
                              );
                            },
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFF2E7D32)
                                    .withValues(alpha: 0.1),
                                child: Text(
                                  '$day',
                                  style: const TextStyle(
                                      color: Color(0xFF2E7D32),
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(
                                DateFormat('dd MMMM yyyy').format(dayDate),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                  '${agg['orders']} order(s)'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '₹${(agg['total'] as double).toStringAsFixed(2)}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Color(0xFF2E7D32)),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(Icons.chevron_right,
                                      color: Colors.grey[300]),
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
  }
}
