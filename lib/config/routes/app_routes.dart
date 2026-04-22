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
import '../../features/settings/presentation/pages/supplier_ledger_page.dart';


import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/auth/presentation/pages/sign_in_page.dart';

import 'dart:async';

class SupabaseAuthRepository extends ChangeNotifier {
  StreamSubscription? _profileSubscription;

  SupabaseAuthRepository() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session != null) {
        _listenToBanStatus(session.user.id);
      } else {
        _profileSubscription?.cancel();
        _profileSubscription = null;
      }
      notifyListeners();
    });
  }

  void _listenToBanStatus(String userId) {
    _profileSubscription?.cancel();
    _profileSubscription = Supabase.instance.client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .listen((List<Map<String, dynamic>> data) {
      if (data.isNotEmpty) {
        bool isBanned = data.first['is_banned'] ?? false;
        if (isBanned) {
          // Force logout immediately if banned
          Supabase.instance.client.auth.signOut();
        }
      }
    });
  }
}

final authRepository = SupabaseAuthRepository();

final router = GoRouter(
  initialLocation: '/',
  refreshListenable: authRepository,
  redirect: (context, state) async {
    final session = Supabase.instance.client.auth.currentSession;
    final isLoggingIn = state.uri.toString() == '/login';

    if (session == null) {
      return isLoggingIn ? null : '/login';
    }

    // Optional: You could add the is_paid check here for total security,
    // but for now, we'll keep it simple to fix the navigation bug.
    
    if (isLoggingIn) {
      return '/';
    }

    return null;
  },
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const SignInPage(),
    ),
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
      path: '/supplier_ledger',
      builder: (context, state) => const SupplierLedgerPage(),
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
