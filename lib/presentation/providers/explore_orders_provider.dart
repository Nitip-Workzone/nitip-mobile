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
  DateTime? _lastFetchTime;

  ExploreOrdersNotifier(this._orderRepo, this._ref) : super(ExploreOrdersState());

  Future<void> fetchAvailableOrders({bool syncLocation = false, bool force = false}) async {
    final now = DateTime.now();
    // Avoid overlapping fetches within a short window (800ms) to prevent double/quadruple hits
    if (state.isLoading && !force) {
      return;
    }
    if (_lastFetchTime != null && now.difference(_lastFetchTime!) < const Duration(milliseconds: 800)) {
      return;
    }
    _lastFetchTime = now;
    final hasData = state.availableOrders.isNotEmpty;
    state = state.copyWith(isLoading: !hasData || force, error: null);
    try {
      // Low burden: only sync location on initial or explicit request, not every SSE trigger (location already via pool SSE + heartbeat)
      if (syncLocation) {
        try {
          final location = await _ref.read(userLocationProvider.notifier).locationService.getCurrentPosition().timeout(const Duration(seconds: 4));
          if (location != null) {
            await _ref.read(authRepositoryProvider).updateLocation(location.latitude, location.longitude);
          }
        } catch (_) {
          // ignore location errors – still fetch pool
        }
      }

      final orders = await _orderRepo.getAvailableOrders();
      // Defensive filter: only actionable statuses should appear in pool
      // Backend should already filter, but keep UI safe if backend leaks
      const allowedStatuses = {
        'pending',
        'merchant_accepted',
        'accepted',
        'cooking',
        'ready',
      };
      final filtered = orders.where((o) => allowedStatuses.contains(o.status.toLowerCase())).toList();
      state = state.copyWith(isLoading: false, availableOrders: filtered);
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
