import 'package:latlong2/latlong.dart';
import 'package:dio/dio.dart';
import 'dart:convert';
import '../config/app_config.dart';

class RoutingService {
  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  static Future<List<LatLng>> getRoute(LatLng start, LatLng end) async {
    return getRouteMulti([start, end]);
  }

  static Future<List<LatLng>> getRouteMulti(List<LatLng> points) async {
    try {
      if (points.length < 2) return points;
      final coordsString = points.map((p) => '${p.longitude},${p.latitude}').join(';');
      final query = '$coordsString?overview=full&geometries=geojson';

      Response response;
      try {
        response = await _dio.get('${AppConfig.routingUrl}/route/v1/driving/$query');
      } catch (_) {
        // Fallback ke Public OSRM
        response = await _dio.get('https://router.project-osrm.org/route/v1/driving/$query');
      }

      if (response.statusCode == 200) {
        var data = response.data;
        if (data is String) {
          data = jsonDecode(data);
        }
        final List coordinates = data['routes'][0]['geometry']['coordinates'];
        final routePoints = coordinates.map((c) => LatLng(c[1].toDouble(), c[0].toDouble())).toList();
        return routePoints;
      }
    } catch (_) {
      // ignore, fallback below
    }
    // Fallback to straight line
    return points;
  }
}
