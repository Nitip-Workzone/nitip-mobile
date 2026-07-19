import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/order_model.dart';
import '../../domain/repositories/order_repository.dart';
import '../../data/repositories/order_repository_impl.dart';
import 'auth_provider.dart';

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return OrderRepositoryImpl(apiClient);
});

class ActivityState {
  final bool isLoading;
  final bool hasFetched;
  final String? error;
  final List<OrderModel> activeOrders;
  final List<OrderModel> pastOrders;

  ActivityState({
    this.isLoading = false,
    this.hasFetched = false,
    this.error,
    this.activeOrders = const [],
    this.pastOrders = const [],
  });

  ActivityState copyWith({
    bool? isLoading,
    bool? hasFetched,
    String? error,
    List<OrderModel>? activeOrders,
    List<OrderModel>? pastOrders,
  }) {
    return ActivityState(
      isLoading: isLoading ?? this.isLoading,
      hasFetched: hasFetched ?? this.hasFetched,
      error: error,
      activeOrders: activeOrders ?? this.activeOrders,
      pastOrders: pastOrders ?? this.pastOrders,
    );
  }
}

class ActivityNotifier extends StateNotifier<ActivityState> {
  final OrderRepository _orderRepo;
  final Ref _ref;

  ActivityNotifier(this._orderRepo, this._ref) : super(ActivityState());

  Future<void>? _fetchFuture;

  void reset() {
    state = ActivityState();
    _fetchFuture = null;
  }

  Future<void> fetchActivities({bool force = false}) async {
    final authState = _ref.read(authProvider);
    if (!authState.isAuthenticated || authState.user == null) return;
    
    // 1. Skip if already fetched and not forced
    if (state.hasFetched && !force) return;

    // 2. Return existing future if already fetching
    if (_fetchFuture != null) return _fetchFuture;

    _fetchFuture = _performFetch();
    try {
      await _fetchFuture;
    } finally {
      _fetchFuture = null;
    }
  }

  Future<void> _performFetch() async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final orders = await _orderRepo.getMyOrders();
      final activeOrders = orders.where((o) => o.isProcessing).toList();
      final pastOrders = orders.where((o) => !o.isProcessing).toList();
      state = state.copyWith(
        isLoading: false,
        hasFetched: true,
        activeOrders: activeOrders,
        pastOrders: pastOrders,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, hasFetched: true, error: e.toString());
    }
  }

  Future<bool> acceptOrder(String id) async {
    try {
      await _orderRepo.acceptOrder(id);
      await fetchActivities(force: true);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> purchaseOrder(String id, String receiptPath) async {
    // Optimistic Update
    final originalOrders = state.activeOrders;
    state = state.copyWith(
      activeOrders: state.activeOrders.map((o) => o.id == id ? o.copyWith(status: 'purchasing') : o).toList(),
    );

    try {
      await _orderRepo.purchaseOrder(id, receiptPath);
      await fetchActivities(force: true);
      return true;
    } catch (e) {
      // Revert if failed
      state = state.copyWith(activeOrders: originalOrders);
      return false;
    }
  }

  Future<bool> adjustPrice(String id, double newCost, String reason) async {
    try {
      await _orderRepo.adjustPrice(id, newCost, reason);
      await fetchActivities(force: true);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> approveAdjustment(String id) async {
    try {
      await _orderRepo.approveAdjustment(id);
      await fetchActivities(force: true);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> pickupOrder(String id) async {
    // Optimistic Update
    final originalOrders = state.activeOrders;
    state = state.copyWith(
      activeOrders: state.activeOrders.map((o) => o.id == id ? o.copyWith(status: 'delivering') : o).toList(),
    );

    try {
      await _orderRepo.pickupOrder(id);
      await fetchActivities(force: true);
      return true;
    } catch (e) {
      // Revert if failed
      state = state.copyWith(activeOrders: originalOrders);
      return false;
    }
  }

  Future<bool> completeOrder(String id, String code, String imagePath) async {
    // Optimistic Update
    final originalOrders = state.activeOrders;
    state = state.copyWith(
      activeOrders: state.activeOrders.map((o) => o.id == id ? o.copyWith(status: 'completed') : o).toList(),
    );

    try {
      await _orderRepo.completeOrder(id, code, imagePath);
      await fetchActivities(force: true);
      return true;
    } catch (e) {
      debugPrint('DEBUG COMPLETE ORDER ERROR: $e');
      // Revert if failed
      state = state.copyWith(activeOrders: originalOrders);
      return false;
    }
  }
}

final activityProvider = StateNotifierProvider<ActivityNotifier, ActivityState>((ref) {
  final orderRepo = ref.watch(orderRepositoryProvider);
  return ActivityNotifier(orderRepo, ref);
});
