class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String message;
  final String type;
  final bool isRead;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    this.metadata,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'],
      userId: json['user_id'],
      title: json['title'],
      message: json['message'],
      type: json['type'],
      isRead: json['is_read'],
      metadata: json['metadata'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
