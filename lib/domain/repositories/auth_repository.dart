import '../models/user_model.dart';

abstract class AuthRepository {
  Future<Map<String, dynamic>> login(String email, String password, String deviceId);
  Future<User> register({
    required String name,
    required String email,
    required String password,
    required String role,
    required String whatsappNumber,
    required String deviceId,
  });
  Future<User> getMe();
  Future<void> setupPin(String pin);
  Future<void> verifyPin(String pin);
  Future<void> changePin(String oldPin, String newPin);
  Future<void> updateAcceptingOrders(bool isAccepting);
  Future<void> updateLocation(double lat, double lng);
  Future<void> updateProfile({
    required String name,
    required String whatsappNumber,
    String? homeAddress,
    String? avatarPath,
  });
  Future<Map<String, dynamic>> getPublicConfig();
}
