import 'package:flutter/foundation.dart';

/// Lightweight no-op logger — debug heavy logger removed 2026-07-28 for perf & security.
/// Keeps API compatible so existing call sites don't break, but does nothing in prod.
/// In debug mode, it forwards to debugPrint only if needed.
class WebViewDebugLogger {
  // ignore: avoid_empty_blocks
  static void log(String msg) {
    if (kDebugMode) {
      // silent by default — enable only when debugging WebView
      // debugPrint('[WEBVIEW_DEBUG] $msg');
    }
  }

  // ignore: avoid_empty_blocks
  static void clear() {}

  static Stream<List<String>> get stream => const Stream.empty();
  static List<String> get logs => const [];
  static String get allLogs => '';
}
