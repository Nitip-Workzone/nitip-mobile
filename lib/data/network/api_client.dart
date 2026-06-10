import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/config/app_config.dart';
import '../../core/services/hmac_service.dart';

class ApiClient {
  late Dio dio;
  final _storage = const FlutterSecureStorage();

  ApiClient() {
    dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-Platform': 'mobile',
        },
      ),
    );

    // Tambahkan interceptor untuk token & koneksi
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Check connectivity
        final connectivityResult = await Connectivity().checkConnectivity();
        if (connectivityResult.isEmpty || connectivityResult.contains(ConnectivityResult.none)) {
          return handler.reject(
            DioException(
              requestOptions: options,
              error: 'Tidak ada koneksi internet',
              type: DioExceptionType.connectionError,
            ),
          );
        }

        final token = await _storage.read(key: 'access_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
          debugPrint('[API_DEBUG] Request: ${options.method} ${options.path} | Token found');
        } else {
          debugPrint('[API_DEBUG] Request: ${options.method} ${options.path} | NO TOKEN FOUND in storage');
        }
        return handler.next(options);
      },
    ));

    // Tambahkan logger sederhana untuk debug
    dio.interceptors.add(LogInterceptor(
      requestBody: false,
      responseBody: false,
      logPrint: (o) => debugPrint(o.toString()),
    ));

    // Handle 401 errors for token refresh
    dio.interceptors.add(InterceptorsWrapper(
      onError: (e, handler) async {
        if (e.response?.statusCode == 401) {
          debugPrint('[API_DEBUG] 401 Unauthorized detected. Attempting refresh...');
          final refreshToken = await _storage.read(key: 'refresh_token');
          if (refreshToken != null) {
            try {
              // Step 1: Get a fresh grant token first
              final grantToken = await _getGrantToken();
              if (grantToken == null) {
                debugPrint('[API_DEBUG] Failed to get grant token for refresh.');
                await _clearSession();
                return handler.next(e);
              }

              // Step 2: Refresh with grant token
              final refreshDio = Dio(BaseOptions(
                headers: {
                  'X-Platform': 'mobile',
                  'X-Grant-Token': grantToken,
                },
              ));

              final refreshUrl = '${AppConfig.baseUrl}auth/refresh';
              debugPrint('[API_DEBUG] POST $refreshUrl (with grant token)');

              final response = await refreshDio.post(
                refreshUrl,
                data: {'refresh_token': refreshToken},
              );

              if (response.statusCode == 200) {
                final newAccessToken = response.data['data']['token'];
                final newRefreshToken = response.data['data']['refresh_token'];

                // Save new tokens
                await _storage.write(key: 'access_token', value: newAccessToken);
                await _storage.write(key: 'refresh_token', value: newRefreshToken);
                debugPrint('[API_DEBUG] Token refresh successful.');

                // Retry original request
                final opts = e.requestOptions;
                opts.headers['Authorization'] = 'Bearer $newAccessToken';

                final retryResponse = await dio.fetch(opts);
                return handler.resolve(retryResponse);
              }
            } on DioException catch (refreshErr) {
              debugPrint('[API_DEBUG] Token refresh failed: ${refreshErr.response?.statusCode} - ${refreshErr.message}');

              // Hanya hapus token jika server mengembalikan 401 atau 400 (token tidak valid/expired)
              if (refreshErr.response?.statusCode == 401 || refreshErr.response?.statusCode == 400) {
                debugPrint('[API_DEBUG] Refresh token invalid/expired. Clearing session.');
                await _clearSession();
              }
            } catch (e) {
              debugPrint('[API_DEBUG] Unexpected error during refresh: $e');
            }
          } else {
            debugPrint('[API_DEBUG] No refresh token found. User must re-login.');
          }
        }
        return handler.next(e);
      },
    ));
  }

  /// Mendapatkan grant token dari server menggunakan HMAC signature.
  /// Grant token diperlukan untuk login dan refresh.
  Future<String?> _getGrantToken() async {
    if (!AppConfig.hasApiCredentials) {
      debugPrint('[AUTH] API credentials not configured! Set API_KEY and API_SECRET via --dart-define');
      return null;
    }

    try {
      final body = '{}';
      final headers = HmacService.generateGrantHeaders(
        apiKey: AppConfig.apiKey,
        apiSecret: AppConfig.apiSecret,
        body: body,
      );

      final grantDio = Dio();
      final response = await grantDio.post(
        '${AppConfig.baseUrl}auth/grant',
        data: body,
        options: Options(headers: headers),
      );

      if (response.statusCode == 200 && response.data['data'] != null) {
        final grantToken = response.data['data']['grant_token'] as String;
        debugPrint('[AUTH] Grant token obtained successfully');
        return grantToken;
      }
    } on DioException catch (e) {
      debugPrint('[AUTH] Failed to get grant token: ${e.response?.statusCode} - ${e.message}');
    } catch (e) {
      debugPrint('[AUTH] Unexpected error getting grant token: $e');
    }
    return null;
  }

  /// Mendapatkan grant token untuk keperluan login (public access).
  Future<String?> getGrantTokenForLogin() async {
    return _getGrantToken();
  }

  Future<void> _clearSession() async {
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
  }
}

class ApiResponse<T> {
  final bool success;
  final String message;
  final T? data;
  final List<dynamic>? errors;

  ApiResponse({
    required this.success,
    required this.message,
    this.data,
    this.errors,
  });

  factory ApiResponse.fromJson(Map<String, dynamic> json, T Function(dynamic) fromJsonT) {
    return ApiResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: json['data'] != null ? fromJsonT(json['data']) : null,
      errors: json['errors'],
    );
  }
}