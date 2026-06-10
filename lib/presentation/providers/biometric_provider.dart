import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BiometricState {
  final bool isSupported;
  final bool canAuthenticate;
  final bool isEnabled;
  final List<BiometricType> availableBiometrics;

  BiometricState({
    this.isSupported = false,
    this.canAuthenticate = false,
    this.isEnabled = false,
    this.availableBiometrics = const [],
  });

  BiometricState copyWith({
    bool? isSupported,
    bool? canAuthenticate,
    bool? isEnabled,
    List<BiometricType>? availableBiometrics,
  }) {
    return BiometricState(
      isSupported: isSupported ?? this.isSupported,
      canAuthenticate: canAuthenticate ?? this.canAuthenticate,
      isEnabled: isEnabled ?? this.isEnabled,
      availableBiometrics: availableBiometrics ?? this.availableBiometrics,
    );
  }
}

class BiometricNotifier extends StateNotifier<BiometricState> {
  final LocalAuthentication _auth = LocalAuthentication();
  final _storage = const FlutterSecureStorage();

  BiometricNotifier() : super(BiometricState()) {
    _init();
  }

  Future<void> _init() async {
    final isSupported = await _auth.isDeviceSupported();
    final canAuthenticate = await _auth.canCheckBiometrics;
    final availableBiometrics = await _auth.getAvailableBiometrics();
    
    // Check if user has enabled it in settings
    final isEnabledStr = await _storage.read(key: 'biometric_enabled');
    final isEnabled = isEnabledStr == 'true';

    state = state.copyWith(
      isSupported: isSupported,
      canAuthenticate: canAuthenticate,
      availableBiometrics: availableBiometrics,
      isEnabled: isEnabled,
    );
  }

  Future<void> toggleEnabled(bool enabled, {String? pin}) async {
    if (enabled && pin != null) {
      await _storage.write(key: 'biometric_enabled', value: 'true');
      await _storage.write(key: 'saved_pin', value: pin);
      state = state.copyWith(isEnabled: true);
    } else {
      await _storage.write(key: 'biometric_enabled', value: 'false');
      await _storage.delete(key: 'saved_pin');
      state = state.copyWith(isEnabled: false);
    }
  }

  Future<String?> getSavedPin() async {
    return await _storage.read(key: 'saved_pin');
  }

  Future<bool> authenticate({String reason = 'Silakan verifikasi identitas Anda'}) async {
    if (!state.canAuthenticate) return false;

    try {
      final authenticated = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
      return authenticated;
    } on PlatformException catch (e) {
      debugPrint('Biometric error: $e');
      return false;
    }
  }
}

final biometricProvider = StateNotifierProvider<BiometricNotifier, BiometricState>((ref) {
  return BiometricNotifier();
});
