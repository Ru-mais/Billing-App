import 'package:go_router/go_router.dart';
import '../../features/billing/presentation/pages/home_page.dart';
import '../../features/product/presentation/pages/product_list_page.dart';
import '../../features/product/presentation/pages/add_product_page.dart';
import '../../features/product/presentation/pages/edit_product_page.dart';
import '../../features/shop/presentation/pages/shop_details_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/billing/presentation/pages/scanner_page.dart';
import '../../features/billing/presentation/pages/checkout_page.dart';
import '../../features/product/domain/entities/product.dart';
import '../../features/reports/presentation/pages/daily_report_page.dart';
import '../../features/reports/presentation/pages/monthly_report_page.dart';
import '../../features/reports/presentation/pages/product_report_page.dart';
import '../../features/reports/presentation/pages/add_purchase_order_page.dart';
import '../../features/reports/presentation/pages/daily_purchase_report_page.dart';
import '../../features/reports/presentation/pages/monthly_purchase_report_page.dart';

final router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomePage(),
      routes: [
        GoRoute(
          path: 'scanner',
          builder: (context, state) => const ScannerPage(),
        ),
        GoRoute(
          path: 'checkout',
          builder: (context, state) => const CheckoutPage(),
        ),
      ],
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsPage(),
    ),
    GoRoute(
      path: '/daily_report',
      builder: (context, state) => const DailyReportPage(),
    ),
    GoRoute(
      path: '/monthly_report',
      builder: (context, state) => const MonthlyReportPage(),
    ),
    GoRoute(
      path: '/product_report',
      builder: (context, state) => const ProductReportPage(),
    ),
    GoRoute(
      path: '/add_purchase_order',
      builder: (context, state) => const AddPurchaseOrderPage(),
    ),
    GoRoute(
      path: '/daily_purchase_report',
      builder: (context, state) => const DailyPurchaseReportPage(),
    ),
    GoRoute(
      path: '/monthly_purchase_report',
      builder: (context, state) => const MonthlyPurchaseReportPage(),
    ),
    GoRoute(
      path: '/products',
      builder: (context, state) => const ProductListPage(),
      routes: [
        GoRoute(
          path: 'add',
          builder: (context, state) => const AddProductPage(),
        ),
        GoRoute(
          path: 'edit/:id',
          builder: (context, state) {
            final product = state.extra as Product?;
            if (product == null) {
              // If we land here without extra (e.g. deep link), go back to products for now.
              return const ProductListPage();
            }
            return EditProductPage(product: product);
          },
        ),
      ],
    ),
    GoRoute(
      path: '/shop',
      builder: (context, state) => const ShopDetailsPage(),
    ),
  ],
);
