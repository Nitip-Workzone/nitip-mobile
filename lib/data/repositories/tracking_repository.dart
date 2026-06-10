import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import '../network/api_client.dart';
import '../../domain/models/tracking_state.dart';

class TrackingRepository {
  final ApiClient _apiClient;

  TrackingRepository(this._apiClient);

  /// Streams real-time tracking data for a specific order using SSE
  Stream<TrackingState> streamOrderTracking(String orderId) async* {
    final url = '/orders/$orderId/track';
    int retryCount = 0;
    
    while (retryCount < 10) {
      try {
        final response = await _apiClient.dio.get(
          url,
          options: Options(
            responseType: ResponseType.stream,
            headers: {'Accept': 'text/event-stream'},
          ),
        );

        final stream = response.data.stream as Stream<List<int>>;
        retryCount = 0; // Reset on successful connection
        
        await for (final chunk in stream) {
          final data = utf8.decode(chunk);
          final lines = data.split('\n');
          for (var line in lines) {
            if (line.startsWith('data: ')) {
              final jsonStr = line.substring(6).trim();
              if (jsonStr.isNotEmpty) {
                try {
                  final Map<String, dynamic> jsonData = json.decode(jsonStr);
                  yield TrackingState.fromJson(jsonData);
                } catch (e) {
                  debugPrint('[TRACKING_ERROR] Failed to parse JSON: $e');
                }
              }
            }
          }
        }
      } catch (e) {
        retryCount++;
        final delay = Duration(seconds: retryCount * 2);
        debugPrint('[TRACKING] Connection closed. Retrying in ${delay.inSeconds}s... (Attempt $retryCount)');
        await Future.delayed(delay);
      }
    }
    
    debugPrint('[TRACKING] Max retries reached. Stopping stream.');
  }

  /// Sends Runner's current location to the backend
  Future<void> updateLocation(double lat, double lng) async {
    // We use the X-Location header pattern or a dedicated endpoint.
    // Based on user/handler.go, calling /users/me with X-Location also updates it passively.
    // Or we can use the dedicated WS stream if implemented.
    // For simplicity and robustness, we'll use a PUT to a dedicated endpoint if available
    // but the backend handler.go showed passive update in GetMe.
    // Let's use the X-Location header on a simple GET /users/me call for now as a heartbeat.
    await _apiClient.dio.get('/users/me', options: Options(
      headers: {'X-Location': '$lat,$lng'},
    ));
  }
}
