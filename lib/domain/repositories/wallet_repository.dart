import '../models/wallet_model.dart';

abstract class WalletRepository {
  Future<WalletModel> getBalance();
  Future<List<WalletTransactionModel>> getTransactions({int page = 1, int limit = 20});
  Future<WalletTransactionModel> initiateTopUp(double amount);
  Future<WalletTransactionModel> getTransactionStatus(String reference);
  Future<List<WithdrawalChannelModel>> getWithdrawalChannels();
  Future<String> inquiryAccount({
    required String channelCode,
    required String accountNo,
  });
  Future<WalletTransactionModel> requestWithdrawal({
    required double amount,
    required String channelId,
    required String pin,
    required Map<String, dynamic> metadata,
  });
}
