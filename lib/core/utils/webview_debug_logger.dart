import 'dart:async';
import 'package:flutter/foundation.dart';

/// Simple in-memory logger for WebView debug overlay visible on HP tanpa adb
class WebViewDebugLogger {
  static final List<String> _logs = [];
  static final StreamController<List<String>> _stream = StreamController.broadcast();
  static Stream<List<String>> get stream => _stream.stream;
  static List<String> get logs => List.unmodifiable(_logs);

  static void log(String msg) {
    final time = DateTime.now().toIso8601String().substring(11, 19);
    final line = '[$time] $msg';
    _logs.add(line);
    if (_logs.length > 200) _logs.removeAt(0);
    _stream.add(List.unmodifiable(_logs));
    debugPrint('[WEBVIEW_DEBUG] $msg');
  }

  static void clear() {
    _logs.clear();
    _stream.add([]);
  }

  static String get allLogs => _logs.join('\n');
}
