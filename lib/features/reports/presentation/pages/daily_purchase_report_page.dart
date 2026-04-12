import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/data/hive_database.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/pdf_helper.dart';
import '../../../shop/data/models/shop_model.dart';
import '../../data/models/purchase_order_model.dart';

class DailyPurchaseReportPage extends StatefulWidget {
  /// If provided, shows report for that specific date. Defaults to today.
  final DateTime? targetDate;
  const DailyPurchaseReportPage({super.key, this.targetDate});

  @override
  State<DailyPurchaseReportPage> createState() =>
      _DailyPurchaseReportPageState();
}

class _DailyPurchaseReportPageState extends State<DailyPurchaseReportPage> {
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    _date = widget.targetDate ?? DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box<PurchaseOrderModel>>(
      valueListenable: HiveDatabase.purchaseOrdersBox.listenable(),
      builder: (context, box, _) {
        final isToday = widget.targetDate == null &&
            _date.year == DateTime.now().year &&
            _date.month == DateTime.now().month &&
            _date.day == DateTime.now().day;

        final dayOrders = box.values.where((order) {
          return order.timestamp.year == _date.year &&
              order.timestamp.month == _date.month &&
              order.timestamp.day == _date.day;
        }).toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

        final dateLabel = isToday
            ? 'Today'
            : DateFormat('dd MMM yyyy').format(_date);

        final totalSpend =
            dayOrders.fold(0.0, (sum, o) => sum + o.totalAmount);
        final totalItems = dayOrders.fold(
            0, (sum, o) => sum + o.items.fold(0, (s, i) => s + i.quantity));

        return Scaffold(
          appBar: AppBar(
            title: Text(
              isToday ? 'Daily Purchase Report' : 'Purchases: $dateLabel',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.chevron_left,
                  size: 28, color: Theme.of(context).primaryColor),
              onPressed: () => context.pop(),
            ),
            actions: [
              // Date picker
              IconButton(
                icon: const Icon(Icons.calendar_month, color: AppTheme.primaryColor),
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
              // PDF export
              IconButton(
                icon: const Icon(Icons.picture_as_pdf,
                    color: AppTheme.primaryColor),
                onPressed: () async {
                  if (dayOrders.isEmpty) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content:
                              Text('No purchases on $dateLabel to download.')));
                    }
                    return;
                  }
                  final shopBox = HiveDatabase.shopBox;
                  final shopDetails =
                      shopBox.get('shop_details') as ShopModel?;
                  final shopName = shopDetails?.name ?? 'My Shop';
                  final dateStr = DateFormat('dd-MM-yyyy').format(_date);

                  // Top purchased items
                  final itemQtys = <String, int>{};
                  for (final order in dayOrders) {
                    for (final item in order.items) {
                      itemQtys[item.productName] =
                          (itemQtys[item.productName] ?? 0) + item.quantity;
                    }
                  }
                  final topItems = itemQtys.entries.toList()
                    ..sort((a, b) => b.value.compareTo(a.value));
                  final mappedTop = topItems.take(5).map((e) =>
                      {'name': e.key, 'qty': e.value}).toList();

                  final mappedTx = dayOrders.map((o) => {
                        'time': DateFormat('hh:mm a').format(o.timestamp),
                        'items':
                            '${o.items.length} item(s) from ${o.supplierName}',
                        'total': o.totalAmount.toStringAsFixed(2),
                      }).toList();

                  try {
                    await PdfHelper.generateReportSummaryPdf(
                      reportTitle: 'Daily Purchase Report',
                      fileNamePrefix: 'daily_purchase_report',
                      shopName: shopName,
                      dateString: dateStr,
                      totalRevenue: 0.0,
                      totalExpense: totalSpend,
                      totalBills: dayOrders.length,
                      topItems: mappedTop,
                      transactions: mappedTx,
                    );
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to open PDF: $e')));
                    }
                  }
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Column(
            children: [
              // ── Summary header ────────────────────────────────────────
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF2E7D32),
                      const Color(0xFF43A047),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2E7D32).withValues(alpha: 0.3),
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
                          isToday ? 'TODAY\'S PURCHASES' : '${dateLabel.toUpperCase()} PURCHASES',
                          style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1),
                        ),
                        const SizedBox(height: 8),
                        Text('₹${totalSpend.toStringAsFixed(2)}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('$totalItems units received',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 10)),
                      ],
                    ),
                    Container(width: 1, height: 40, color: Colors.white24),
                    Column(
                      children: [
                        const Text('ORDERS',
                            style: TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1)),
                        const SizedBox(height: 8),
                        Text('${dayOrders.length}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),

              const Padding(
                padding:
                    EdgeInsets.only(left: 24, right: 24, top: 4, bottom: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('PURCHASE ORDERS',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                          letterSpacing: 1.2)),
                ),
              ),

              // ── Orders list ───────────────────────────────────────────
              Expanded(
                child: dayOrders.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.shopping_cart_outlined,
                                size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text(
                              'No purchases recorded for $dateLabel.',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 32),
                        itemCount: dayOrders.length,
                        itemBuilder: (context, index) {
                          final order = dayOrders[index];
                          return _PurchaseOrderTile(order: order);
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

class _PurchaseOrderTile extends StatelessWidget {
  final PurchaseOrderModel order;
  const _PurchaseOrderTile({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF2E7D32).withValues(alpha: 0.1),
          child: const Icon(Icons.local_shipping_outlined,
              color: Color(0xFF2E7D32)),
        ),
        title: Text(
          order.supplierName.isEmpty ? 'Unknown Supplier' : order.supplierName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          '${order.items.length} item(s) • ${DateFormat('hh:mm a').format(order.timestamp)}',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing: Text(
          '₹${order.totalAmount.toStringAsFixed(2)}',
          style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Color(0xFF2E7D32)),
        ),
        childrenPadding:
            const EdgeInsets.only(left: 16, right: 16, bottom: 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          ...order.items.map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(item.productName,
                          style:
                              const TextStyle(fontWeight: FontWeight.w500)),
                    ),
                    Text(
                      '${item.quantity} × ₹${item.unitCost.toStringAsFixed(2)} = ₹${item.totalCost.toStringAsFixed(2)}',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              )),
          if (order.notes.isNotEmpty) ...[
            const Divider(),
            Row(
              children: [
                const Icon(Icons.notes, size: 14, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                    child: Text(order.notes,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[600]))),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
