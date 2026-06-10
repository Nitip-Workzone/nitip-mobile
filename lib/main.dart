import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/responsive.dart';

import 'presentation/pages/welcome/welcome_page.dart';
import 'presentation/pages/auth/login_page.dart';
import 'presentation/pages/auth/register_page.dart';
import 'presentation/pages/dashboard/dashboard_page.dart';
// import 'presentation/pages/kyc/kyc_intro_page.dart';
// import 'presentation/pages/kyc/kyc_verified_benefits_page.dart';
import 'presentation/pages/notification/notification_page.dart';
import 'presentation/pages/info/faq_page.dart';
import 'presentation/pages/wallet/transaction_history_page.dart';
import 'presentation/pages/wallet/withdraw_page.dart';
// import 'presentation/pages/orders/titip_beli_page.dart';
// import 'presentation/pages/orders/titip_kirim_page.dart';
import 'presentation/pages/orders/explore_orders_page.dart';
import 'presentation/pages/orders/order_detail_page.dart';
import 'presentation/pages/dashboard/tabs/orders_tab.dart';

import 'presentation/providers/auth_provider.dart';

class AuthStatus {
  final bool isInitialized;
  final bool isAuthenticated;
  AuthStatus({required this.isInitialized, required this.isAuthenticated});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthStatus &&
          runtimeType == other.runtimeType &&
          isInitialized == other.isInitialized &&
          isAuthenticated == other.isAuthenticated;

  @override
  int get hashCode => isInitialized.hashCode ^ isAuthenticated.hashCode;
}

final authStatusProvider = Provider<AuthStatus>((ref) {
  final authState = ref.watch(authProvider);
  return AuthStatus(
    isInitialized: authState.isInitialized,
    isAuthenticated: authState.isAuthenticated,
  );
});

final routerProvider = Provider<GoRouter>((ref) {
  final authStatus = ref.watch(authStatusProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      // Jika belum inisialisasi, jangan redirect dulu
      if (!authStatus.isInitialized) return null;

      final isAuth = authStatus.isAuthenticated;
      final isLoggingIn = state.matchedLocation == '/login' || 
                          state.matchedLocation == '/register' ||
                          state.matchedLocation == '/';

      // Jika sudah login tapi masih di halaman auth, lempar ke dashboard
      if (isAuth && isLoggingIn) return '/dashboard';
      
      // Jika belum login dan mencoba akses dashboard, lempar ke welcome
      if (!isAuth && state.matchedLocation == '/dashboard') return '/';

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const WelcomePage(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardPage(),
      ),
      // GoRoute(
      //   path: '/kyc-intro',
      //   builder: (context, state) => const KycIntroPage(),
      // ),
      // GoRoute(
      //   path: '/kyc-benefits',
      //   builder: (context, state) => const KycVerifiedBenefitsPage(),
      // ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationPage(),
      ),
      GoRoute(
        path: '/faq',
        builder: (context, state) => const FaqPage(),
      ),
      GoRoute(
        path: '/wallet/history',
        builder: (context, state) => const TransactionHistoryPage(),
      ),
      GoRoute(
        path: '/wallet/withdraw',
        builder: (context, state) => const WithdrawPage(),
      ),
      // GoRoute(
      //   path: '/orders/titip-beli',
      //   builder: (context, state) => const TitipBeliPage(),
      // ),
      // GoRoute(
      //   path: '/orders/titip-kirim',
      //   builder: (context, state) => const TitipKirimPage(),
      // ),
      GoRoute(
        path: '/orders/explore',
        builder: (context, state) => const ExploreOrdersPage(),
      ),
      GoRoute(
        path: '/orders/detail/:id',
        builder: (context, state) => OrderDetailPage(orderId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/orders/active',
        builder: (context, state) => const OrdersTab(),
      ),
    ],

  );
});

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  
  
  runApp(
    const ProviderScope(
      child: NitipApp(),
    ),
  );
}

class NitipApp extends ConsumerWidget {
  const NitipApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final authState = ref.watch(authProvider);

    // Tampilkan Splash sederhana jika belum inisialisasi
    if (!authState.isInitialized) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return MaterialApp.router(
      title: 'Nitip Mobile',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
      builder: (context, child) {
        return MaxWidthWrapper(
          maxWidth: 600,
          child: child!,
        );
      },
    );

  }
}
