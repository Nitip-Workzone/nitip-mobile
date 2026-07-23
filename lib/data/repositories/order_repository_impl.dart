import 'package:dio/dio.dart';
import '../../domain/models/order_model.dart';
import '../../domain/repositories/order_repository.dart';
import '../network/api_client.dart';

class OrderRepositoryImpl implements OrderRepository {
  final ApiClient _apiClient;

  OrderRepositoryImpl(this._apiClient);

  @override
  Future<List<OrderModel>> getMyOrders({int page = 1, int limit = 15}) async {
    final response = await _apiClient.dio.get(
      '/orders/me',
      queryParameters: {'page': page, 'limit': limit},
    );
    final apiResponse = ApiResponse.fromJson(
      response.data,
      (data) => (data as List).map((e) => OrderModel.fromJson(e)).toList(),
    );
    return apiResponse.data ?? [];
  }

  @override
  Future<OrderModel> getOrderById(String id) async {
    final response = await _apiClient.dio.get('/orders/$id');
    final apiResponse = ApiResponse.fromJson(
      response.data,
      (data) => OrderModel.fromJson(data),
    );
    if (apiResponse.data == null) throw Exception(apiResponse.message);
    return apiResponse.data!;
  }

  @override
  Future<OrderModel> createOrder(Map<String, dynamic> data) async {
    final response = await _apiClient.dio.post('/orders', data: data);
    final apiResponse = ApiResponse.fromJson(
      response.data,
      (data) => OrderModel.fromJson(data),
    );
    if (apiResponse.data == null) throw Exception(apiResponse.message);
    return apiResponse.data!;
  }

  @override
  Future<void> cancelOrder(String id) async {
    final response = await _apiClient.dio.post('/orders/$id/cancel');
    final apiResponse = ApiResponse.fromJson(response.data, (data) => data);
    if (!apiResponse.success) throw Exception(apiResponse.message);
  }

  @override
  Future<List<OrderModel>> getAvailableOrders() async {
    final response = await _apiClient.dio.get('/orders/available');
    final apiResponse = ApiResponse.fromJson(
      response.data,
      (data) => (data as List).map((e) => OrderModel.fromJson(e)).toList(),
    );
    return apiResponse.data ?? [];
  }

  @override
  Future<void> acceptOrder(String id) async {
    final response = await _apiClient.dio.post('/orders/$id/accept');
    final apiResponse = ApiResponse.fromJson(response.data, (data) => data);
    if (!apiResponse.success) throw Exception(apiResponse.message);
  }

  @override
  Future<void> purchaseOrder(String id, String receiptPath) async {
    final formData = FormData.fromMap({
      'receipt': await MultipartFile.fromFile(
        receiptPath,
        filename: receiptPath.split('/').last,
      ),
    });
    final response = await _apiClient.dio.post('/orders/$id/purchased', data: formData);
    final apiResponse = ApiResponse.fromJson(response.data, (data) => data);
    if (!apiResponse.success) throw Exception(apiResponse.message);
  }

  @override
  Future<void> adjustPrice(String id, double adjustedCost, String reason) async {
    final response = await _apiClient.dio.post('/orders/$id/adjust-price', data: {
      'adjusted_cost': adjustedCost,
      'reason': reason,
    });
    final apiResponse = ApiResponse.fromJson(response.data, (data) => data);
    if (!apiResponse.success) throw Exception(apiResponse.message);
  }

  @override
  Future<void> approveAdjustment(String id) async {
    final response = await _apiClient.dio.post('/orders/$id/approve-adjustment');
    final apiResponse = ApiResponse.fromJson(response.data, (data) => data);
    if (!apiResponse.success) throw Exception(apiResponse.message);
  }

  @override
  Future<void> pickupOrder(String id) async {
    final response = await _apiClient.dio.post('/orders/$id/pickup');
    final apiResponse = ApiResponse.fromJson(response.data, (data) => data);
    if (!apiResponse.success) throw Exception(apiResponse.message);
  }

  @override
  Future<void> completeOrder(String id, String completionCode, String deliveryImagePath) async {
    final formData = FormData.fromMap({
      'completion_code': completionCode,
    });
    if (deliveryImagePath.isNotEmpty) {
      formData.files.add(MapEntry(
        'delivery_image',
        await MultipartFile.fromFile(
          deliveryImagePath,
          filename: deliveryImagePath.split('/').last,
        ),
      ));
    }
    final response = await _apiClient.dio.post('/orders/$id/complete', data: formData);
    final apiResponse = ApiResponse.fromJson(response.data, (data) => data);
    if (!apiResponse.success) throw Exception(apiResponse.message);
  }

  @override
  Future<Map<String, dynamic>> estimateFee(Map<String, dynamic> data) async {
    final response = await _apiClient.dio.post('/orders/estimate-fee', data: data);
    final apiResponse = ApiResponse.fromJson(response.data, (data) => data as Map<String, dynamic>);
    if (apiResponse.data == null) throw Exception(apiResponse.message);
    return apiResponse.data!;
  }
}
