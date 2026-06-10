import 'package:flutter/foundation.dart';
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
      debugPrint('[ROUTING_DEBUG] Fetching route: query=$query');
      
      Response response;
      try {
        response = await _dio.get('${AppConfig.routingUrl}/route/v1/driving/$query');
        debugPrint('[ROUTING_DEBUG] Local OSRM success: statusCode=${response.statusCode}');
      } catch (e) {
        debugPrint('[ROUTING_DEBUG] Local OSRM failed, falling back to public: $e');
        // 2. Fallback ke Public OSRM
        response = await _dio.get('https://router.project-osrm.org/route/v1/driving/$query');
        debugPrint('[ROUTING_DEBUG] Public OSRM success: statusCode=${response.statusCode}');
      }
      
      if (response.statusCode == 200) {
        var data = response.data;
        if (data is String) {
          debugPrint('[ROUTING_DEBUG] response.data is String, decoding manually...');
          data = jsonDecode(data);
        }
        debugPrint('[ROUTING_DEBUG] response.data type: ${data.runtimeType}');

        final List coordinates = data['routes'][0]['geometry']['coordinates'];
        final routePoints = coordinates.map((c) => LatLng(c[1].toDouble(), c[0].toDouble())).toList();
        debugPrint('[ROUTING_DEBUG] Route parsed successfully with ${routePoints.length} coordinates.');
        return routePoints;
      } else {
        debugPrint('[ROUTING_DEBUG] Response code is not 200: ${response.statusCode}');
      }
    } catch (e, stack) {
      debugPrint('[ROUTING_ERROR] Failed to fetch route: $e\n$stack');
    }
    // Fallback to straight line
    debugPrint('[ROUTING_DEBUG] Falling back to straight lines');
    return points;
  }
}
