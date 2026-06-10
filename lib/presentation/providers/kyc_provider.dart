import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/kyc_repository_impl.dart';
import '../../domain/repositories/kyc_repository.dart';
import 'auth_provider.dart';

final kycRepositoryProvider = Provider<KycRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return KycRepositoryImpl(apiClient);
});

class KycState {
  final bool isLoading;
  final String? error;
  final bool isSuccess;

  KycState({
    this.isLoading = false,
    this.error,
    this.isSuccess = false,
  });

  KycState copyWith({
    bool? isLoading,
    String? error,
    bool? isSuccess,
  }) {
    return KycState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }
}

class KycNotifier extends StateNotifier<KycState> {
  final KycRepository _repository;
  final Ref _ref;

  KycNotifier(this._repository, this._ref) : super(KycState());

  Future<void> submit({
    required String idCardNumber,
    required String idCardPath,
    required String selfiePath,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.submitKyc(
        idCardNumber: idCardNumber,
        idCardImage: File(idCardPath),
        selfieImage: File(selfiePath),
      );
      
      state = state.copyWith(isLoading: false, isSuccess: true);
      
      // Refresh user profile and kyc status in AuthProvider
      await _ref.read(authProvider.notifier).refreshProfile();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }
}

final kycProvider = StateNotifierProvider<KycNotifier, KycState>((ref) {
  final repository = ref.watch(kycRepositoryProvider);
  return KycNotifier(repository, ref);
});
