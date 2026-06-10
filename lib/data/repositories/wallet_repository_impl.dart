import 'package:dio/dio.dart';
import '../../domain/models/wallet_model.dart';
import '../../domain/repositories/wallet_repository.dart';
import '../network/api_client.dart';

class WalletRepositoryImpl implements WalletRepository {
  final ApiClient apiClient;

  WalletRepositoryImpl(this.apiClient);

  @override
  Future<WalletModel> getBalance() async {
    final response = await apiClient.dio.get('/wallets/balance');
    final apiResponse = ApiResponse.fromJson(
      response.data,
      (data) => WalletModel.fromJson(data),
    );
    if (apiResponse.data == null) {
      throw Exception(apiResponse.message);
    }
    return apiResponse.data!;
  }

  @override
  Future<List<WalletTransactionModel>> getTransactions({int page = 1, int limit = 20}) async {
    try {
      final response = await apiClient.dio.get(
        '/wallets/transactions',
        queryParameters: {'page': page, 'limit': limit},
      );
      if (response.data['success'] == true) {
        final List list = response.data['data'] ?? [];
        return list.map((e) => WalletTransactionModel.fromJson(e)).toList();
      } else {
        throw Exception(response.data['message'] ?? 'Gagal mengambil riwayat transaksi');
      }
    } on DioException catch (e) {
      final message = e.response?.data['message'] ?? 'Terjadi kesalahan jaringan';
      throw Exception(message);
    }
  }

  @override
  Future<WalletTransactionModel> initiateTopUp(double amount) async {
    try {
      final response = await apiClient.dio.post('/wallets/topup', data: {'amount': amount});
      if (response.data['success'] == true) {
        return WalletTransactionModel.fromJson(response.data['data']);
      } else {
        throw Exception(response.data['message'] ?? 'Gagal melakukan top up');
      }
    } on DioException catch (e) {
      final message = e.response?.data['message'] ?? 'Terjadi kesalahan jaringan';
      throw Exception(message);
    }
  }

  @override
  Future<WalletTransactionModel> getTransactionStatus(String reference) async {
    try {
      final response = await apiClient.dio.get(
        '/wallets/transactions/status',
        queryParameters: {'reference': reference},
      );
      if (response.data['success'] == true) {
        return WalletTransactionModel.fromJson(response.data['data']);
      } else {
        throw Exception(response.data['message'] ?? 'Transaksi tidak ditemukan');
      }
    } on DioException catch (e) {
      final message = e.response?.data['message'] ?? 'Terjadi kesalahan jaringan';
      throw Exception(message);
    }
  }

  @override
  Future<List<WithdrawalChannelModel>> getWithdrawalChannels() async {
    try {
      final response = await apiClient.dio.get('/wallets/withdrawal-channels');
      if (response.data['success'] == true) {
        final List list = response.data['data'] ?? [];
        return list.map((e) => WithdrawalChannelModel.fromJson(e)).toList();
      } else {
        throw Exception(response.data['message'] ?? 'Gagal mengambil metode penarikan');
      }
    } on DioException catch (e) {
      final message = e.response?.data['message'] ?? 'Terjadi kesalahan jaringan';
      throw Exception(message);
    }
  }

  @override
  Future<String> inquiryAccount({
    required String channelCode,
    required String accountNo,
  }) async {
    try {
      final response = await apiClient.dio.post('/wallets/withdraw/inquiry', data: {
        'channel_code': channelCode,
        'account_no': accountNo,
      });
      if (response.data['success'] == true) {
        return response.data['data']['account_name'];
      } else {
        throw Exception(response.data['message'] ?? 'Gagal memverifikasi rekening');
      }
    } on DioException catch (e) {
      final message = e.response?.data['message'] ?? 'Terjadi kesalahan jaringan';
      throw Exception(message);
    }
  }

  @override
  Future<WalletTransactionModel> requestWithdrawal({
    required double amount,
    required String channelId,
    required String pin,
    required Map<String, dynamic> metadata,
  }) async {
    try {
      final response = await apiClient.dio.post('/wallets/withdraw', data: {
        'amount': amount,
        'channel_id': channelId,
        'pin': pin,
        'metadata': metadata,
      });
      if (response.data['success'] == true) {
        return WalletTransactionModel.fromJson(response.data['data']);
      } else {
        throw Exception(response.data['message'] ?? 'Gagal melakukan penarikan');
      }
    } on DioException catch (e) {
      final message = e.response?.data['message'] ?? 'Terjadi kesalahan jaringan';
      throw Exception(message);
    }
  }
}
