import '../../data/models/review_model.dart';

abstract class ReviewRepository {
  Future<ReviewModel?> getReview(String orderId);
  Future<ReviewModel> submitRequesterReview(String orderId, int rating, String? comment);
}
