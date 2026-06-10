class WalletModel {
  final String id;
  final String userId;
  final double balance;
  final DateTime createdAt;
  final DateTime updatedAt;

  WalletModel({
    required this.id,
    required this.userId,
    required this.balance,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WalletModel.fromJson(Map<String, dynamic> json) {
    return WalletModel(
      id: json['id'],
      userId: json['user_id'],
      balance: (json['balance'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}

class WalletTransactionModel {
  final String id;
  final String walletId;
  final String? orderId;
  final String type;
  final double amount;
  final String? reference;
  final String status;
  final String? qrisString;
  final DateTime createdAt;

  WalletTransactionModel({
    required this.id,
    required this.walletId,
    this.orderId,
    required this.type,
    required this.amount,
    this.reference,
    required this.status,
    this.qrisString,
    required this.createdAt,
  });

  factory WalletTransactionModel.fromJson(Map<String, dynamic> json) {
    return WalletTransactionModel(
      id: json['id'],
      walletId: json['wallet_id'],
      orderId: json['order_id'],
      type: json['type'],
      amount: (json['amount'] as num).toDouble(),
      reference: json['reference'],
      status: json['status'],
      qrisString: json['qris_string'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class WithdrawalChannelModel {
  final String id;
  final String name;
  final String code;
  final String type;
  final double adminFeeFlat;
  final double adminFeePercent;
  final double minAmount;
  final String estimatedTime;
  final bool isActive;

  WithdrawalChannelModel({
    required this.id,
    required this.name,
    required this.code,
    required this.type,
    required this.adminFeeFlat,
    required this.adminFeePercent,
    required this.minAmount,
    required this.estimatedTime,
    required this.isActive,
  });

  factory WithdrawalChannelModel.fromJson(Map<String, dynamic> json) {
    return WithdrawalChannelModel(
      id: json['id'],
      name: json['name'],
      code: json['code'],
      type: json['type'],
      adminFeeFlat: (json['admin_fee_flat'] as num).toDouble(),
      adminFeePercent: (json['admin_fee_percent'] as num).toDouble(),
      minAmount: (json['min_amount'] as num).toDouble(),
      estimatedTime: json['estimated_time'],
      isActive: json['is_active'] ?? true,
    );
  }
}
