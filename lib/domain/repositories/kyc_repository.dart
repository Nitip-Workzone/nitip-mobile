import 'dart:io';

abstract class KycRepository {
  Future<Map<String, dynamic>> submitKyc({
    required String idCardNumber,
    required File idCardImage,
    required File selfieImage,
  });

  Future<Map<String, dynamic>?> getKycStatus();
}
