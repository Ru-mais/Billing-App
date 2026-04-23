import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'config/routes/app_routes.dart';
import 'core/data/hive_database.dart';
import 'core/config/app_env.dart';
import 'core/service_locator.dart' as di;
import 'core/theme/app_theme.dart';
import 'features/billing/presentation/bloc/billing_bloc.dart';
import 'features/product/presentation/bloc/product_bloc.dart';
import 'features/shop/presentation/bloc/shop_bloc.dart';
import 'features/settings/presentation/bloc/printer_bloc.dart';
import 'features/settings/presentation/bloc/printer_event.dart';
import 'core/utils/sync_manager.dart';
import 'features/settings/presentation/bloc/theme_bloc.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/utils/backup_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: AppEnv.supabaseUrl,
    anonKey: AppEnv.supabaseAnonKey,
  );

  await HiveDatabase.init();
  await SyncManager.loadPersistedHealth();

  // 2. Initial Cloud Pull (Auto-Restore)
  // This ensures the device has the latest data from the shared account on startup
  await SyncManager.pullAll();

  await di.init();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  bool _hasShownSchemaWarning = false;

  Future<void> _refreshCloudData() async {
    await SyncManager.pullAll();
    _showSchemaWarningIfNeeded();
  }

  void _showSchemaWarningIfNeeded() {
    final health = SyncManager.syncHealthNotifier.value;
    if (health.missingTables.isEmpty) return;
    if (_hasShownSchemaWarning) return;
    final dialogContext = router.routerDelegate.navigatorKey.currentContext;
    if (dialogContext == null) return;
    _hasShownSchemaWarning = true;
    showDialog<void>(
      context: dialogContext,
      builder: (context) => AlertDialog(
        title: const Text('Cloud Setup Warning'),
        content: Text(
          'Missing Supabase tables: ${health.missingTables.join(', ')}.\nSome sync features are limited until these tables are created.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshCloudData();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Auto-refresh from cloud each time app opens/resumes
      _refreshCloudData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<ThemeBloc>(
            create: (context) => ThemeBloc()..add(LoadTheme())),
        BlocProvider<ProductBloc>(
            create: (context) => di.sl<ProductBloc>()..add(LoadProducts())),
        BlocProvider<ShopBloc>(
            create: (context) => di.sl<ShopBloc>()..add(LoadShopEvent())),
        BlocProvider<BillingBloc>(
            create: (context) =>
                BillingBloc(getProductByBarcodeUseCase: di.sl())),
        BlocProvider<PrinterBloc>(
            create: (context) => di.sl<PrinterBloc>()..add(InitPrinterEvent())),
      ],
      child: BlocBuilder<ThemeBloc, ThemeState>(
        builder: (context, state) {
          return MaterialApp.router(
            title: 'Bilby',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: state.themeMode,
            routerConfig: router,
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}
