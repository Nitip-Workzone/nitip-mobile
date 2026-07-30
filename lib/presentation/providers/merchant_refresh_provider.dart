import 'package:flutter_riverpod/flutter_riverpod.dart';

// Provider untuk memicu auto-refresh webview merchant
final merchantRefreshEventProvider = StateProvider<int>((ref) => 0);

// Provider untuk memicu navigasi webview merchant ke URL target
final merchantTargetUrlProvider = StateProvider<String?>((ref) => null);
