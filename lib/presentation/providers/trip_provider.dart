import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/trip_model.dart';
import '../../domain/repositories/trip_repository.dart';
import '../../data/repositories/trip_repository_impl.dart';
import 'auth_provider.dart';

final tripRepositoryProvider = Provider<TripRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return TripRepositoryImpl(apiClient);
});

class TripState {
  final bool isLoading;
  final bool hasFetched;
  final String? error;
  final List<TripModel> myTrips;

  TripState({
    this.isLoading = false,
    this.hasFetched = false,
    this.error,
    this.myTrips = const [],
  });

  List<TripModel> get activeTrips => myTrips.where((t) => t.status == 'active' || t.status == 'started').toList();
  TripModel? get currentTrip => activeTrips.isNotEmpty ? activeTrips.first : null;

  TripState copyWith({
    bool? isLoading,
    bool? hasFetched,
    String? error,
    List<TripModel>? myTrips,
  }) {
    return TripState(
      isLoading: isLoading ?? this.isLoading,
      hasFetched: hasFetched ?? this.hasFetched,
      error: error,
      myTrips: myTrips ?? this.myTrips,
    );
  }
}

class TripNotifier extends StateNotifier<TripState> {
  final TripRepository _tripRepo;

  TripNotifier(this._tripRepo) : super(TripState());

  Future<void> fetchMyTrips({bool force = false}) async {
    if (state.hasFetched && !force && !state.isLoading) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final trips = await _tripRepo.getMyTrips();
      state = state.copyWith(
        isLoading: false,
        hasFetched: true,
        myTrips: trips,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> createTrip(Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final newTrip = await _tripRepo.createTrip(data);
      state = state.copyWith(
        isLoading: false,
        myTrips: [newTrip, ...state.myTrips],
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> startTrip(String id) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _tripRepo.startTrip(id);
      final updated = state.myTrips.map((t) {
        if (t.id == id) {
          return t.copyWith(status: 'started');
        }
        return t;
      }).toList();
      state = state.copyWith(isLoading: false, myTrips: updated);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> cancelTrip(String id) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _tripRepo.cancelTrip(id);
      final updated = state.myTrips.map((t) {
        if (t.id == id) {
          return t.copyWith(status: 'cancelled');
        }
        return t;
      }).toList();
      state = state.copyWith(isLoading: false, myTrips: updated);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> completeTrip(String id) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _tripRepo.completeTrip(id);
      final updated = state.myTrips.map((t) {
        if (t.id == id) {
          return t.copyWith(status: 'completed');
        }
        return t;
      }).toList();
      state = state.copyWith(isLoading: false, myTrips: updated);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }
}

final tripProvider = StateNotifierProvider<TripNotifier, TripState>((ref) {
  final repo = ref.watch(tripRepositoryProvider);
  final notifier = TripNotifier(repo);
  // Auto-fetch on initialization
  notifier.fetchMyTrips();
  return notifier;
});
