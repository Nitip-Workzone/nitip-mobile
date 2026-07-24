class ReviewModel {
  final String id;
  final String orderId;
  final String reviewerId;
  final String runnerId;
  final int? runnerRating;
  final String? runnerComment;
  final String? merchantId;
  final int? merchantRating;
  final String? merchantComment;
  final String? requesterId;
  final int? requesterRating;
  final String? requesterComment;
  final DateTime createdAt;

  ReviewModel({
    required this.id,
    required this.orderId,
    required this.reviewerId,
    required this.runnerId,
    this.runnerRating,
    this.runnerComment,
    this.merchantId,
    this.merchantRating,
    this.merchantComment,
    this.requesterId,
    this.requesterRating,
    this.requesterComment,
    required this.createdAt,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      id: json['id'] ?? '',
      orderId: json['order_id'] ?? '',
      reviewerId: json['reviewer_id'] ?? '',
      runnerId: json['runner_id'] ?? '',
      runnerRating: json['runner_rating'],
      runnerComment: json['runner_comment'],
      merchantId: json['merchant_id'],
      merchantRating: json['merchant_rating'],
      merchantComment: json['merchant_comment'],
      requesterId: json['requester_id'],
      requesterRating: json['requester_rating'],
      requesterComment: json['requester_comment'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at']).toLocal()
          : DateTime.now(),
    );
  }
}
