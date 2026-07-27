import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../core/services/location_service.dart';
import 'auth_provider.dart';
import 'activity_provider.dart';

final userLocationProvider = StateNotifierProvider<UserLocationNotifier, LatLng?>((ref) {
  final notifier = UserLocationNotifier(ref);
  ref.onDispose(() {
    notifier.stopTracking();
  });
  return notifier;
});

/// Heartbeat yang memenuhi 3 syarat:
/// 1. Status Online (isAcceptingOrders / isOnline dari screenshot Offline pill)
/// 2. Ada order aktif (activeOrders.length > 0)
/// 3. Sedang trip & app foreground (AppLifecycleState.resumed)
class UserLocationNotifier extends StateNotifier<LatLng?> with WidgetsBindingObserver {
  final Ref _ref;
  Timer? _timer;
  final locationService = LocationService();
  bool _isForeground = true;
  LatLng? _lastSentPos;
  bool _hasActiveTrip = false;

  UserLocationNotifier(this._ref) : super(null) {
    WidgetsBinding.instance.addObserver(this);
    // Initial one-time location for UI (not heartbeat)
    _fetchOnceForDisplay();
    _evaluateTrackingState();

    // Listen to auth online status changes to start/stop heartbeat
    _ref.listen(authProvider.select((s) => s.user?.isAcceptingOrders), (_, __) {
      _evaluateTrackingState();
    });
    _ref.listen(activityProvider.select((s) => s.activeOrders.length), (_, __) {
      _evaluateTrackingState();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final wasForeground = _isForeground;
    _isForeground = state == AppLifecycleState.resumed;
    if (wasForeground != _isForeground) {
      _evaluateTrackingState();
    }
  }

  void _fetchOnceForDisplay() async {
    try {
      final pos = await locationService.getCurrentPosition();
      if (pos != null) {
        state = pos;
      }
    } catch (_) {}
  }

  /// Cek apakah heartbeat boleh aktif
  bool get _shouldHeartbeat {
    final auth = _ref.read(authProvider);
    final user = auth.user;
    if (user == null || !auth.isAuthenticated) return false;
    if (!user.isRunner) return false;
    if (!user.isAcceptingOrders) return false; // Syarat 1: Online
    final activity = _ref.read(activityProvider);
    if (activity.activeOrders.isEmpty) return false; // Syarat 2: Ada order aktif
    if (!_hasActiveTrip && activity.activeOrders.isEmpty) {
      // Juga allow jika ada activeOrder meski trip belum, karena trip bisa implicit
      // Tapi jika mau strict trip: cek tripProvider. Untuk sekarang activeOrder sudah cukup mewakili.
    }
    if (!_isForeground) return false; // Syarat 3: foreground
    return true;
  }

  void setHasActiveTrip(bool hasTrip) {
    _hasActiveTrip = hasTrip;
    _evaluateTrackingState();
  }

  void _evaluateTrackingState() {
    if (_shouldHeartbeat) {
      startTracking();
    } else {
      stopTracking();
    }
  }

  void startTracking() {
    if (_timer != null && _timer!.isActive) return;
    // Heartbeat interval 45s (sebelumnya 15s terlalu sering)
    _timer = Timer.periodic(const Duration(seconds: 45), (timer) async {
      if (!_shouldHeartbeat) {
        stopTracking();
        return;
      }
      await _sendHeartbeat();
    });
    // Kirim segera pertama kali saat mulai
    Future.microtask(() => _sendHeartbeat());
  }

  void stopTracking() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _sendHeartbeat() async {
    try {
      final pos = await locationService.getCurrentPosition();
      if (pos == null) return;

      // Distance dedup: skip if moved <20m
      if (_lastSentPos != null) {
        const distance = Distance();
        final moved = distance.as(LengthUnit.Meter, _lastSentPos!, pos);
        if (moved < 20) return;
      }

      state = pos;

      final auth = _ref.read(authProvider);
      if (!auth.isAuthenticated || auth.user == null) return;

      final activity = _ref.read(activityProvider);
      final activeTripId = _ref.read(_currentTripIdProvider);
      final activeOrdersCount = activity.activeOrders.length;

      await _ref.read(authRepositoryProvider).sendHeartbeat(
            lat: pos.latitude,
            lng: pos.longitude,
            tripId: activeTripId,
            activeOrders: activeOrdersCount,
            isForeground: _isForeground,
          );

      _lastSentPos = pos;
    } catch (_) {
      // Silent fail
    }
  }

  /// Untuk UI saja, tanpa kirim heartbeat
  Future<void> updateLocation() async {
    final pos = await locationService.getCurrentPosition();
    if (pos != null) {
      state = pos;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    stopTracking();
    super.dispose();
  }
}

// Helper provider untuk menyimpan tripId aktif (di-set dari trips tab)
final _currentTripIdProvider = StateProvider<String?>((ref) => null);

/// Provider helper untuk dashboard/trip tab meng-set apakah ada trip aktif
final hasActiveTripProvider = StateProvider<bool>((ref) => false);

final userAddressProvider = FutureProvider<String?>((ref) async {
  final loc = ref.watch(userLocationProvider);
  if (loc == null) return null;
  return LocationService().getAddressFromCoords(loc.latitude, loc.longitude);
});
