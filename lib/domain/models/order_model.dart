import 'package:intl/intl.dart';

class OrderModel {
  final String id;
  final String requesterId;
  final String? runnerId;
  final String itemDetails;
  final double pickupLat;
  final double pickupLng;
  final double deliveryLat;
  final double deliveryLng;
  final double estimatedCost;
  final double deliveryFee;
  final String status;
  final String paymentStatus;
  final String paymentMethod;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? receiptImageUrl;
  final String? deliveryImageUrl;
  final String? disputeReason;
  final String? disputeProofUrl;
  final DateTime? disputedAt;
  final double adjustedCost;
  final String? adjustmentReason;
  final String? adjustmentStatus;
  final double weightKg;
  final double volumeLiters;
  final double serviceFee;
  final String? tripId;
  final double totalPayment;
  final String orderType;
  final double checkingFee;
  final String serviceCategory;
  final String? receiverName;
  final String? receiverPhone;
  final String? deliveryName;
  final String? deliveryAddress;
  final String? pickupName;
  final String? pickupAddress;
  final double distanceKm;

  final String? completionCode;
  final int? feedbackRating;
  final String? feedbackComment;
  final String paymentSource;
  final String? qrisData;

  OrderModel({
    required this.id,
    required this.requesterId,
    this.runnerId,
    required this.itemDetails,
    required this.pickupLat,
    required this.pickupLng,
    required this.deliveryLat,
    required this.deliveryLng,
    required this.estimatedCost,
    required this.deliveryFee,
    required this.status,
    required this.paymentStatus,
    required this.paymentMethod,
    required this.createdAt,
    required this.updatedAt,
    this.receiptImageUrl,
    this.deliveryImageUrl,
    this.disputeReason,
    this.disputeProofUrl,
    this.disputedAt,
    this.adjustedCost = 0,
    this.adjustmentReason,
    this.adjustmentStatus,
    this.weightKg = 0,
    this.volumeLiters = 0,
    this.serviceFee = 0,
    this.tripId,
    this.totalPayment = 0,
    this.orderType = 'regular',
    this.checkingFee = 0,
    this.serviceCategory = 'beli',
    this.receiverName,
    this.receiverPhone,
    this.deliveryName,
    this.deliveryAddress,
    this.pickupName,
    this.pickupAddress,
    this.distanceKm = 0,
    this.completionCode,
    this.feedbackRating,
    this.feedbackComment,
    this.paymentSource = 'wallet',
    this.qrisData,
  });

