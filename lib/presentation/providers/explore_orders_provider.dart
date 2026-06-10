import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/order_model.dart';
import '../../domain/repositories/order_repository.dart';
import 'activity_provider.dart';
import 'auth_provider.dart';
import 'location_provider.dart';

class ExploreOrdersState {
  final bool isLoading;
  final List<OrderModel> availableOrders;
  final String? error;

  ExploreOrdersState({
    this.isLoading = false,
    this.availableOrders = const [],
    this.error,
  });

  ExploreOrdersState copyWith({
    bool? isLoading,
    List<OrderModel>? availableOrders,
    String? error,
  }) {
    return ExploreOrdersState(
      isLoading: isLoading ?? this.isLoading,
      availableOrders: availableOrders ?? this.availableOrders,
      error: error,
    );
  }
}

class ExploreOrdersNotifier extends StateNotifier<ExploreOrdersState> {
  final OrderRepository _orderRepo;
  final Ref _ref;

  ExploreOrdersNotifier(this._orderRepo, this._ref) : super(ExploreOrdersState());

  Future<void> fetchAvailableOrders() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // Sync location first to ensure backend proximity matching works
      final location = await _ref.read(userLocationProvider.notifier).locationService.getCurrentPosition();
      if (location != null) {
        await _ref.read(authRepositoryProvider).updateLocation(location.latitude, location.longitude);
      }

      final orders = await _orderRepo.getAvailableOrders();
      state = state.copyWith(isLoading: false, availableOrders: orders);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> acceptOrder(String orderId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _orderRepo.acceptOrder(orderId);
      // Refresh activities to show the newly accepted order in "My Trips/Orders"
      await _ref.read(activityProvider.notifier).fetchActivities();
      // Remove from available list
      final updatedOrders = state.availableOrders.where((o) => o.id != orderId).toList();
      state = state.copyWith(isLoading: false, availableOrders: updatedOrders);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }
}

final exploreOrdersProvider = StateNotifierProvider<ExploreOrdersNotifier, ExploreOrdersState>((ref) {
  final orderRepo = ref.watch(orderRepositoryProvider);
  return ExploreOrdersNotifier(orderRepo, ref);
});
