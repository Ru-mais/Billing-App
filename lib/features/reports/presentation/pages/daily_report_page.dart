import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/data/hive_database.dart';
import '../../data/models/sale_model.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class DailyReportPage extends StatelessWidget {
  const DailyReportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Report', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.chevron_left, size: 28, color: Theme.of(context).primaryColor),
          onPressed: () => context.pop(),
        ),
      ),
      body: ValueListenableBuilder<Box<SaleModel>>(
        valueListenable: HiveDatabase.salesBox.listenable(),
        builder: (context, box, _) {
          final now = DateTime.now();
          final todaySales = box.values.where((sale) {
            return sale.timestamp.year == now.year &&
                sale.timestamp.month == now.month &&
                sale.timestamp.day == now.day;
          }).toList()
            ..sort((a, b) => b.timestamp.compareTo(a.timestamp)); // Newest first

          final totalToday = todaySales.fold(0.0, (sum, sale) => sum + sale.totalAmount);

          return Column(
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
                        const Text('TODAY\'S SALES', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                        const SizedBox(height: 8),
                        Text('₹${totalToday.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
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

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
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
                               child: Icon(Icons.receipt, color: AppTheme.primaryColor)
                            ),
                            title: Text('Bill at ${DateFormat('hh:mm a').format(sale.timestamp)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('${sale.items.length} items'),
                            trailing: Text('₹${sale.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          );
                        },
                      ),
              )
            ],
          );
        },
      ),
    );
  }
}
