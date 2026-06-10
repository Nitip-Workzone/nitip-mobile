import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/notification_provider.dart';
import '../../../data/models/notification_model.dart';

class NotificationPage extends ConsumerWidget {
  const NotificationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationProvider);
    final primary = AppColors.primary;

    // --- Lazy Load Strategy ---
    // Fetch list only when this page is built/viewed and has not been fetched yet
    if (!state.hasFetched && !state.isLoading) {
      Future.microtask(() => ref.read(notificationProvider.notifier).fetchNotifications());
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Notifikasi', style: TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1A1A1A), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (state.notifications.isNotEmpty)
            TextButton(
              onPressed: () => ref.read(notificationProvider.notifier).markAllAsRead(),
              child: Text('Baca Semua', style: TextStyle(color: primary, fontWeight: FontWeight.w600, fontSize: 13)),
            ),
        ],
      ),
      body: state.isLoading && state.notifications.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : state.notifications.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: () => ref.read(notificationProvider.notifier).fetchNotifications(),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: state.notifications.length,
                    separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey[100]),
                    itemBuilder: (context, index) {
                      final notif = state.notifications[index];
                      return _NotificationTile(
                        notification: notif,
                        onTap: () {
                          if (!notif.isRead) {
                            ref.read(notificationProvider.notifier).markAsRead(notif.id);
                          }
                          // Handle navigation based on type if needed
                        },
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey[300]),
          ),
          const SizedBox(height: 16),
          const Text(
            'Belum ada notifikasi',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
          ),
          const SizedBox(height: 8),
          Text(
            'Pemberitahuan aktivitas Anda akan muncul di sini.',
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;

  const _NotificationTile({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final Color color;

    switch (notification.type) {
      case 'order':
        icon = Icons.shopping_bag_rounded;
        color = Colors.blue;
        break;
      case 'payment':
        icon = Icons.account_balance_wallet_rounded;
        color = Colors.green;
        break;
      case 'chat':
        icon = Icons.chat_bubble_rounded;
        color = Colors.orange;
        break;
      case 'kyc':
        icon = Icons.verified_user_rounded;
        color = Colors.purple;
        break;
      default:
        icon = Icons.notifications_rounded;
        color = Colors.grey;
    }

    return InkWell(
      onTap: onTap,
      child: Container(
        color: notification.isRead ? Colors.transparent : Colors.blue.withValues(alpha: 0.03),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: notification.isRead ? FontWeight.w600 : FontWeight.w800,
                            color: const Color(0xFF1A1A1A),
                          ),
                        ),
                      ),
                      Text(
                        _formatTime(notification.createdAt),
                        style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.message,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            if (!notification.isRead)
              Container(
                margin: const EdgeInsets.only(left: 12, top: 4),
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}j';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}h';
    } else {
      return DateFormat('dd/MM').format(time);
    }
  }
}
