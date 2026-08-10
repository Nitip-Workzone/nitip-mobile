class SupportTicketModel {
  final String id;
  final String userId;
  final String? orderId;
  final String category;
  final String title;
  final String description;
  final String status;
  final int priority;
  final String? assignedCsId;
  final String? assignedCsName;
  final String? assignedCsWhatsapp;
  final DateTime createdAt;
  final DateTime updatedAt;

  SupportTicketModel({
    required this.id,
    required this.userId,
    this.orderId,
    required this.category,
    required this.title,
    required this.description,
    required this.status,
    required this.priority,
    this.assignedCsId,
    this.assignedCsName,
    this.assignedCsWhatsapp,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SupportTicketModel.fromJson(Map<String, dynamic> json) {
    return SupportTicketModel(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      orderId: json['order_id'],
      category: json['category'] ?? 'other',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      status: json['status'] ?? 'queued',
      priority: json['priority'] ?? 1,
      assignedCsId: json['assigned_cs_id'],
      assignedCsName: json['assigned_cs_name'],
      assignedCsWhatsapp: json['assigned_cs_whatsapp'],
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
    );
  }

  bool get isOpen => status == 'queued' || status == 'open';
  bool get isActive => status == 'assigned' || status == 'in_progress' || status == 'waiting_user';
  bool get isClosed => status == 'resolved' || status == 'closed';
}

class SupportMessageModel {
  final String id;
  final String ticketId;
  final String senderId;
  final String senderRole;
  final String message;
  final bool isInternal;
  final DateTime createdAt;

  SupportMessageModel({
    required this.id,
    required this.ticketId,
    required this.senderId,
    required this.senderRole,
    required this.message,
    required this.isInternal,
    required this.createdAt,
  });

  factory SupportMessageModel.fromJson(Map<String, dynamic> json) {
    return SupportMessageModel(
      id: json['id'] ?? '',
      ticketId: json['ticket_id'] ?? '',
      senderId: json['sender_id'] ?? '',
      senderRole: json['sender_role'] ?? 'user',
      message: json['message'] ?? '',
      isInternal: json['is_internal'] ?? false,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  bool get isFromCs => senderRole == 'cs';
  bool get isFromUser => senderRole == 'user';
}
