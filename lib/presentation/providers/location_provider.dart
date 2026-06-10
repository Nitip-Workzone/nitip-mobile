import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../core/services/location_service.dart';

final userLocationProvider = StateNotifierProvider<UserLocationNotifier, LatLng?>((ref) {
  return UserLocationNotifier();
});

class UserLocationNotifier extends StateNotifier<LatLng?> {
  UserLocationNotifier() : super(null);

  final locationService = LocationService();

  Future<void> updateLocation() async {
    final pos = await locationService.getCurrentPosition();
    if (pos != null) {
      state = pos;
    }
  }
}

final userAddressProvider = FutureProvider<String?>((ref) async {
  final loc = ref.watch(userLocationProvider);
  if (loc == null) return null;
  return LocationService().getAddressFromCoords(loc.latitude, loc.longitude);
});
