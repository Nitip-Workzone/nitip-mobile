import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/config/app_config.dart';

/// Event model untuk status order specific – low burden
/// - 0 DB queries saat idle (server event-driven via PoolHub)
/// - Hanya 1 koneksi SSE aktif saat detail page terbuka di status intermediate
class OrderStatusEvent {
  final String status;
  final String type; // order_status, init, completed, cancelled, etc
  final String? orderId;
  final int ts;

  OrderStatusEvent({
    required this.status,
    required this.type,
    this.orderId,
    required this.ts,
  });

  factory OrderStatusEvent.fromJson(Map<String, dynamic> j) {
    // Backend format: event: order_status \n data: {"type":..., "order_id":..., "data":{"status":...}}
    // atau legacy: data: {"status": "..."}
    String status = '';
    if (j['status'] is String) {
      status = j['status'] as String;
    } else if (j['data'] is Map && (j['data'] as Map)['status'] is String) {
      status = (j['data'] as Map)['status'] as String;
    }
    return OrderStatusEvent(
      status: status,
      type: j['type'] as String? ?? '',
      orderId: j['order_id'] as String?,
      ts: j['ts'] as int? ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  factory OrderStatusEvent.fromLegacy(Map<String, dynamic> j) {
    // Legacy Stream handler: data: {"status":"ready"}
    return OrderStatusEvent(
      status: j['status'] as String? ?? '',
      type: 'order_status',
      orderId: null,
      ts: DateTime.now().millisecondsSinceEpoch,
    );
  }
}

/// Low-burden SSE client untuk single order
/// - Reuse pattern dari PoolRealtimeService agar ringan di device
/// - Auto dispose, cancelable
class OrderStatusService {
  StreamController<OrderStatusEvent> _controller =
      StreamController<OrderStatusEvent>.broadcast();
  Stream<OrderStatusEvent> get stream => _controller.stream;

  CancelToken? _cancelToken;
  bool _running = false;
  bool get isRunning => _running;
  String? _currentOrderId;

  Future<void> connect({required String orderId}) async {
    if (_running && _currentOrderId == orderId) return;
    // Jika ganti order, disconnect dulu
    if (_running) disconnect();

    _running = true;
    _currentOrderId = orderId;
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
        receiveTimeout: const Duration(seconds: 0), // infinite SSE
        headers: {
          'Accept': 'text/event-stream',
          'Authorization': 'Bearer $token',
        },
      ));

      final url = '${AppConfig.baseUrl}orders/$orderId/stream';

      final resp = await dio.get<ResponseBody>(
        url,
        options: Options(responseType: ResponseType.stream),
        cancelToken: _cancelToken,
      );

      if (resp.data == null) {
        _running = false;
        return;
      }

      String buffer = '';
      await for (final chunk in resp.data!.stream as Stream<List<int>>) {
        if (_cancelToken?.isCancelled == true) break;

        final String decoded = utf8.decode(chunk, allowMalformed: true);
        buffer += decoded;

        while (buffer.contains('\n\n')) {
          final idx = buffer.indexOf('\n\n');
          final frame = buffer.substring(0, idx);
          buffer = buffer.substring(idx + 2);

          String dataStr = '';
          String eventType = '';

          for (final rawLine in frame.split('\n')) {
            final line = rawLine.trim();
            if (line.isEmpty) continue;
            if (line.startsWith(':')) {
              // heartbeat comment
              continue;
            }
            if (line.startsWith('event:')) {
              eventType = line.substring(6).trim();
              continue;
            } else if (line.startsWith('data:')) {
              dataStr += line.substring(5).trim();
            }
          }

          if (dataStr.isEmpty) continue;
          try {
            final jsonData = jsonDecode(dataStr) as Map<String, dynamic>;
            OrderStatusEvent ev;
            // Distinguish new format (has type + data.status) vs legacy {status}
            if (jsonData.containsKey('type') || jsonData.containsKey('order_id')) {
              ev = OrderStatusEvent.fromJson(jsonData);
              // Override type dari SSE event line jika ada
              if (eventType.isNotEmpty && ev.type.isEmpty) {
                ev = OrderStatusEvent(
                    status: ev.status,
                    type: eventType,
                    orderId: ev.orderId,
                    ts: ev.ts);
              }
            } else {
              ev = OrderStatusEvent.fromLegacy(jsonData);
              if (eventType.isNotEmpty) {
                ev = OrderStatusEvent(
                    status: ev.status, type: eventType, orderId: ev.orderId, ts: ev.ts);
              }
            }

            if (ev.status.isEmpty) continue;
            if (_controller.isClosed) break;
            if (ev.type == 'heartbeat') continue;
            _controller.add(ev);

            // Terminal: close after delivering completed/cancelled
            if (ev.type == 'completed' ||
                ev.type == 'cancelled' ||
                ev.type == 'expired' ||
                ev.status == 'completed' ||
                ev.status == 'cancelled' ||
                ev.status == 'expired') {
              // keep open a bit then server will close; we also stop client loop after
              // but don't break immediately – let server close naturally
            }
          } catch (_) {
            // ignore parse
          }
        }
      }
    } on DioException catch (_) {
      // cancelled or network – will reconnect via provider
    } catch (_) {
      // generic
    } finally {
      _running = false;
    }
  }

  void disconnect() {
    try {
      _cancelToken?.cancel('disconnect order status');
    } catch (_) {}
    _running = false;
    _currentOrderId = null;
  }

  void dispose() {
    disconnect();
    try {
      if (!_controller.isClosed) _controller.close();
    } catch (_) {}
    _controller = StreamController<OrderStatusEvent>.broadcast();
  }
}
