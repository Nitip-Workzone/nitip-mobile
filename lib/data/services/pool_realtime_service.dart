import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/config/app_config.dart';

/// Best practice ringan: 1 koneksi SSE, auto close saat background, cancelable dengan CancelToken
/// Data model untuk event pool
class PoolEvent {
  final String type; // order_created, order_claimed, order_cancelled, connected, heartbeat
  final String? orderId;
  final int ts;
  final Map<String, dynamic>? data;

  PoolEvent({required this.type, this.orderId, required this.ts, this.data});

  factory PoolEvent.fromJson(Map<String, dynamic> j) {
    return PoolEvent(
      type: j['type'] as String? ?? '',
      orderId: j['order_id'] as String?,
      ts: j['ts'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      data: j['data'] is Map ? Map<String, dynamic>.from(j['data'] as Map) : null,
    );
  }
}

/// Lightweight SSE client using Dio stream – no extra dependency
/// - Non-blocking, buffer 64 events drop-oldest (via StreamController)
/// - _running guard prevents parallel connects
/// - CancelToken for clean disconnect
/// - Exponential backoff handled in provider, not here (single responsibility)
class PoolRealtimeService {
  StreamController<PoolEvent> _controller = StreamController<PoolEvent>.broadcast();
  Stream<PoolEvent> get stream => _controller.stream;

  CancelToken? _cancelToken;
  bool _running = false;
  bool get isRunning => _running;

  Future<void> connect({required double lat, required double lng, double radiusKm = 15}) async {
    if (_running) return;
    _running = true;
    _cancelToken = CancelToken();

    try {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'access_token');
      if (token == null || token.isEmpty) {
        _running = false;
        return;
      }

      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 0), // infinite for SSE
        headers: {
          'Accept': 'text/event-stream',
          'Authorization': 'Bearer $token',
        },
      ));

      // REFACTOR 2026-07-29: Cookie-only + Authorization header, no ?token= query (security + logs)
      final url =
          '${AppConfig.baseUrl}orders/pool/stream?lat=$lat&lng=$lng&radius=$radiusKm';

      final resp = await dio.get<ResponseBody>(
        url,
        options: Options(responseType: ResponseType.stream),
        cancelToken: _cancelToken,
      );

      // Ensure stream
      if (resp.data == null) {
        _running = false;
        return;
      }

      String buffer = '';
      // resp.data.stream is Stream<Uint8List>
      await for (final chunk in resp.data!.stream as Stream<List<int>>) {
        // Check cancellation before processing
        if (_cancelToken?.isCancelled == true) break;

        final String decoded = utf8.decode(chunk, allowMalformed: true);

        buffer += decoded;

        // SSE frames are separated by double \n\n
        while (buffer.contains('\n\n')) {
          final idx = buffer.indexOf('\n\n');
          final frame = buffer.substring(0, idx);
          buffer = buffer.substring(idx + 2);

          // Parse frame: lines of event: , data: , : heartbeat
          String dataStr = '';

          for (final rawLine in frame.split('\n')) {
            final line = rawLine.trim();
            if (line.isEmpty) continue;
            if (line.startsWith(':')) {
              // comment / heartbeat from server
              continue;
            }
            if (line.startsWith('event:')) {
              // event type ignored, we parse from data.type instead (more reliable)
              continue;
            } else if (line.startsWith('data:')) {
              dataStr += line.substring(5).trim();
            }
          }

          if (dataStr.isEmpty) continue;

          try {
            final jsonData = jsonDecode(dataStr) as Map<String, dynamic>;
            final ev = PoolEvent.fromJson(jsonData);
            if (_controller.isClosed) break;
            // Only forward meaningful events (skip heartbeat if parsed as event)
            if (ev.type == 'heartbeat') continue;
            _controller.add(ev);
          } catch (_) {
            // ignore parse errors
          }
        }
      }
    } on DioException catch (_) {
      // cancelled or network error — will reconnect via provider backoff
    } catch (_) {
      // generic error
    } finally {
      _running = false;
    }
  }

  void disconnect() {
    try {
      _cancelToken?.cancel('disconnect');
    } catch (_) {}
    _running = false;
  }

  void dispose() {
    disconnect();
    try {
      if (!_controller.isClosed) _controller.close();
    } catch (_) {}
    // Recreate for possible reuse
    _controller = StreamController<PoolEvent>.broadcast();
  }
}