  factory OrderModel.empty() {
    return OrderModel(
      id: '',
      requesterId: '',
      itemDetails: '',
      pickupLat: 0,
      pickupLng: 0,
      deliveryLat: 0,
      deliveryLng: 0,
      estimatedCost: 0,
      deliveryFee: 0,
      status: '',
      paymentStatus: '',
      paymentMethod: '',
      paymentSource: 'wallet',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'] ?? '',
      requesterId: json['requester_id'] ?? '',
      runnerId: json['runner_id'],
      itemDetails: json['item_details'] ?? '',
      pickupLat: (json['pickup_lat'] ?? 0).toDouble(),
      pickupLng: (json['pickup_lng'] ?? 0).toDouble(),
      deliveryLat: (json['delivery_lat'] ?? 0).toDouble(),
      deliveryLng: (json['delivery_lng'] ?? 0).toDouble(),
      estimatedCost: (json['estimated_cost'] ?? 0).toDouble(),
      deliveryFee: (json['delivery_fee'] ?? 0).toDouble(),
      status: json['status'] ?? 'pending',
      paymentStatus: json['payment_status'] ?? 'unpaid',
      paymentMethod: json['payment_method'] ?? 'escrow',
      createdAt: DateTime.parse(json['created_at']).toLocal(),
      updatedAt: DateTime.parse(json['updated_at']).toLocal(),
      receiptImageUrl: json['receipt_image_url'],
      deliveryImageUrl: json['delivery_image_url'],
      disputeReason: json['dispute_reason'],
      disputeProofUrl: json['dispute_proof_url'],
      disputedAt: json['disputed_at'] != null ? DateTime.parse(json['disputed_at']).toLocal() : null,
      adjustedCost: (json['adjusted_cost'] ?? 0).toDouble(),
      adjustmentReason: json['adjustment_reason'],
      adjustmentStatus: json['adjustment_status'] != null
          ? (json['adjustment_status'] == 'accepted'
              ? 'APPROVED'
              : json['adjustment_status'].toString().toUpperCase())
          : null,
      weightKg: (json['weight_kg'] ?? 0).toDouble(),
      volumeLiters: (json['volume_liters'] ?? 0).toDouble(),
      serviceFee: (json['service_fee'] ?? 0).toDouble(),
      tripId: json['trip_id'],
      totalPayment: (json['total_payment'] ?? 0).toDouble(),
      orderType: json['order_type'] ?? 'regular',
      checkingFee: (json['checking_fee'] ?? 0).toDouble(),
      serviceCategory: json['service_category'] ?? 'beli',
      receiverName: json['receiver_name'],
      receiverPhone: json['receiver_phone'],
      deliveryName: json['delivery_name'],
      deliveryAddress: json['delivery_address'],
      pickupName: json['pickup_name'],
      pickupAddress: json['pickup_address'],
      distanceKm: (json['distance_km'] ?? 0).toDouble(),
      completionCode: json['completion_code'],
      feedbackRating: json['feedback_rating'],
      feedbackComment: json['feedback_comment'],
      paymentSource: json['payment_source'] ?? 'wallet',
      qrisData: json['qris_data'],
    );
  }

  OrderModel copyWith({
    String? status,
    String? paymentStatus,
    String? completionCode,
  }) {
    return OrderModel(
      id: id,
      requesterId: requesterId,
      runnerId: runnerId,
      itemDetails: itemDetails,
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      deliveryLat: deliveryLat,
      deliveryLng: deliveryLng,
      estimatedCost: estimatedCost,
      deliveryFee: deliveryFee,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentMethod: paymentMethod,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      receiptImageUrl: receiptImageUrl,
      deliveryImageUrl: deliveryImageUrl,
      disputeReason: disputeReason,
      disputeProofUrl: disputeProofUrl,
      disputedAt: disputedAt,
      adjustedCost: adjustedCost,
      adjustmentReason: adjustmentReason,
      adjustmentStatus: adjustmentStatus,
      weightKg: weightKg,
      volumeLiters: volumeLiters,
      serviceFee: serviceFee,
      tripId: tripId,
      totalPayment: totalPayment,
      orderType: orderType,
      checkingFee: checkingFee,
      serviceCategory: serviceCategory,
      receiverName: receiverName,
      receiverPhone: receiverPhone,
      deliveryName: deliveryName,
      deliveryAddress: deliveryAddress,
      pickupName: pickupName,
      pickupAddress: pickupAddress,
      distanceKm: distanceKm,
      completionCode: completionCode ?? this.completionCode,
      feedbackRating: feedbackRating,
      feedbackComment: feedbackComment,
      paymentSource: paymentSource,
      qrisData: qrisData,
    );
  }

  String get formattedCreatedAt => DateFormat('dd MMM yyyy, HH:mm').format(createdAt);
  
  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isCooking => status == 'cooking';
  bool get isReady => status == 'ready';
  bool get isPurchasing => status == 'purchasing';
  bool get isDelivering => status == 'delivering';
  bool get isOnProgress => status == 'on_progress' || status == 'purchasing' || status == 'delivering' || status == 'cooking' || status == 'ready';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';
  bool get isDisputed => status == 'disputed';
  bool get isProcessing => !isCompleted && !isCancelled && !isDisputed;
}
