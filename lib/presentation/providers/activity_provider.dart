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
  final bool isLoadingMore;
  final bool hasMore;
  final int currentPage;
  final String? error;
  final List<OrderModel> activeOrders;
  final List<OrderModel> pastOrders;
  final List<OrderModel> merchantOrders;
  final List<OrderModel> _allOrders;

  ActivityState({
    this.isLoading = false,
    this.hasFetched = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.currentPage = 1,
    this.error,
    this.activeOrders = const [],
    this.pastOrders = const [],
    this.merchantOrders = const [],
    List<OrderModel> allOrders = const [],
  }) : _allOrders = allOrders;

  ActivityState copyWith({
    bool? isLoading,
    bool? hasFetched,
    bool? isLoadingMore,
    bool? hasMore,
    int? currentPage,
    String? error,
    List<OrderModel>? allOrders,
    List<OrderModel>? merchantOrders,
  }) {
    final orders = allOrders ?? _allOrders;
    return ActivityState(
      isLoading: isLoading ?? this.isLoading,
      hasFetched: hasFetched ?? this.hasFetched,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      error: error,
      activeOrders: orders.where((o) => o.isProcessing).toList(),
      pastOrders: orders.where((o) => !o.isProcessing).toList(),
      merchantOrders: merchantOrders ?? this.merchantOrders,
      allOrders: orders,
    );
  }
}

class ActivityNotifier extends StateNotifier<ActivityState> {
  final OrderRepository _orderRepo;
  final Ref _ref;
  static const int _limit = 15;

  // Low-burden lock: once order marked completed via optimistic, never revert to earlier status from stale fetch
  final Set<String> _completedLock = {};
  final Set<String> _deliveringLock = {};

  ActivityNotifier(this._orderRepo, this._ref) : super(ActivityState());

  Future<void>? _fetchFuture;

  void reset() {
    state = ActivityState();
    _fetchFuture = null;
    _completedLock.clear();
    _deliveringLock.clear();
  }

  // Patch single order status without full fetch – used by realtime provider (low burden)
  void patchOrderStatus(String id, String newStatus) {
    final lower = newStatus.toLowerCase().trim();
    if (lower.isEmpty) return;
    // Respect completed lock
    if (_completedLock.contains(id) && lower != 'completed') {
      return; // ignore stale revert to ready/delivering
    }
    if (lower == 'completed') _completedLock.add(id);
    if (lower == 'delivering') _deliveringLock.add(id);

    final current = state._allOrders;
    final idx = current.indexWhere((o) => o.id == id);
    if (idx == -1) return; // not in current list, ignore patch (full fetch will add later if needed)
    final updated = current[idx].copyWith(status: lower);
    final newList = List<OrderModel>.from(current);
    newList[idx] = updated;
    state = state.copyWith(allOrders: newList);
  }

  void patchOrder(OrderModel fullOrder) {
    final id = fullOrder.id;
    if (_completedLock.contains(id) && fullOrder.status != 'completed') {
      // keep completed, ignore stale
      return;
    }
    if (fullOrder.status == 'completed') _completedLock.add(id);
    final current = state._allOrders;
    final idx = current.indexWhere((o) => o.id == id);
    if (idx == -1) {
      // insert if not exist (e.g. fallback fetch found order)
      state = state.copyWith(allOrders: [fullOrder, ...current]);
    } else {
      final newList = List<OrderModel>.from(current);
      newList[idx] = fullOrder;
      state = state.copyWith(allOrders: newList);
    }
  }

  Future<void> fetchActivities({bool force = false}) async {
    final authState = _ref.read(authProvider);
    if (!authState.isAuthenticated || authState.user == null) return;
    // Merchant doesn't use /orders/me - use merchant orders via WebView, skip to avoid 403/200 empty spam
    if (authState.user?.isMerchant ?? false) return;

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
    state = state.copyWith(isLoading: true, error: null, currentPage: 1, allOrders: []);

    try {
      final orders = await _orderRepo.getMyOrders(page: 1, limit: _limit);
      final merged = _applyCompletedLock(orders);
      state = state.copyWith(
        isLoading: false,
        hasFetched: true,
        currentPage: 1,
        hasMore: orders.length == _limit,
        allOrders: merged,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, hasFetched: true, error: e.toString());
    }
  }

