import 'package:dio/dio.dart';
import '../../domain/models/user_model.dart';
import '../../domain/repositories/auth_repository.dart';
import '../network/api_client.dart';

class AuthRepositoryImpl implements AuthRepository {
  final ApiClient apiClient;

  AuthRepositoryImpl(this.apiClient);

  @override
  Future<Map<String, dynamic>> login(String email, String password, String deviceId) async {
    try {
      // Step 1: Get grant token (HMAC signature)
      final grantToken = await apiClient.getGrantTokenForLogin();
      if (grantToken == null) {
        throw Exception('Gagal mendapatkan grant token. Pastikan API credentials dikonfigurasi.');
      }

      // Step 2: Login with grant token
      final response = await apiClient.dio.post(
        '/auth/login',
        data: {
          'email': email,
          'password': password,
          'device_id': deviceId,
        },
        options: Options(
          headers: {'X-Grant-Token': grantToken},
        ),
      );

      if (response.data['success'] == true) {
        final data = response.data['data'];
        return {
          'token': data['token'],
          'refresh_token': data['refresh_token'],
          'user': User.fromJson(data['user']),
        };
      } else {
        throw Exception(response.data['message'] ?? 'Login gagal');
      }
    } on DioException catch (e) {
      final message = e.response?.data['message'] ?? 'Terjadi kesalahan jaringan';
      throw Exception(message);
    }
  }

  @override
  Future<void> verifyPin(String pin) async {
    try {
      final response = await apiClient.dio.post('/users/pin/verify', data: {
        'pin': pin,
      });

      if (response.data['success'] != true) {
        throw Exception(response.data['message'] ?? 'Verifikasi PIN gagal');
      }
    } on DioException catch (e) {
      final message = e.response?.data['message'] ?? 'Terjadi kesalahan jaringan';
      throw Exception(message);
    }
  }

  @override
  Future<void> changePin(String oldPin, String newPin) async {
    try {
      final response = await apiClient.dio.post('/users/pin/change', data: {
        'old_pin': oldPin,
        'new_pin': newPin,
      });

      if (response.data['success'] != true) {
        throw Exception(response.data['message'] ?? 'Gagal mengubah PIN');
      }
    } on DioException catch (e) {
      final message = e.response?.data['message'] ?? 'Terjadi kesalahan jaringan';
      throw Exception(message);
    }
  }

  @override
  Future<User> register({
    required String name,
    required String email,
    required String password,
    required String role,
    required String whatsappNumber,
    required String deviceId,
  }) async {
    try {
      final response = await apiClient.dio.post('/users/register', data: {
        'name': name,
        'email': email,
        'password': password,
        'role': role,
        'whatsapp_number': whatsappNumber,
        'device_id': deviceId,
      });

      if (response.data['success'] == true) {
        return User.fromJson(response.data['data']);
      } else {
        throw Exception(response.data['message'] ?? 'Registrasi gagal');
      }
    } on DioException catch (e) {
      final message = e.response?.data['message'] ?? 'Terjadi kesalahan jaringan';
      throw Exception(message);
    }
  }

  @override
  Future<User> getMe() async {
    try {
      final response = await apiClient.dio.get('/users/me');

      if (response.data['success'] == true) {
        return User.fromJson(response.data['data']);
      } else {
        throw Exception(response.data['message'] ?? 'Gagal mengambil data profil');
      }
    } on DioException catch (e) {
      final message = e.response?.data['message'] ?? 'Terjadi kesalahan jaringan';
      throw Exception(message);
    }
  }

  @override
  Future<void> setupPin(String pin) async {
    try {
      final response = await apiClient.dio.post('/users/pin/setup', data: {
        'pin': pin,
      });

      if (response.data['success'] != true) {
        throw Exception(response.data['message'] ?? 'Gagal mengatur PIN');
      }
    } on DioException catch (e) {
      final message = e.response?.data['message'] ?? 'Terjadi kesalahan jaringan';
      throw Exception(message);
    }
  }

  @override
  Future<void> updateAcceptingOrders(bool isAccepting) async {
    try {
      final response = await apiClient.dio.put('/users/accepting-orders', data: {
        'is_accepting_orders': isAccepting,
      });

      if (response.data['success'] != true) {
        throw Exception(response.data['message'] ?? 'Gagal memperbarui status');
      }
    } on DioException catch (e) {
      final message = e.response?.data['message'] ?? 'Terjadi kesalahan jaringan';
      throw Exception(message);
    }
  }

  @override
  Future<void> updateLocation(double lat, double lng) async {
    try {
      await apiClient.dio.get('/users/me', options: Options(
        headers: {
          'X-Location': '$lat,$lng',
        },
      ));
    } catch (_) {
      // Silently fail for passive location updates
    }
  }

  @override
  Future<void> updateProfile({
    required String name,
    required String whatsappNumber,
    String? homeAddress,
    String? avatarPath,
  }) async {
    try {
      final Map<String, dynamic> formDataMap = {
        'name': name,
        'whatsapp_number': whatsappNumber,
      };

      if (homeAddress != null) {
        formDataMap['home_address'] = homeAddress;
      }

      if (avatarPath != null) {
        formDataMap['avatar'] = await MultipartFile.fromFile(
          avatarPath,
          filename: avatarPath.split('/').last,
        );
      }

      final formData = FormData.fromMap(formDataMap);

      final response = await apiClient.dio.put(
        '/users/profile',
        data: formData,
      );

      if (response.data['success'] != true) {
        throw Exception(response.data['message'] ?? 'Gagal memperbarui profil');
      }
    } on DioException catch (e) {
      final message = e.response?.data['message'] ?? 'Terjadi kesalahan jaringan';
      throw Exception(message);
    }
  }

  @override
  Future<Map<String, dynamic>> getPublicConfig() async {
    try {
      final response = await apiClient.dio.get('/configs/public');
      return response.data['data'] as Map<String, dynamic>;
    } on DioException catch (e) {
      final message = e.response?.data['message'] ?? 'Terjadi kesalahan jaringan';
      throw Exception(message);
    }
  }
}
