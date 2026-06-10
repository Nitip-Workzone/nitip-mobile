import 'package:dio/dio.dart';
import '../../domain/repositories/notification_repository.dart';
import '../models/notification_model.dart';
import '../network/api_client.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  final ApiClient _apiClient;

  NotificationRepositoryImpl(this._apiClient);

  @override
  Future<List<NotificationModel>> getNotifications({int limit = 20, int offset = 0}) async {
    try {
      final response = await _apiClient.dio.get('/notifications', queryParameters: {
        'limit': limit,
        'offset': offset,
      });
      
      if (response.data['success'] == true) {
        final List list = response.data['data'] ?? [];
        return list.map((json) => NotificationModel.fromJson(json)).toList();
      } else {
        throw Exception(response.data['message'] ?? 'Gagal mengambil notifikasi');
      }
    } on DioException catch (e) {
      final message = e.response?.data['message'] ?? 'Terjadi kesalahan jaringan';
      throw Exception(message);
    }
  }

  @override
  Future<int> getUnreadCount() async {
    try {
      final response = await _apiClient.dio.get('/notifications/unread-count');
      if (response.data['success'] == true || response.data['unread_count'] != null) {
        return response.data['unread_count'] ?? 0;
      } else {
        return 0;
      }
    } catch (_) {
      return 0;
    }
  }

  @override
  Future<void> markAsRead(String id) async {
    try {
      await _apiClient.dio.put('/notifications/$id/read');
    } catch (_) {}
  }

  @override
  Future<void> markAllAsRead() async {
    try {
      await _apiClient.dio.put('/notifications/read-all');
    } catch (_) {}
  }
}
