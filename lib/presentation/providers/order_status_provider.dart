import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/order_status_service.dart';
import 'activity_provider.dart';

/// Low-burden order status realtime provider
/// - Hanya aktif saat status intermediate (pending, merchant_accepted, cooking, ready, accepted, purchasing, delivering)
/// - Auto disconnect on background / dispose / terminal status
/// - Smart fallback polling 15s + jitter hanya foreground + intermediate, PK getByID (murah)
/// - Patch activityProvider via patchOrderStatus agar global state sync tanpa extra fetch

final orderStatusServiceProvider = Provider<OrderStatusService>((ref) {
  final svc = OrderStatusService();
  ref.onDispose(() => svc.dispose());
  return svc;
});

class OrderStatusState {
  final String status;
  final bool isLive;
  final bool isConnecting;
  final bool hasFetched;
  final String? error;
  final int reconnectAttempts;
  final String? orderId;

  OrderStatusState({
    this.status = '',
    this.isLive = false,
    this.isConnecting = false,
    this.hasFetched = false,
    this.error,
    this.reconnectAttempts = 0,
    this.orderId,
  });

  bool get isTerminal =>
      status == 'completed' ||
      status == 'cancelled' ||
      status == 'expired' ||
      status == 'disputed';

  bool get isIntermediate {
    if (status.isEmpty) return true; // assume intermediate if unknown yet
    const intermediate = {
      'pending',
      'merchant_accepted',
      'accepted',
      'cooking',
      'ready',
      'purchasing',
      'delivering',
      'on_progress',
    };
    return intermediate.contains(status);
  }

  OrderStatusState copyWith({
    String? status,
    bool? isLive,
    bool? isConnecting,
    bool? hasFetched,
    String? error,
    int? reconnectAttempts,
    String? orderId,
  }) =>
      OrderStatusState(
        status: status ?? this.status,
        isLive: isLive ?? this.isLive,
        isConnecting: isConnecting ?? this.isConnecting,
        hasFetched: hasFetched ?? this.hasFetched,
        error: error,
        reconnectAttempts: reconnectAttempts ?? this.reconnectAttempts,
        orderId: orderId ?? this.orderId,
      );
}

