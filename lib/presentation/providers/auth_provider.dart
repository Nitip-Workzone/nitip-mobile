import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../data/network/api_client.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/models/user_model.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../core/config/app_config.dart';
import './kyc_provider.dart';
import './wallet_provider.dart';
import './notification_provider.dart';
import './activity_provider.dart';
import './location_provider.dart';

// Provider untuk ApiClient
final apiClientProvider = Provider((ref) => ApiClient());

// Provider untuk AuthRepository
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AuthRepositoryImpl(apiClient);
});

// State untuk Auth
class AuthState {
  final bool isLoading;
  final bool isRefreshing;
  final bool isInitialized;
  final String? error;
  final User? user;
  final bool isAuthenticated;
  final String? kycStatus; // 'none', 'pending', 'approved', 'rejected'
  final String? accessToken;

  AuthState({
    this.isLoading = false,
    this.isRefreshing = false,
    this.isInitialized = false,
    this.error,
    this.user,
    this.isAuthenticated = false,
    this.kycStatus = 'none',
    this.accessToken,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isRefreshing,
    bool? isInitialized,
    String? error,
    User? user,
    bool? isAuthenticated,
    String? kycStatus,
    String? accessToken,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isInitialized: isInitialized ?? this.isInitialized,
      error: error,
      user: user ?? this.user,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      kycStatus: kycStatus ?? this.kycStatus,
      accessToken: accessToken ?? this.accessToken,
    );
  }
}

