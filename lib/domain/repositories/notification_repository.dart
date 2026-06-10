import '../../data/models/notification_model.dart';

abstract class NotificationRepository {
  Future<List<NotificationModel>> getNotifications({int limit = 20, int offset = 0});
  Future<int> getUnreadCount();
  Future<void> markAsRead(String id);
  Future<void> markAllAsRead();
}
