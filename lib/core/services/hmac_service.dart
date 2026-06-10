import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Service untuk menghitung HMAC-SHA256 signature
/// sesuai protokol autentikasi Nitip API (3-Layer Auth).
///
/// Algoritma:
/// 1. bodyHash  = SHA256(requestBody)
/// 2. payload   = timestamp + "." + bodyHash
/// 3. signature = HMAC-SHA256(payload, apiSecret)
class HmacService {
  /// Menghasilkan headers yang diperlukan untuk POST /auth/grant.
  ///
  /// Returns map berisi:
  /// - X-API-Key
  /// - X-Timestamp (RFC3339)
  /// - X-Signature (HMAC-SHA256 hex)
  static Map<String, String> generateGrantHeaders({
    required String apiKey,
    required String apiSecret,
    required String body,
  }) {
    final timestamp = DateTime.now().toUtc().toIso8601String();
    final bodyHash = sha256.convert(utf8.encode(body)).toString();
    final payload = '$timestamp.$bodyHash';

    final hmacBytes = Hmac(sha256, utf8.encode(apiSecret))
        .convert(utf8.encode(payload))
        .bytes;
    final signature = hmacBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    return {
      'X-API-Key': apiKey,
      'X-Timestamp': timestamp,
      'X-Signature': signature,
      'Content-Type': 'application/json',
    };
  }
}