import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/responsive.dart';

import 'presentation/pages/welcome/welcome_page.dart';
import 'presentation/pages/auth/login_page.dart';
import 'presentation/pages/auth/register_page.dart';
import 'presentation/pages/dashboard/dashboard_page.dart';
import 'presentation/pages/kyc/kyc_intro_page.dart';
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

import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/wallet_provider.dart';
import 'presentation/providers/notification_provider.dart';

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
      GoRoute(
        path: '/kyc-intro',
        builder: (context, state) => const KycIntroPage(),
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
    }
    
    // Always refresh notification count
    container.read(notificationProvider.notifier).fetchUnreadCount(force: true);
  });

  // 2. BACKGROUND (app open but backgrounded): User taps notification
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    debugPrint('[FCM-OPENED] User tapped notification: ${message.data}');
    // Refresh notification list
    container.read(notificationProvider.notifier).fetchNotifications();
    // Navigation can be handled here (e.g., go to order detail)
  });

  // 3. TERMINATED: App opened from terminated state via notification
  final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) {
    debugPrint('[FCM-INITIAL] App opened from terminated via notification: ${initialMessage.data}');
    // Delayed navigation after app is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      container.read(notificationProvider.notifier).fetchNotifications();
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
