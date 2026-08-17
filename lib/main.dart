import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/responsive.dart';
import 'core/services/crash_service.dart';

import 'presentation/pages/welcome/welcome_page.dart';
import 'presentation/pages/auth/login_page.dart';
import 'presentation/pages/auth/register_page.dart';
import 'presentation/pages/dashboard/dashboard_page.dart';
import 'presentation/pages/kyc/kyc_intro_page.dart';
import 'presentation/pages/kyc/kyc_status_page.dart';
import 'presentation/pages/kyc/kyc_verified_benefits_page.dart';
import 'presentation/pages/notification/notification_page.dart';
import 'presentation/pages/info/faq_page.dart';
import 'presentation/pages/wallet/transaction_history_page.dart';
import 'presentation/pages/wallet/withdraw_page.dart';
import 'presentation/pages/orders/titip_beli_page.dart';
import 'presentation/pages/orders/titip_kirim_page.dart';
import 'presentation/pages/orders/explore_orders_page.dart';
import 'presentation/pages/orders/order_detail_page.dart';
import 'presentation/pages/dashboard/tabs/orders_tab.dart';
import 'presentation/pages/reviews/submit_review_page.dart';
import 'presentation/pages/support/support_ticket_list_page.dart';
import 'presentation/pages/support/support_ticket_detail_page.dart';
import 'presentation/pages/support/support_new_ticket_page.dart';

import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/wallet_provider.dart';
import 'presentation/providers/notification_provider.dart';
import 'core/config/app_config.dart';
import 'presentation/providers/merchant_refresh_provider.dart';

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
      
      // Jika belum login dan mencoba akses route terlindungi (termasuk merchant via /dashboard), lempar ke welcome
      // Sebelumnya hanya cek '/dashboard' exact, sekarang semua route kecuali public harus ke '/'
      const publicRoutes = ['/', '/login', '/register', '/kyc-intro', '/kyc-benefits'];
      final isPublic = publicRoutes.contains(state.matchedLocation) || state.matchedLocation.startsWith('/login') || state.matchedLocation.startsWith('/register');
      if (!isAuth && !isPublic) {
        return '/';
      }

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
      GoRoute(
        path: '/kyc-intro',
        builder: (context, state) => const KycIntroPage(),
      ),
      GoRoute(
        path: '/kyc-status',
        builder: (context, state) => const KycStatusPage(),
      ),
      GoRoute(
      path: '/kyc-benefits',
      builder: (context, state) => const KycVerifiedBenefitsPage(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationPage(),
      ),
      GoRoute(
        path: '/faq',
        builder: (context, state) => const FaqPage(),
      ),
      GoRoute(
        path: '/support',
        builder: (context, state) {
          // lazy import to avoid circular
          return const SupportTicketListPage();
        },
      ),
      GoRoute(
        path: '/support/new',
        builder: (context, state) => SupportNewTicketPage(orderId: state.uri.queryParameters['order_id']),
      ),
      GoRoute(
        path: '/support/:id',
        builder: (context, state) => SupportTicketDetailPage(ticketId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/wallet/history',
        builder: (context, state) => const TransactionHistoryPage(),
      ),
      GoRoute(
        path: '/wallet/withdraw',
        builder: (context, state) => const WithdrawPage(),
      ),
      GoRoute(
      path: '/orders/titip-beli',
      builder: (context, state) => const TitipBeliPage(),
      ),
      GoRoute(
      path: '/orders/titip-kirim',
      builder: (context, state) => const TitipKirimPage(),
      ),
      GoRoute(
        path: '/orders/explore',
        builder: (context, state) => const ExploreOrdersPage(),
      ),
      GoRoute(
        path: '/orders/detail/:id',
        builder: (context, state) => OrderDetailPage(orderId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/orders/:id/review',
        builder: (context, state) => SubmitReviewPage(
          orderId: state.pathParameters['id']!,
          runnerName: state.uri.queryParameters['runnerName'],
        ),
      ),
      GoRoute(
        path: '/orders/active',
        builder: (context, state) => const OrdersTab(),
      ),
    ],

  );
});

// Top-level function to handle background messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('[FCM-BACKGROUND] Message received: ${message.data}');
}

// Local notification plugin instance
final FlutterLocalNotificationsPlugin _localNotificationsPlugin = FlutterLocalNotificationsPlugin();

