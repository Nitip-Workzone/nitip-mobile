import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/pool_realtime_service.dart';
import 'explore_orders_provider.dart';
import 'location_provider.dart';

/// Best practice anti-beban:
/// - WidgetsBindingObserver: pause SSE when app backgrounded (didChangeAppLifecycleState paused -> disconnect)
/// - Location throttle: only reconnect if moved >100m
/// - Exponential backoff + jitter max 30s
/// - Fallback polling 60s only when foreground + SSE disconnected
/// - Single subscription, broadcast stream
/// - autoDispose + onDispose cleanup to avoid leaks

final poolRealtimeServiceProvider = Provider<PoolRealtimeService>((ref) {
  final svc = PoolRealtimeService();
  ref.onDispose(() => svc.dispose());
  return svc;
});

final poolRealtimeProvider = StateNotifierProvider.autoDispose<PoolRealtimeNotifier, PoolRealtimeState>((ref) {
  final notifier = PoolRealtimeNotifier(ref);
  ref.onDispose(() => notifier.dispose());
  return notifier;
});

class PoolRealtimeState {
  final bool isLive;
  final bool isConnecting;
  final String? lastUpdate;
  final int reconnectAttempts;

  PoolRealtimeState({
    this.isLive = false,
    this.isConnecting = false,
    this.lastUpdate,
    this.reconnectAttempts = 0,
  });

  PoolRealtimeState copyWith({
    bool? isLive,
    bool? isConnecting,
    String? lastUpdate,
    int? reconnectAttempts,
  }) =>
      PoolRealtimeState(
        isLive: isLive ?? this.isLive,
        isConnecting: isConnecting ?? this.isConnecting,
        lastUpdate: lastUpdate ?? this.lastUpdate,
        reconnectAttempts: reconnectAttempts ?? this.reconnectAttempts,
      );
}

class PoolRealtimeNotifier extends StateNotifier<PoolRealtimeState> with WidgetsBindingObserver {
  final Ref _ref;
  StreamSubscription<PoolEvent>? _sub;
  Timer? _fallbackTimer;
  Timer? _reconnectTimer;
  double? _lastLat;
  double? _lastLng;
  bool _shouldRun = false;
  bool _disposed = false;

  PoolRealtimeNotifier(this._ref) : super(PoolRealtimeState()) {
    WidgetsBinding.instance.addObserver(this);
    _shouldRun = true;
    _init();
  }

  void _init() {
    // Listen to pool events
    final svc = _ref.read(poolRealtimeServiceProvider);
    _sub = svc.stream.listen((ev) {
      if (_disposed) return;

      if (ev.type == 'order_created') {
        _debouncedFetch();
        state = state.copyWith(
          isLive: true,
          lastUpdate: _formatNow(),
        );
      } else if (ev.type == 'order_claimed' ||
          ev.type == 'order_cancelled' ||
          ev.type == 'order_expired' ||
          ev.type == 'order_completed') {
        if (ev.orderId != null) {
          final cur = _ref.read(exploreOrdersProvider).availableOrders;
          final filtered = cur.where((o) => o.id != ev.orderId).toList();
          if (filtered.length != cur.length) {
            _ref.read(exploreOrdersProvider.notifier).state =
                _ref.read(exploreOrdersProvider.notifier).state.copyWith(availableOrders: filtered);
          }
        }
        state = state.copyWith(lastUpdate: _formatNow());
      } else if (ev.type == 'connected') {
        state = state.copyWith(isLive: true, isConnecting: false, reconnectAttempts: 0, lastUpdate: _formatNow());
        _debouncedFetch();
      }
    });

    // Initial connect
    _connectLoop();

    // Fallback polling every 60s only when not live & app in foreground & shouldRun
    _fallbackTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (!_shouldRun) return;
      if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) return;
      final svc = _ref.read(poolRealtimeServiceProvider);
      if (!svc.isRunning && !state.isLive) {
        _ref.read(exploreOrdersProvider.notifier).fetchAvailableOrders();
      }
    });
  }

  Timer? _debounceTimer;
  void _debouncedFetch() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 800), () {
      if (_disposed || !_shouldRun) return;
      _ref.read(exploreOrdersProvider.notifier).fetchAvailableOrders();
    });
  }

  Future<void> _connectLoop() async {
    if (_disposed || !_shouldRun) return;
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed &&
        WidgetsBinding.instance.lifecycleState != null) {
      return;
    }

    try {
      final locationService = _ref.read(userLocationProvider.notifier).locationService;
      final pos = await locationService.getCurrentPosition().timeout(const Duration(seconds: 8));
      if (pos == null) {
        _scheduleReconnect();
        return;
      }

      if (_lastLat != null && _lastLng != null) {
        final distM = _calculateDistance(_lastLat!, _lastLng!, pos.latitude, pos.longitude) * 1000;
        if (distM < 100) {
          final svc = _ref.read(poolRealtimeServiceProvider);
          if (svc.isRunning) return;
        }
      }

      _lastLat = pos.latitude;
      _lastLng = pos.longitude;

      state = state.copyWith(isConnecting: true);
      final svc = _ref.read(poolRealtimeServiceProvider);
      await svc.connect(lat: pos.latitude, lng: pos.longitude, radiusKm: 15);
      state = state.copyWith(isLive: false, isConnecting: false);
    } catch (_) {
      state = state.copyWith(isLive: false, isConnecting: false);
    }

    if (_disposed || !_shouldRun) return;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    if (!_shouldRun || _disposed) return;
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed &&
        WidgetsBinding.instance.lifecycleState != null) {
      return;
    }
    final attempt = state.reconnectAttempts;
    final jitter = (DateTime.now().millisecondsSinceEpoch % 500);
    final backoffMs = (1000 * (1 << (attempt < 5 ? attempt : 5)) + jitter).clamp(1000, 30000);
    _reconnectTimer = Timer(Duration(milliseconds: backoffMs), () {
      if (_disposed || !_shouldRun) return;
      state = state.copyWith(reconnectAttempts: attempt + 1);
      _connectLoop();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed) return;
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // Best practice: disconnect when backgrounded to save battery & radio
      _ref.read(poolRealtimeServiceProvider).disconnect();
      this.state = this.state.copyWith(isLive: false, isConnecting: false);
    } else if (state == AppLifecycleState.resumed) {
      // Reconnect when foregrounded
      if (_shouldRun) {
        _connectLoop();
      }
    }
  }

  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const double p = 0.017453292519943295;
    const double earth = 6371;
    final double dLat = (lat2 - lat1) * p;
    final double dLng = (lng2 - lng1) * p;
    final double lat1R = lat1 * p;
    final double lat2R = lat2 * p;
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.sin(dLng / 2) * math.sin(dLng / 2) * math.cos(lat1R) * math.cos(lat2R);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earth * c;
  }

  String _formatNow() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}:${now.second.toString().padLeft(2,'0')}';
  }

  void stop() {
    _shouldRun = false;
    _fallbackTimer?.cancel();
    _reconnectTimer?.cancel();
    _debounceTimer?.cancel();
    _ref.read(poolRealtimeServiceProvider).disconnect();
    state = state.copyWith(isLive: false, isConnecting: false);
  }

  @override
  void dispose() {
    _disposed = true;
    _shouldRun = false;
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    _fallbackTimer?.cancel();
    _reconnectTimer?.cancel();
    _debounceTimer?.cancel();
    try {
      _ref.read(poolRealtimeServiceProvider).disconnect();
    } catch (_) {}
    super.dispose();
  }
}
