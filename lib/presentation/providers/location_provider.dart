import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../core/services/location_service.dart';
import 'auth_provider.dart';

final userLocationProvider = StateNotifierProvider<UserLocationNotifier, LatLng?>((ref) {
  final notifier = UserLocationNotifier(ref);
  ref.onDispose(() {
    notifier.stopTracking();
  });
  return notifier;
});

class UserLocationNotifier extends StateNotifier<LatLng?> {
  final Ref _ref;
  Timer? _timer;
  final locationService = LocationService();

  UserLocationNotifier(this._ref) : super(null) {
    startTracking();
  }

  void startTracking() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 15), (timer) async {
      await updateLocation();
    });
  }

  void stopTracking() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> updateLocation() async {
    final pos = await locationService.getCurrentPosition();
    if (pos != null) {
      state = pos;
      
      // Sync runner location with backend periodically
      final auth = _ref.read(authProvider);
      if (auth.isAuthenticated && auth.user != null) {
        try {
          await _ref.read(authRepositoryProvider).updateLocation(pos.latitude, pos.longitude);
        } catch (_) {
          // Fail silently to avoid interrupting UX
        }
      }
    }
  }
}

final userAddressProvider = FutureProvider<String?>((ref) async {
  final loc = ref.watch(userLocationProvider);
  if (loc == null) return null;
  return LocationService().getAddressFromCoords(loc.latitude, loc.longitude);
});
