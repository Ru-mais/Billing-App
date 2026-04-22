import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:app_settings/app_settings.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/sync_manager.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../shop/presentation/bloc/shop_bloc.dart';
import '../bloc/printer_bloc.dart';
import '../bloc/printer_event.dart';
import '../bloc/printer_state.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Future<void> _forceSyncNow() async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Syncing with cloud...')),
    );
    await SyncManager.pullAll();
    final health = SyncManager.syncHealthNotifier.value;
    if (!mounted) return;
    final isSuccess = health.status == 'success' || health.status == 'degraded';
    messenger.showSnackBar(
      SnackBar(
        content: Text(
            health.message ?? (isSuccess ? 'Sync complete' : 'Sync failed')),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    context.read<PrinterBloc>().add(InitPrinterEvent());
  }

  Widget _buildBoxButton(String text, VoidCallback onTap) {
    final borderColor = Theme.of(context).dividerColor.withOpacity(0.1);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: borderColor),
        ),
        child: Text(text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w500)),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    final borderColor = Theme.of(context).dividerColor.withOpacity(0.1);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        centerTitle: false,
        automaticallyImplyLeading: false, // Removing default leading to respect the screenshot explicitly requested.
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            // Management Section
            _buildSection(
              'Management',
              [
                _buildBoxButton('Shop Details', () => context.push('/shop')),
                _buildBoxButton('Products', () => context.push('/products')),
                _buildBoxButton('Daily Report', () => context.push('/daily_report')),
                _buildBoxButton('Monthly Report', () => context.push('/monthly_report')),
                _buildBoxButton('Suppliers', () => context.push('/supplier_ledger')),
                _buildBoxButton('Stock Report', () => context.push('/product_report')),
              ],
            ),

            // Purchase Section
            _buildSection(
              'Purchase',
              [
                _buildBoxButton('Add Purchase', () => context.push('/add_purchase_order')),
                _buildBoxButton('Daily Purchase Report', () => context.push('/daily_purchase_report')),
                _buildBoxButton('Monthly Purchase Report', () => context.push('/monthly_purchase_report')),
              ],
            ),

            // Hardware Section
            _buildSection(
              'Hardware',
              [
                _buildBoxButton('Printer Connection', () {
                  AppSettings.openAppSettings(type: AppSettingsType.bluetooth);
                  context.read<PrinterBloc>().add(InitPrinterEvent());
                }),
              ],
            ),

            // Cloud & Security Section
            ValueListenableBuilder<SyncHealth>(
              valueListenable: SyncManager.syncHealthNotifier,
              builder: (context, health, _) {
                final lastSyncText = health.lastSyncAt == null
                    ? 'Never synced'
                    : 'Last Sync: ${DateFormat('dd MMM yyyy, hh:mm a').format(health.lastSyncAt!)}';

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: Theme.of(context).dividerColor.withOpacity(0.1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Cloud & Security',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(lastSyncText,
                          style: TextStyle(
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.color!
                                  .withOpacity(0.7),
                              fontSize: 12)),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _forceSyncNow,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F172A),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6)),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('Force Sync',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            await Supabase.instance.client.auth.signOut();
                            if (context.mounted) context.go('/login');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF3B30),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6)),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('Logout',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Standard Outlined Back Button below Logout as requested
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => context.pop(),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6)),
                            side: BorderSide(
                                color: Theme.of(context)
                                    .dividerColor
                                    .withOpacity(0.1)),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('Back',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