// Notifier untuk Auth
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;
  final Ref _ref; // Tambahkan ref untuk akses provider lain
  final _storage = const FlutterSecureStorage();

  AuthNotifier(this._repository, this._ref) : super(AuthState()) {
    checkAuthStatus();
  }

  Future<void> checkAuthStatus() async {
    try {
      final config = await _repository.getPublicConfig();
      AppConfig.isKycRequired = config['kyc_verification_required'] ?? false;
      debugPrint('[CONFIG] Dynamic KYC verification requirement set to: ${AppConfig.isKycRequired}');
    } catch (e) {
      debugPrint('[CONFIG] Failed to load public config from backend: $e');
    }

    final token = await _storage.read(key: 'access_token');
    if (token == null) {
      state = state.copyWith(isInitialized: true, isAuthenticated: false);
      return;
    }

    try {
      final user = await _repository.getMe();
      
      // Fetch KYC Status
      String kycStatus = 'none';
      try {
        final kycData = await _ref.read(kycRepositoryProvider).getKycStatus();
        if (kycData != null) {
          kycStatus = kycData['status'] ?? 'none';
        }
      } catch (_) {}

      state = state.copyWith(
        isInitialized: true,
        user: user,
        isAuthenticated: true,
        kycStatus: kycStatus,
        accessToken: token,
      );
      requestNotificationPermission();
    } catch (e) {
      // Jika token tidak valid (401), hapus dari storage
      if (e.toString().contains('401') || e.toString().contains('Unauthorized')) {
        await logout();
      }
      state = state.copyWith(isInitialized: true, isAuthenticated: false);
    }
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // Get Device ID
      String deviceId = 'unknown';
      final deviceInfo = DeviceInfoPlugin();
      
      if (kIsWeb) {
        final webInfo = await deviceInfo.webBrowserInfo;
        deviceId = webInfo.userAgent ?? 'web_browser';
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceId = androidInfo.id; // Unique ID on Android
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceId = iosInfo.identifierForVendor ?? 'ios_device';
      }

      final result = await _repository.login(email, password, deviceId);
      final token = result['token'];
      final refreshToken = result['refresh_token'];
      final user = result['user'] as User;

      // Simpan token ke secure storage
      await _storage.write(key: 'access_token', value: token);
      await _storage.write(key: 'refresh_token', value: refreshToken);

      // Berikan jeda sedikit agar transisi tombol berputar di login page terlihat natural
      await Future.delayed(const Duration(milliseconds: 800));

      // Force refresh all data providers to use the new token *before* updating auth state to avoid navigation race condition
      _ref.invalidate(walletProvider);
      _ref.invalidate(notificationProvider);
      _ref.invalidate(activityProvider);

      state = state.copyWith(
        isLoading: false,
        user: user,
        isAuthenticated: true,
        accessToken: token,
      );
      
      // Request notification permission & sync FCM token after successful login
      requestNotificationPermission();

      // After login, check KYC status
      await checkAuthStatus();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    required String role,
    required String whatsappNumber,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // Get Device ID
      String deviceId = 'unknown';
      final deviceInfo = DeviceInfoPlugin();

      if (kIsWeb) {
        final webInfo = await deviceInfo.webBrowserInfo;
        deviceId = webInfo.userAgent ?? 'web_browser';
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceId = androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceId = iosInfo.identifierForVendor ?? 'ios_device';
      }

      await _repository.register(
        name: name,
        email: email,
        password: password,
        role: role,
        whatsappNumber: whatsappNumber,
        deviceId: deviceId,
      );
      // Setelah register, otomatis login
      await login(email, password);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void>? _refreshProfileFuture;

  Future<void> refreshProfile() async {
    // Guard: skip if already refreshing
    if (_refreshProfileFuture != null) return _refreshProfileFuture;

    _refreshProfileFuture = _performRefreshProfile();
    try {
      await _refreshProfileFuture;
    } finally {
      _refreshProfileFuture = null;
    }
  }

  Future<void> _performRefreshProfile() async {
    state = state.copyWith(isRefreshing: true);
    try {
      final user = await _repository.getMe();
      
      // Fetch KYC Status
      String kycStatus = 'none';
      try {
        final kycData = await _ref.read(kycRepositoryProvider).getKycStatus();
        if (kycData != null) {
          kycStatus = kycData['status'] ?? 'none';
        }
      } catch (_) {}

      state = state.copyWith(user: user, isAuthenticated: true, isRefreshing: false, kycStatus: kycStatus);
    } catch (e) {
      state = state.copyWith(isRefreshing: false);
      // Jika token tidak valid saat refresh, logout
      if (e.toString().contains('Unauthorized') || e.toString().contains('401')) {
        await logout();
      }
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');

    // Invalidate data providers on logout to clear their state
    _ref.invalidate(walletProvider);
    _ref.invalidate(notificationProvider);
    _ref.invalidate(activityProvider);

    state = AuthState(isInitialized: true);
  }

  Future<void> setupPin(String pin) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.setupPin(pin);
      // Refresh profile to update hasPin status
      await refreshProfile();
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString().replaceAll('Exception: ', ''));
      rethrow;
    }
  }

  Future<void> verifyPin(String pin) async {
    try {
      await _repository.verifyPin(pin);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> changePin(String oldPin, String newPin) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.changePin(oldPin, newPin);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString().replaceAll('Exception: ', ''));
      rethrow;
    }
  }

  Future<void> toggleAcceptingOrders(bool isAccepting) async {
    final previousUser = state.user;
    if (previousUser == null) return;

    // 1. Optimistic Update: Update local state immediately
    state = state.copyWith(user: previousUser.copyWith(isAcceptingOrders: isAccepting));

    try {
      // 2. Sync Location first if going online
      if (isAccepting) {
        final location = await _ref.read(userLocationProvider.notifier).locationService.getCurrentPosition();
        if (location != null) {
          await _repository.updateLocation(location.latitude, location.longitude);
        }
      }

      // 3. Network Sync: Update status on the server
      await _repository.updateAcceptingOrders(isAccepting);
    } catch (e) {
      // 4. Rollback: If server fails, revert to previous state
      state = state.copyWith(
        user: previousUser,
        error: e.toString().replaceAll('Exception: ', ''),
      );
      rethrow;
    }
  }

  Future<void> updateProfile({
    required String name,
    required String whatsappNumber,
    String? homeAddress,
    String? avatarPath,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.updateProfile(
        name: name,
        whatsappNumber: whatsappNumber,
        homeAddress: homeAddress,
        avatarPath: avatarPath,
      );
      await refreshProfile();
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
      rethrow;
    }
  }

  Future<void> requestNotificationPermission() async {
    try {
      final messaging = FirebaseMessaging.instance;

      // Cek status notifikasi saat ini via Firebase
      final currentSettings = await messaging.getNotificationSettings();
      debugPrint('[NOTIF] Current authorization status: ${currentSettings.authorizationStatus}');

      // Jika sudah authorized, langsung sync token
      if (currentSettings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('[NOTIF] Already authorized, syncing FCM token...');
        await syncFcmToken();
        return;
      }

      // Request permission menggunakan Firebase Messaging
      // Ini menangani POST_NOTIFICATIONS di Android 13+ secara native
      // dan APNS permission di iOS secara native
      final settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      debugPrint('[NOTIF] Permission request result: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        debugPrint('[NOTIF] Permission granted, syncing FCM token...');
        await syncFcmToken();
      } else {
        debugPrint('[NOTIF] Permission denied or not determined. Status: ${settings.authorizationStatus}');
      }
    } catch (e) {
      debugPrint('[NOTIF] Failed to request notification permission: $e');
    }
  }

  Future<void> syncFcmToken() async {
    try {
      final messaging = FirebaseMessaging.instance;
      final token = await messaging.getToken();
      if (token != null) {
        debugPrint('[FCM] Syncing token with server...');
        await _ref.read(apiClientProvider).dio.put('/users/fcm-token', data: {'fcm_token': token});
        debugPrint('[FCM] Token synced successfully');
      }
    } catch (e) {
      debugPrint('[FCM] Failed to sync token with server: $e');
    }
  }
}

// Provider untuk AuthNotifier
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return AuthNotifier(repository, ref);
});