/// Initialize local notifications channel and plugin
Future<void> _initLocalNotifications() async {
  // Android channel
  const androidChannel = AndroidNotificationChannel(
    'nitip_high_importance', // id
    'Nitip Notifications',   // name
    description: 'Notifikasi penting dari Nitip',
    importance: Importance.high,
    playSound: true,
  );

  // Create the Android notification channel
  final androidPlugin = _localNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  if (androidPlugin != null) {
    await androidPlugin.createNotificationChannel(androidChannel);
  }

  // Initialize plugin
  const initSettings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/launcher_icon'),
    iOS: DarwinInitializationSettings(
      requestAlertPermission: false, // Handled by FirebaseMessaging
      requestBadgePermission: false,
      requestSoundPermission: false,
    ),
  );

  await _localNotificationsPlugin.initialize(
    initSettings,
    onDidReceiveNotificationResponse: (details) {
      debugPrint('[NOTIF-LOCAL] User tapped notification: ${details.payload}');
      // Navigation can be handled here based on payload
    },
  );
}

/// Display a local notification (used when app is in foreground)
void _showLocalNotification(RemoteMessage message) {
  final notification = message.notification;
  if (notification == null) return;

  final androidDetails = AndroidNotificationDetails(
    'nitip_high_importance',
    'Nitip Notifications',
    channelDescription: 'Notifikasi penting dari Nitip',
    importance: Importance.high,
    priority: Priority.high,
    playSound: true,
    icon: '@mipmap/launcher_icon',
  );

  final details = NotificationDetails(
    android: androidDetails,
    iOS: const DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
  );

  _localNotificationsPlugin.show(
    notification.hashCode,
    notification.title,
    notification.body,
    details,
    payload: message.data.toString(),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  
  // Register background message handler BEFORE Firebase init
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  try {
    await Firebase.initializeApp();

    // Init Crashlytics & Analytics (best practice: no extra bloat)
    try {
      await CrashService.init();
      debugPrint('[CRASH] Crashlytics initialized');
    } catch (e) {
      debugPrint('[CRASH] init failed: $e');
    }

    // Initialize local notifications for foreground display
    await _initLocalNotifications();

    final messaging = FirebaseMessaging.instance;
    
    // Foreground presentation options (iOS) — we handle display ourselves via local notifications
    await messaging.setForegroundNotificationPresentationOptions(
      alert: false,  // We use flutter_local_notifications instead
      badge: true,
      sound: true,
    );

    final token = await messaging.getToken();
    debugPrint('[FCM] Device Token: $token');
  } catch (e) {
    debugPrint('[FCM] Initialization failed: $e');
  }

  final container = ProviderContainer();

  void handleNotificationTap(RemoteMessage message, ProviderContainer container) {
    final data = message.data;
    final orderId = data['order_id'];
    if (orderId == null || orderId.toString().isEmpty) return;

    final authState = container.read(authProvider);
    final isMerchant = authState.user?.isMerchant ?? false;

    if (isMerchant || data['type'] == 'merchant_order') {
      final targetUrl = '${AppConfig.webBaseUrl}/merchant/orders';
      container.read(merchantTargetUrlProvider.notifier).state = targetUrl;
    } else {
      final router = container.read(routerProvider);
      router.push('/orders/detail/$orderId');
    }
  }

  // 1. FOREGROUND: Listen to FCM messages when app is in foreground
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    debugPrint('[FCM-FOREGROUND] Title: ${message.notification?.title}');
    debugPrint('[FCM-FOREGROUND] Body: ${message.notification?.body}');
    debugPrint('[FCM-FOREGROUND] Data: ${message.data}');

    // Show local notification since app is in foreground
    _showLocalNotification(message);

    // Handle specific data types
    if (message.data['type'] == 'wallet_update') {
      debugPrint('[FCM-FOREGROUND] Triggering wallet balance refresh...');
      container.read(walletProvider.notifier).fetchBalance(force: true);
    } else if (message.data['type'] == 'merchant_order') {
      debugPrint('[FCM-FOREGROUND] Triggering merchant webview auto-refresh...');
      container.read(merchantRefreshEventProvider.notifier).state++;
    }
    
    // Always refresh notification count
    container.read(notificationProvider.notifier).fetchUnreadCount(force: true);
  });

  // 2. BACKGROUND (app open but backgrounded): User taps notification
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    debugPrint('[FCM-OPENED] User tapped notification: ${message.data}');
    container.read(notificationProvider.notifier).fetchNotifications();
    handleNotificationTap(message, container);
  });

  // 3. TERMINATED: App opened from terminated state via notification
  final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) {
    debugPrint('[FCM-INITIAL] App opened from terminated via notification: ${initialMessage.data}');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      container.read(notificationProvider.notifier).fetchNotifications();
      Future.doWhile(() async {
        await Future.delayed(const Duration(milliseconds: 200));
        return !container.read(authProvider).isInitialized;
      }).then((_) {
        if (container.read(authProvider).isAuthenticated) {
          handleNotificationTap(initialMessage, container);
        }
      });
    });
  }
  
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const NitipApp(),
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
