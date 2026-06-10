import 'package:dio/dio.dart';
import '../../data/models/review_model.dart';
import '../../domain/repositories/review_repository.dart';
import '../network/api_client.dart';

class ReviewRepositoryImpl implements ReviewRepository {
  final ApiClient _apiClient;

  ReviewRepositoryImpl(this._apiClient);

  @override
  Future<ReviewModel?> getReview(String orderId) async {
    try {
      final response = await _apiClient.dio.get('/orders/$orderId/review');
      if (response.data['success'] == true && response.data['data'] != null) {
        return ReviewModel.fromJson(response.data['data']);
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      final message = e.response?.data['message'] ?? 'Terjadi kesalahan jaringan';
      throw Exception(message);
    }
  }

  @override
  Future<ReviewModel> submitReview(String orderId, int rating, String? comment) async {
    try {
      final body = <String, dynamic>{
        'rating': rating,
      };
      if (comment != null && comment.isNotEmpty) {
        body['comment'] = comment;
      }

      final response = await _apiClient.dio.post('/orders/$orderId/review', data: body);

      if (response.data['success'] == true && response.data['data'] != null) {
        return ReviewModel.fromJson(response.data['data']);
      } else {
        throw Exception(response.data['message'] ?? 'Gagal mengirim review');
      }
    } on DioException catch (e) {
      final message = e.response?.data['message'] ?? 'Terjadi kesalahan jaringan';
      throw Exception(message);
    }
  }
}
