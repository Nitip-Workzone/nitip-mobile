import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/tracking_repository.dart';
import '../../domain/models/tracking_state.dart';
import 'auth_provider.dart';

final trackingRepositoryProvider = Provider<TrackingRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return TrackingRepository(apiClient);
});

final orderTrackingProvider = StreamProvider.family<TrackingState, String>((ref, orderId) {
  final repo = ref.watch(trackingRepositoryProvider);
  return repo.streamOrderTracking(orderId);
});

final runnerLocationStreamingProvider = StateNotifierProvider<RunnerLocationStreamingNotifier, bool>((ref) {
  final repo = ref.watch(trackingRepositoryProvider);
  return RunnerLocationStreamingNotifier(repo, ref);
});

class RunnerLocationStreamingNotifier extends StateNotifier<bool> {
  RunnerLocationStreamingNotifier(TrackingRepository repo, Ref ref) : super(false);

  void startStreaming() {}
  void stopStreaming() {}
  void checkAndStop() {}
  void resumeIfNeeded() {}
}