class OrderStatusNotifier extends StateNotifier<OrderStatusState>
    with WidgetsBindingObserver {
  final Ref _ref;
  final String orderId;
  StreamSubscription<OrderStatusEvent>? _sub;
  Timer? _reconnectTimer;
  Timer? _debounceFetchTimer;
  bool _shouldRun = true;
  bool _disposed = false;

  OrderStatusNotifier(this._ref, this.orderId)
      : super(OrderStatusState(orderId: orderId)) {
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  void _init() {
    // Listen to status events
    final svc = _ref.read(orderStatusServiceProvider);
    _sub = svc.stream.listen((ev) {
      if (_disposed || !_shouldRun) return;
      if (ev.orderId != null && ev.orderId != orderId) return; // ignore other orders if any

      if (ev.status.isEmpty) return;

      final prevStatus = state.status;
      final newStatus = ev.status;

      if (prevStatus != newStatus) {
        state = state.copyWith(status: newStatus, hasFetched: true, isLive: true);
        // Patch global activity – low burden, no fetch
        try {
          _ref.read(activityProvider.notifier).patchOrderStatus(orderId, newStatus);
        } catch (_) {}

        // Debounced full fetch only on status change (to sync other fields) – 800ms debounce
        _debouncedFullFetch();

        // If terminal, stop
        if (state.isTerminal) {
          stop();
        }
      } else {
        // Even if same status, mark live
        state = state.copyWith(isLive: true, hasFetched: true);
      }
    });

    // Initial connect
    _connectLoop();

    // Fallback polling 15s removed — replaced by FCM order_status_changed + SSE order:{id} via dispatcher collapse_id order_{id}
    // No Timer.periodic — FCM maximizes antrian per-device bucket 20/10m refill 3m, prevents limit hit
    // FCM in main.dart handles order_status_changed → patchOrderStatus
    // ignore: avoid_print
    print('[order_status] Fallback 15s polling removed — using FCM order_status_changed + SSE primary');
  }

  void _debouncedFullFetch() {
    _debounceFetchTimer?.cancel();
    _debounceFetchTimer = Timer(const Duration(milliseconds: 800), () async {
      if (_disposed || !_shouldRun) return;
      try {
        final repo = _ref.read(orderRepositoryProvider);
        final fullOrder = await repo.getOrderById(orderId);
        if (fullOrder.status != state.status) {
          state = state.copyWith(status: fullOrder.status);
        }
        // Also patch via full order to ensure other fields sync
        _ref.read(activityProvider.notifier).patchOrder(fullOrder);
      } catch (_) {}
    });
  }

  // ignore: unused_element — kept for manual fallback if FCM+SSE both fail (no periodic Timer now)
  Future<void> _fallbackFetch() async {
    if (_disposed || !_shouldRun) return;
    if (state.isTerminal) return;
    try {
      final repo = _ref.read(orderRepositoryProvider);
      final full = await repo.getOrderById(orderId);
      if (full.status != state.status && full.status.isNotEmpty) {
        final prev = state.status;
        state = state.copyWith(status: full.status, hasFetched: true);
        try {
          _ref.read(activityProvider.notifier).patchOrder(full);
        } catch (_) {}
        if (prev != full.status && state.isTerminal) {
          stop();
        }
      }
    } catch (_) {}
  }

  Future<void> _connectLoop() async {
    if (_disposed || !_shouldRun) return;
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed &&
        WidgetsBinding.instance.lifecycleState != null) {
      return;
    }
    if (state.isTerminal) return;

    try {
      state = state.copyWith(isConnecting: true);
      final svc = _ref.read(orderStatusServiceProvider);
      await svc.connect(orderId: orderId);
      // connect() returns when disconnected (server closed or error)
      state = state.copyWith(isLive: false, isConnecting: false);
      if (_disposed || !_shouldRun) return;
      if (state.isTerminal) return;
      _scheduleReconnect();
    } catch (_) {
      state = state.copyWith(isLive: false, isConnecting: false);
      if (_disposed || !_shouldRun) return;
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    if (!_shouldRun || _disposed || state.isTerminal) return;
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed &&
        WidgetsBinding.instance.lifecycleState != null) {
      return;
    }
    final attempt = state.reconnectAttempts;
    if (attempt > 8) return; // stop after many attempts if still failing – fallback polling will handle
    final jitter = (DateTime.now().millisecondsSinceEpoch % 500);
    final backoffMs =
        (1000 * (1 << (attempt < 5 ? attempt : 5)) + jitter).clamp(1000, 20000);
    _reconnectTimer = Timer(Duration(milliseconds: backoffMs), () {
      if (_disposed || !_shouldRun || state.isTerminal) return;
      state = state.copyWith(reconnectAttempts: attempt + 1);
      _connectLoop();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // Disconnect to save battery & radio
      _ref.read(orderStatusServiceProvider).disconnect();
      this.state = this.state.copyWith(isLive: false, isConnecting: false);
    } else if (state == AppLifecycleState.resumed) {
      if (_shouldRun && !this.state.isTerminal) {
        // Reset attempts on resume for quick reconnect
        this.state = this.state.copyWith(reconnectAttempts: 0);
        _connectLoop();
      }
    }
  }

  // FCM handler — replaces 15s polling, called from main.dart onMessage when type order_status_changed
  void handleFcmStatus(String newStatus) {
    if (_disposed || !_shouldRun) return;
    if (newStatus.isEmpty) return;
    if (state.status == newStatus) return;
    state = state.copyWith(status: newStatus, hasFetched: true, isLive: true);
    try {
      _ref.read(activityProvider.notifier).patchOrderStatus(orderId, newStatus);
    } catch (_) {}
    _debouncedFullFetch();
    if (state.isTerminal) {
      stop();
    }
  }

  void stop() {
    _shouldRun = false;
    _reconnectTimer?.cancel();
    _debounceFetchTimer?.cancel();
    try {
      _ref.read(orderStatusServiceProvider).disconnect();
    } catch (_) {}
    state = state.copyWith(isLive: false, isConnecting: false);
  }

  @override
  void dispose() {
    _disposed = true;
    _shouldRun = false;
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    _reconnectTimer?.cancel();
    _debounceFetchTimer?.cancel();
    try {
      _ref.read(orderStatusServiceProvider).disconnect();
    } catch (_) {}
    super.dispose();
  }
}

final orderStatusProvider = StateNotifierProvider.autoDispose
    .family<OrderStatusNotifier, OrderStatusState, String>((ref, orderId) {
  final notifier = OrderStatusNotifier(ref, orderId);
  ref.onDispose(() => notifier.dispose());
  return notifier;
});
