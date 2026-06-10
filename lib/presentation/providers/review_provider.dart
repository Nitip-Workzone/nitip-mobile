import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/review_model.dart';
import '../../domain/repositories/review_repository.dart';
import '../../data/repositories/review_repository_impl.dart';
import 'auth_provider.dart';

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ReviewRepositoryImpl(apiClient);
});

class ReviewState {
  final bool isLoading;
  final bool isSubmitting;
  final String? error;
  final ReviewModel? review;
  final bool submitted;

  ReviewState({
    this.isLoading = false,
    this.isSubmitting = false,
    this.error,
    this.review,
    this.submitted = false,
  });

  ReviewState copyWith({
    bool? isLoading,
    bool? isSubmitting,
    String? error,
    ReviewModel? review,
    bool? submitted,
  }) {
    return ReviewState(
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: error,
      review: review ?? this.review,
      submitted: submitted ?? this.submitted,
    );
  }
}

class ReviewNotifier extends StateNotifier<ReviewState> {
  final ReviewRepository _repository;

  ReviewNotifier(this._repository) : super(ReviewState());

  Future<void> fetchReview(String orderId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final review = await _repository.getReview(orderId);
      state = state.copyWith(isLoading: false, review: review);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> submitReview(String orderId, int rating, String? comment) async {
    state = state.copyWith(isSubmitting: true, error: null);
    try {
      final review = await _repository.submitReview(orderId, rating, comment);
      state = state.copyWith(isSubmitting: false, review: review, submitted: true);
      return true;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
      return false;
    }
  }

  void reset() {
    state = ReviewState();
  }
}

final reviewProvider = StateNotifierProvider.family<ReviewNotifier, ReviewState, String>((ref, orderId) {
  final repository = ref.watch(reviewRepositoryProvider);
  return ReviewNotifier(repository);
});
