import 'dart:io';

abstract class KycRepository {
  Future<Map<String, dynamic>> submitKyc({
    required String facebookName,
    required File facebookScreenshot,
    required File selfieImage,
  });

  Future<Map<String, dynamic>?> getKycStatus();
}
