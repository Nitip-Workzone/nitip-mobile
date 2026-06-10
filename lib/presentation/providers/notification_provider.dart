import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/notification_model.dart';
import '../../domain/repositories/notification_repository.dart';
import '../../data/repositories/notification_repository_impl.dart';
import 'auth_provider.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return NotificationRepositoryImpl(apiClient);
});

class NotificationState {
  final bool isLoading;
  final bool hasFetched;
  final String? error;
  final List<NotificationModel> notifications;
  final int unreadCount;
  final bool hasFetchedCount;

  NotificationState({
    this.isLoading = false,
    this.hasFetched = false,
    this.error,
    this.notifications = const [],
    this.unreadCount = 0,
    this.hasFetchedCount = false,
  });

  NotificationState copyWith({
    bool? isLoading,
    bool? hasFetched,
    String? error,
    List<NotificationModel>? notifications,
    int? unreadCount,
    bool? hasFetchedCount,
  }) {
    return NotificationState(
      isLoading: isLoading ?? this.isLoading,
      hasFetched: hasFetched ?? this.hasFetched,
      error: error,
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      hasFetchedCount: hasFetchedCount ?? this.hasFetchedCount,
    );
  }
}

class NotificationNotifier extends StateNotifier<NotificationState> {
  final NotificationRepository _repository;

  NotificationNotifier(this._repository) : super(NotificationState()) {
    // Only fetch unread count on initialization for dashboard badge.
    // Full notifications list will be fetched on-demand when user opens notification page.
    fetchUnreadCount();
  }

  Future<void> fetchNotifications() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final notifications = await _repository.getNotifications();
      state = state.copyWith(isLoading: false, hasFetched: true, notifications: notifications);
    } catch (e) {
      state = state.copyWith(isLoading: false, hasFetched: true, error: e.toString());
    }
  }

  Future<void>? _unreadCountFuture;

  Future<void> fetchUnreadCount({bool force = false}) async {
    if (state.hasFetchedCount && !force) return;
    if (_unreadCountFuture != null) return _unreadCountFuture;

    _unreadCountFuture = _performFetchUnreadCount();
    try {
      await _unreadCountFuture;
    } finally {
      _unreadCountFuture = null;
    }
  }

  Future<void> _performFetchUnreadCount() async {
    try {
      final count = await _repository.getUnreadCount();
      state = state.copyWith(unreadCount: count, hasFetchedCount: true);
    } catch (_) {
      // Ignore unread count error
    }
  }

  Future<void> markAsRead(String id) async {
    try {
      await _repository.markAsRead(id);
      // Update local state for immediate feedback
      final updatedNotifs = state.notifications.map((n) {
        if (n.id == id) {
          return NotificationModel(
            id: n.id,
            userId: n.userId,
            title: n.title,
            message: n.message,
            type: n.type,
            isRead: true,
            metadata: n.metadata,
            createdAt: n.createdAt,
          );
        }
        return n;
      }).toList();
      
      final newUnreadCount = (state.unreadCount - 1).clamp(0, 999);
      state = state.copyWith(notifications: updatedNotifs, unreadCount: newUnreadCount);
    } catch (_) {
      // Handle error
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await _repository.markAllAsRead();
      final updatedNotifs = state.notifications.map((n) {
        return NotificationModel(
          id: n.id,
          userId: n.userId,
          title: n.title,
          message: n.message,
          type: n.type,
          isRead: true,
          metadata: n.metadata,
          createdAt: n.createdAt,
        );
      }).toList();
      state = state.copyWith(notifications: updatedNotifs, unreadCount: 0);
    } catch (_) {
      // Handle error
    }
  }
}

final notificationProvider = StateNotifierProvider<NotificationNotifier, NotificationState>((ref) {
  final repository = ref.watch(notificationRepositoryProvider);
  return NotificationNotifier(repository);
});
