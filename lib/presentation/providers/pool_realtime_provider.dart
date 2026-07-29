import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/pool_realtime_service.dart';
import 'activity_provider.dart';
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

// Keep alive – do NOT autoDispose, so SSE stays live when navigating to detail and back.
// This prevents miss of order_created events and removes need for pull-to-refresh.
final poolRealtimeProvider = StateNotifierProvider<PoolRealtimeNotifier, PoolRealtimeState>((ref) {
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
    // Listen to pool events – low burden: only fetch list when truly new order
    final svc = _ref.read(poolRealtimeServiceProvider);
    _sub = svc.stream.listen((ev) {
      if (_disposed) return;

      if (ev.type == 'order_created') {
        // Realtime path: try single fetch + immediate list fetch (no location sync)
        if (ev.orderId != null) {
          _fetchSingleOrder(ev.orderId!);
        }
        _immediateFetch();
        // Also debounced to catch case single fails
        _debouncedFetch(force: true);
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
          } else if (ev.type == 'order_claimed' || ev.type == 'order_cancelled') {
            // still trigger fetch if not in list (maybe race where list stale)
            _debouncedFetch();
          }
        }
        state = state.copyWith(lastUpdate: _formatNow());
      } else if (ev.type == 'connected') {
        state = state.copyWith(isLive: true, isConnecting: false, reconnectAttempts: 0, lastUpdate: _formatNow());
        _immediateFetch();
      } else if (ev.type == 'order_status' && ev.data != null && (ev.data!['status'] == 'cancelled' || ev.data!['status'] == 'claimed')) {
        // From order:{id} channel too – also remove from pool
        final cur = _ref.read(exploreOrdersProvider).availableOrders;
        final filtered = cur.where((o) => o.id != ev.orderId).toList();
        if (filtered.length != cur.length) {
          _ref.read(exploreOrdersProvider.notifier).state =
              _ref.read(exploreOrdersProvider.notifier).state.copyWith(availableOrders: filtered);
        }
        _debouncedFetch();
      }
    });

    // Initial connect
    _connectLoop();

    // Low burden polling: when not live 15s, when live 30s (still catches miss)
    _fallbackTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!_shouldRun) return;
      if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) return;
      final svc = _ref.read(poolRealtimeServiceProvider);
      if (!svc.isRunning && !state.isLive) {
        final jitter = (DateTime.now().millisecondsSinceEpoch % 2000);
        Future.delayed(Duration(milliseconds: jitter), () {
          if (_disposed || !_shouldRun) return;
          _ref.read(exploreOrdersProvider.notifier).fetchAvailableOrders(syncLocation: false);
        });
      } else if (state.isLive) {
        // When live, refresh every 30s as safety net for cell edge miss
        if (DateTime.now().millisecondsSinceEpoch % 30000 < 15000) return;
        _ref.read(exploreOrdersProvider.notifier).fetchAvailableOrders(syncLocation: false);
      }
    });
  }

  Timer? _debounceTimer;
  void _debouncedFetch({bool force = false}) {
    _debounceTimer?.cancel();
    final delayMs = force ? 100 : 300;
    _debounceTimer = Timer(Duration(milliseconds: delayMs), () {
      if (_disposed || !_shouldRun) return;
      _ref.read(exploreOrdersProvider.notifier).fetchAvailableOrders(syncLocation: false, force: true);
    });
  }

  void _immediateFetch() {
    _debounceTimer?.cancel();
    if (_disposed || !_shouldRun) return;
    _ref.read(exploreOrdersProvider.notifier).fetchAvailableOrders(syncLocation: false, force: true);
  }

  Future<void> _fetchSingleOrder(String orderId) async {
    try {
      final repo = _ref.read(orderRepositoryProvider);
      final order = await repo.getOrderById(orderId);
      final cur = _ref.read(exploreOrdersProvider).availableOrders;
      if (cur.any((o) => o.id == orderId)) return;
      const allowed = {'pending','merchant_accepted','accepted','cooking','ready'};
      if (!allowed.contains(order.status.toLowerCase())) return;
      _ref.read(exploreOrdersProvider.notifier).state =
          _ref.read(exploreOrdersProvider.notifier).state.copyWith(availableOrders: [order, ...cur]);
    } catch (_) {
      // If 403 (not participant) or fail, fallback to list fetch – low burden, ensures pool still updates
      _debouncedFetch();
    }
  }

  Future<void> _connectLoop({bool forceGlobalFirst = true}) async {
    if (_disposed || !_shouldRun) return;
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed &&
        WidgetsBinding.instance.lifecycleState != null) {
      return;
    }

    // Step 1: Instant global connect for fast Live badge – no GPS blocking
    if (forceGlobalFirst && _lastLat == null) {
      state = state.copyWith(isConnecting: true);
      final svc = _ref.read(poolRealtimeServiceProvider);
      try {
        // Connect without awaiting forever – will be terminated by provider stream when live
        // We start connect and immediately consider isLive optimistic after 300ms if stream not failed
        final connectFuture = svc.connect(lat: 0, lng: 0, radiusKm: 20);
        // Wait a bit for connected event, but also allow Live optimistic
        await Future.any([
          connectFuture,
          Future.delayed(const Duration(milliseconds: 400)),
        ]);
        // If service says running, mark Live immediately – don't wait for GPS
        if (svc.isRunning) {
          state = state.copyWith(isLive: true, isConnecting: false, reconnectAttempts: 0, lastUpdate: _formatNow());
        } else {
          state = state.copyWith(isConnecting: false);
        }
        // Don't return – continue to try real GPS in background for better cells
      } catch (_) {
        state = state.copyWith(isConnecting: false);
      }
      if (_disposed || !_shouldRun) return;
    }

    // Step 2: Try get real GPS to upgrade cell (background, non-blocking Live)
    try {
      final locationService = _ref.read(userLocationProvider.notifier).locationService;
      final pos = await locationService.getCurrentPosition().timeout(const Duration(seconds: 5));
      if (pos == null) {
        // No GPS – keep global connection alive (stay Live), retry later
        if (!_ref.read(poolRealtimeServiceProvider).isRunning) {
          _scheduleReconnect();
        }
        return;
      }

      if (_lastLat != null && _lastLng != null) {
        final distM = _calculateDistance(_lastLat!, _lastLng!, pos.latitude, pos.longitude) * 1000;
        final svc = _ref.read(poolRealtimeServiceProvider);
        if (distM < 50 && svc.isRunning) return; // already connected with nearby location
      }

      _lastLat = pos.latitude;
      _lastLng = pos.longitude;

      // Upgrade to precise cell without losing Live
      final svc = _ref.read(poolRealtimeServiceProvider);
      if (svc.isRunning) {
        // Already have global live – disconnect and reconnect with real loc, but keep Live badge
        svc.disconnect();
        await Future.delayed(const Duration(milliseconds: 250));
      }
      state = state.copyWith(isConnecting: true);
      await svc.connect(lat: pos.latitude, lng: pos.longitude, radiusKm: 20);
      state = state.copyWith(isLive: true, isConnecting: false, reconnectAttempts: 0, lastUpdate: _formatNow());
    } catch (_) {
      // GPS failed – keep existing Live (global) if any, otherwise Poll
      final svc = _ref.read(poolRealtimeServiceProvider);
      if (svc.isRunning) {
        state = state.copyWith(isLive: true, isConnecting: false);
      } else {
        state = state.copyWith(isLive: false, isConnecting: false);
        _scheduleReconnect();
      }
    }
  }

  // Public method to force refresh + reconnect when user enters Kelola Tugas page
  void forceRefresh() {
    _immediateFetch();
    if (!_ref.read(poolRealtimeServiceProvider).isRunning) {
      _lastLat = null;
      _connectLoop(forceGlobalFirst: true);
    }
  }

  // Called when order cancelled externally – optimistic remove without fetch
  void removeOrderLocally(String orderId) {
    final cur = _ref.read(exploreOrdersProvider).availableOrders;
    final filtered = cur.where((o) => o.id != orderId).toList();
    if (filtered.length != cur.length) {
      _ref.read(exploreOrdersProvider.notifier).state =
          _ref.read(exploreOrdersProvider.notifier).state.copyWith(availableOrders: filtered);
    }
    // Force fetch to sync
    _immediateFetch();
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
