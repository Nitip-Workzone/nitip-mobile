import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:dio/dio.dart';
import '../config/app_config.dart';

class LocationService {
  final Dio _dio = Dio(
    BaseOptions(
      headers: {
        'User-Agent': 'NitipMobileApp/1.0 (contact@nitip.com)',
      },
      connectTimeout: const Duration(seconds: 10), // Diperpanjang untuk local container
      receiveTimeout: const Duration(seconds: 10),
    ),
  );



  Future<LatLng?> getCurrentPosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint("Location services are disabled.");
        return null;
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint("Location permissions are denied.");
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint("Location permissions are permanently denied.");
        return null;
      }

      // Try to get last known position first for speed
      final lastPos = await Geolocator.getLastKnownPosition();
      if (lastPos != null) {
        if (lastPos.isMocked) {
          throw Exception("Fake GPS/Mock Location terdeteksi! Gunakan lokasi GPS asli Anda.");
        }
        return LatLng(lastPos.latitude, lastPos.longitude);
      }

      // If no last position, get current with timeout
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );
      if (position.isMocked) {
        throw Exception("Fake GPS/Mock Location terdeteksi! Gunakan lokasi GPS asli Anda.");
      }
      return LatLng(position.latitude, position.longitude);
    } catch (e) {
      debugPrint("Error getting location: $e");
      // Fallback if current position times out but we have a last known one (re-check)
      try {
        final lastPos = await Geolocator.getLastKnownPosition();
        if (lastPos != null) return LatLng(lastPos.latitude, lastPos.longitude);
      } catch (_) {}
      return null;
    }
  }

  Future<String?> getAddressFromCoords(double lat, double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final name = p.name != null && p.name != p.street ? "${p.name}, " : "";
        return "$name${p.street}, ${p.subLocality}, ${p.locality}";
      }
    } catch (e) {
      // 1. Coba Self-Hosted Nominatim (Local)
      try {
        final resp = await _dio.get(
          '${AppConfig.nominatimUrl}/reverse',
          queryParameters: {
            'format': 'json',
            'lat': lat,
            'lon': lng,
            'zoom': 18,
            'addressdetails': 1,
          },
        );
        return resp.data['display_name'];
      } catch (e) {
        debugPrint('[LOCATION_DEBUG] Local Nominatim failed: $e. Falling back to public OSM.');
        // 2. Fallback ke Nominatim Publik (OSM) jika lokal down
        try {
          final resp = await _dio.get(
            'https://nominatim.openstreetmap.org/reverse',
            queryParameters: {
              'format': 'json',
              'lat': lat,
              'lon': lng,
              'zoom': 18,
              'addressdetails': 1,
            },
          );
          return resp.data['display_name'];
        } catch (_) {
          return null;
        }
      }
    }
    return null;
  }

  /// Searches for places/shops using Nominatim POI search
  Future<List<Map<String, dynamic>>> searchPlaces(String query, {double? lat, double? lng}) async {
    final Map<String, dynamic> queryParams = {
      'q': query,
      'format': 'json',
      'limit': 10,
      'addressdetails': 1,
      'countrycodes': 'id', // Restrict to Indonesia
    };

    if (lat != null && lng != null) {
      const double delta = 0.05; 
      queryParams['viewbox'] = '${lng - delta},${lat + delta},${lng + delta},${lat - delta}';
      queryParams['bounded'] = 0;
    }

    try {
      // 1. Coba Self-Hosted Nominatim (Local)
      final resp = await _dio.get(
        '${AppConfig.nominatimUrl}/search',
        queryParameters: queryParams,
      );
      
      return (resp.data as List).map((item) => {
        'display_name': item['display_name'],
        'lat': double.parse(item['lat']),
        'lng': double.parse(item['lon']),
      }).toList();
    } catch (e) {
      debugPrint('[LOCATION_DEBUG] Local Nominatim search failed: $e. Falling back to public OSM.');
      // 2. Fallback ke Nominatim Publik (OSM) jika lokal down
      try {
        final resp = await _dio.get(
          'https://nominatim.openstreetmap.org/search',
          queryParameters: queryParams,
        );
        
        return (resp.data as List).map((item) => {
          'display_name': item['display_name'],
          'lat': double.parse(item['lat']),
          'lng': double.parse(item['lon']),
        }).toList();
      } catch (_) {
        return [];
      }
    }
  }


  Future<LatLng?> getCoordsFromAddress(String address) async {
    try {
      List<Location> locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        return LatLng(locations.first.latitude, locations.first.longitude);
      }
    } catch (e) {
      // Fallback to searchPlaces
      final results = await searchPlaces(address);
      if (results.isNotEmpty) {
        return LatLng(results.first['lat'], results.first['lng']);
      }
    }
    return null;
  }
}
