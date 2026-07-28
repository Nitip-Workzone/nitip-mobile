import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

/// Centralized crash & analytics service (best practice)
/// - Logs WebView errors (500, etc) to Crashlytics + Analytics
/// - No extra dep bloat: uses existing firebase_core
class CrashService {
  static final FirebaseCrashlytics _crash = FirebaseCrashlytics.instance;
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// Call in main() after Firebase.initializeApp()
  static Future<void> init() async {
    // Pass all uncaught Flutter errors to Crashlytics
    FlutterError.onError = (details) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  /// Log non-fatal error with context
  static Future<void> logError(
    dynamic error,
    StackTrace? stack, {
    String reason = 'unknown',
    Map<String, dynamic>? extras,
  }) async {
    try {
      if (extras != null) {
        for (final e in extras.entries) {
          await _crash.setCustomKey(e.key, e.value.toString());
        }
      }
      await _crash.recordError(error, stack, reason: reason, fatal: false);
      await _analytics.logEvent(
        name: 'app_error',
        parameters: <String, Object>{
          'reason': reason,
          'error': error.toString().substring(0, error.toString().length > 500 ? 500 : error.toString().length),
          ...?extras?.map((k, v) => MapEntry(k, v.toString() as Object)),
        },
      );
      debugPrint('[CRASH] $reason: $error extras=$extras');
    } catch (_) {
      // ignore logging failure
    }
  }

  /// Log WebView error specifically (500, etc)
  static Future<void> logWebViewError({
    required String url,
    required int? errorCode,
    required String? description,
    String? failingUrl,
  }) async {
    await logError(
      'WebView Error $errorCode: $description at $url',
      null,
      reason: 'webview_error_${errorCode ?? 0}',
      extras: {
        'url': url,
        'errorCode': errorCode?.toString() ?? 'unknown',
        'description': description ?? '',
        'failingUrl': failingUrl ?? url,
      },
    );
  }

  /// Log pool realtime event for analytics
  static Future<void> logPoolEvent(String type, {Map<String, Object>? data}) async {
    try {
      await _analytics.logEvent(name: 'pool_$type', parameters: data);
    } catch (_) {}
  }

  static Future<void> setUser(String userId, {String? email, String? role}) async {
    try {
      await _crash.setUserIdentifier(userId);
      if (email != null) await _crash.setCustomKey('email', email);
      if (role != null) await _crash.setCustomKey('role', role);
      await _analytics.setUserId(id: userId);
      if (role != null) await _analytics.setUserProperty(name: 'role', value: role);
    } catch (_) {}
  }
}
