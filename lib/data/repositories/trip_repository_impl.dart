import '../../domain/models/trip_model.dart';
import '../../domain/repositories/trip_repository.dart';
import '../network/api_client.dart';

class TripRepositoryImpl implements TripRepository {
  final ApiClient _apiClient;

  TripRepositoryImpl(this._apiClient);

  @override
  Future<List<TripModel>> getMyTrips() async {
    final response = await _apiClient.dio.get('/trips/me');
    final apiResponse = ApiResponse.fromJson(
      response.data,
      (data) => (data as List).map((e) => TripModel.fromJson(e)).toList(),
    );
    return apiResponse.data ?? [];
  }

  @override
  Future<TripModel> createTrip(Map<String, dynamic> data) async {
    final response = await _apiClient.dio.post('/trips', data: data);
    final apiResponse = ApiResponse.fromJson(
      response.data,
      (data) => TripModel.fromJson(data),
    );
    if (apiResponse.data == null) throw Exception(apiResponse.message);
    return apiResponse.data!;
  }

  @override
  Future<void> startTrip(String id) async {
    final response = await _apiClient.dio.post('/trips/$id/start');
    final apiResponse = ApiResponse.fromJson(response.data, (data) => data);
    if (!apiResponse.success) throw Exception(apiResponse.message);
  }

  @override
  Future<void> cancelTrip(String id) async {
    final response = await _apiClient.dio.post('/trips/$id/cancel');
    final apiResponse = ApiResponse.fromJson(response.data, (data) => data);
    if (!apiResponse.success) throw Exception(apiResponse.message);
  }

  @override
  Future<void> completeTrip(String id) async {
    final response = await _apiClient.dio.post('/trips/$id/complete');
    final apiResponse = ApiResponse.fromJson(response.data, (data) => data);
    if (!apiResponse.success) throw Exception(apiResponse.message);
  }
}