  List<OrderModel> _applyCompletedLock(List<OrderModel> incoming) {
    if (_completedLock.isEmpty) return incoming;
    // Preserve completed status for locked ids even if server returns stale
    final existingMap = {for (var o in state._allOrders) o.id: o};
    return incoming.map((o) {
      if (_completedLock.contains(o.id) && o.status != 'completed') {
        final kept = existingMap[o.id];
        if (kept != null && kept.status == 'completed') return kept;
        return o.copyWith(status: 'completed');
      }
      if (o.status == 'completed') _completedLock.add(o.id);
      return o;
    }).toList();
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore || state.isLoading) return;

    state = state.copyWith(isLoadingMore: true, error: null);
    try {
      final nextPage = state.currentPage + 1;
      final orders = await _orderRepo.getMyOrders(page: nextPage, limit: _limit);
      final merged = [...state._allOrders, ..._applyCompletedLock(orders)];
      state = state.copyWith(
        isLoadingMore: false,
        currentPage: nextPage,
        hasMore: orders.length == _limit,
        allOrders: merged,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e.toString());
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
    final originalOrders = state._allOrders;
    state = state.copyWith(
      allOrders: state._allOrders.map((o) => o.id == id ? o.copyWith(status: 'purchasing') : o).toList(),
    );

    try {
      await _orderRepo.purchaseOrder(id, receiptPath);
      await fetchActivities(force: true);
      return true;
    } catch (e) {
      // Revert if failed
      state = state.copyWith(allOrders: originalOrders);
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
    // Optimistic Update + lock delivering
    _deliveringLock.add(id);
    final originalOrders = state._allOrders;
    state = state.copyWith(
      allOrders: state._allOrders.map((o) => o.id == id ? o.copyWith(status: 'delivering') : o).toList(),
    );

    try {
      await _orderRepo.pickupOrder(id);
      await fetchActivities(force: true);
      return true;
    } catch (e) {
      _deliveringLock.remove(id);
      // Revert if failed
      state = state.copyWith(allOrders: originalOrders);
      return false;
    }
  }

  Future<bool> completeOrder(String id, String code, String imagePath) async {
    // Optimistic Update + hard lock completed (prevents stale revert to ready)
    _completedLock.add(id);
    final originalOrders = state._allOrders;
    state = state.copyWith(
      allOrders: state._allOrders.map((o) => o.id == id ? o.copyWith(status: 'completed') : o).toList(),
    );

    try {
      await _orderRepo.completeOrder(id, code, imagePath);
      // After success, fetch but keep completed lock – _applyCompletedLock will preserve it
      await fetchActivities(force: true);
      return true;
    } catch (e) {
      debugPrint('DEBUG COMPLETE ORDER ERROR: $e');
      _completedLock.remove(id); // only remove lock on failure
      state = state.copyWith(allOrders: originalOrders);
      return false;
    }
  }

  Future<void> fetchMerchantOrders() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final orders = await _orderRepo.getMerchantOrders();
      state = state.copyWith(
        isLoading: false,
        merchantOrders: orders,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> merchantAccept(String id) async {
    try {
      await _orderRepo.merchantAcceptOrder(id);
      await fetchMerchantOrders();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> merchantReady(String id) async {
    try {
      await _orderRepo.merchantReadyOrder(id);
      await fetchMerchantOrders();
      return true;
    } catch (e) {
      return false;
    }
  }
}

final activityProvider = StateNotifierProvider<ActivityNotifier, ActivityState>((ref) {
  final orderRepo = ref.watch(orderRepositoryProvider);
  return ActivityNotifier(orderRepo, ref);
});
