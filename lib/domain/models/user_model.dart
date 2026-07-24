class User {
  final String id;
  final String name;
  final String email;
  final String whatsappNumber;
  final String? avatarUrl;
  final String role;
  final int trustScore;
  final bool isVerified;
  final DateTime? verifiedAt;
  final String? fcmToken;
  final double? lastLat;
  final double? lastLng;
  final double? homeLat;
  final double? homeLng;
  final String? homeAddress;
  final bool isSuspended;
  final String? suspendedReason;
  final bool hasPin;
  final bool isAcceptingOrders;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isRunner => role == 'runner';
  bool get isRequester => role == 'requester';
  bool get isPenitip => isRequester;
  bool get isMerchant => role == 'merchant';

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.whatsappNumber,
    this.avatarUrl,
    required this.role,
    required this.trustScore,
    required this.isVerified,
    this.verifiedAt,
    this.fcmToken,
    this.lastLat,
    this.lastLng,
    this.homeLat,
    this.homeLng,
    this.homeAddress,
    required this.isSuspended,
    this.suspendedReason,
    this.hasPin = false,
    this.isAcceptingOrders = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      whatsappNumber: json['whatsapp_number'] ?? '',
      avatarUrl: json['avatar_url'],
      role: json['role'],
      trustScore: json['trust_score'] ?? 0,
      isVerified: json['is_verified'] ?? false,
      verifiedAt: json['verified_at'] != null ? DateTime.parse(json['verified_at']) : null,
      fcmToken: json['fcm_token'],
      lastLat: json['last_lat']?.toDouble(),
      lastLng: json['last_lng']?.toDouble(),
      homeLat: json['home_lat']?.toDouble(),
      homeLng: json['home_lng']?.toDouble(),
      homeAddress: json['home_address'],
      isSuspended: json['is_suspended'] ?? false,
      suspendedReason: json['suspended_reason'],
      hasPin: json['has_pin'] ?? false,
      isAcceptingOrders: json['is_accepting_orders'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'whatsapp_number': whatsappNumber,
      'avatar_url': avatarUrl,
      'role': role,
      'trust_score': trustScore,
      'is_verified': isVerified,
      'verified_at': verifiedAt?.toIso8601String(),
      'fcm_token': fcmToken,
      'last_lat': lastLat,
      'last_lng': lastLng,
      'home_lat': homeLat,
      'home_lng': homeLng,
      'home_address': homeAddress,
      'is_suspended': isSuspended,
      'suspended_reason': suspendedReason,
      'has_pin': hasPin,
      'is_accepting_orders': isAcceptingOrders,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  User copyWith({
    String? id,
    String? name,
    String? email,
    String? whatsappNumber,
    String? avatarUrl,
    String? role,
    int? trustScore,
    bool? isVerified,
    DateTime? verifiedAt,
    String? fcmToken,
    double? lastLat,
    double? lastLng,
    double? homeLat,
    double? homeLng,
    String? homeAddress,
    bool? isSuspended,
    String? suspendedReason,
    bool? hasPin,
    bool? isAcceptingOrders,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      whatsappNumber: whatsappNumber ?? this.whatsappNumber,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      trustScore: trustScore ?? this.trustScore,
      isVerified: isVerified ?? this.isVerified,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      fcmToken: fcmToken ?? this.fcmToken,
      lastLat: lastLat ?? this.lastLat,
      lastLng: lastLng ?? this.lastLng,
      homeLat: homeLat ?? this.homeLat,
      homeLng: homeLng ?? this.homeLng,
      homeAddress: homeAddress ?? this.homeAddress,
      isSuspended: isSuspended ?? this.isSuspended,
      suspendedReason: suspendedReason ?? this.suspendedReason,
      hasPin: hasPin ?? this.hasPin,
      isAcceptingOrders: isAcceptingOrders ?? this.isAcceptingOrders,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
