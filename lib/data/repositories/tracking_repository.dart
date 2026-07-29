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
  /// FIX 2026-07-28: Stop using GET /users/me with X-Location (causes /me spam in logs)
  /// Merchant doesn't need tracking at all. Use dedicated heartbeat endpoint or no-op.
  Future<void> updateLocation(double lat, double lng) async {
    // Merchant: no tracking needed, skip /me call to avoid log spam
    // Runner: heartbeat already uses /users/heartbeat via auth_repository, so this is legacy no-op
    // Keeping method for backward compat but not calling /me
    return;
  }
}
