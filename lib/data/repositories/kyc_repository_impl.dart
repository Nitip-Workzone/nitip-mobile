import 'dart:io';
import 'package:dio/dio.dart';
import '../../domain/repositories/kyc_repository.dart';
import '../network/api_client.dart';

class KycRepositoryImpl implements KycRepository {
  final ApiClient _apiClient;

  KycRepositoryImpl(this._apiClient);

  @override
  Future<Map<String, dynamic>> submitKyc({
    required String idCardNumber,
    required File idCardImage,
    required File selfieImage,
  }) async {
    try {
      final formData = FormData.fromMap({
        'id_card_number': idCardNumber,
        'id_card': await MultipartFile.fromFile(
          idCardImage.path,
          filename: 'id_card.jpg',
        ),
        'selfie': await MultipartFile.fromFile(
          selfieImage.path,
          filename: 'selfie.jpg',
        ),
      });

      final response = await _apiClient.dio.post(
        '/kyc/submit',
        data: formData,
      );

      return response.data;
    } on DioException catch (e) {
      final message = e.response?.data['message'] ?? 'Gagal mengirim data verifikasi';
      throw Exception(message);
    } catch (e) {
      throw Exception('Terjadi kesalahan sistem: $e');
    }
  }

  @override
  Future<Map<String, dynamic>?> getKycStatus() async {
    try {
      final response = await _apiClient.dio.get('/kyc/me');
      if (response.data != null && response.data['success'] == true) {
        return response.data['data'];
      }
      return null;
    } catch (e) {
      // If 404, means no KYC submitted yet
      if (e is DioException && e.response?.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }
}
