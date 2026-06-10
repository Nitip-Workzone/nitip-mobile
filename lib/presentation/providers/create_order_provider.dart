import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../domain/repositories/order_repository.dart';
import 'activity_provider.dart';
import 'wallet_provider.dart';

class CreateOrderState {
  final bool isLoading;
  final String? error;
  final String itemDetails;
  final double estimatedCost;
  final double weightKg;
  final double volumeLiters;
  final LatLng? pickupLocation;
  final String? pickupAddress;
  final LatLng? deliveryLocation;
  final String? deliveryAddress;
  final double estimatedFee;
  final double distanceKm;
  final String paymentMethod;
  final bool showSummary;
  final double userBalance;
  final String serviceCategory;
  final String? receiverName;
  final String? receiverPhone;
  final String? deliveryName;

  CreateOrderState({
    this.isLoading = false,
    this.error,
    this.itemDetails = '',
    this.estimatedCost = 0,
    this.weightKg = 0.5,
    this.volumeLiters = 1,
    this.pickupLocation,
    this.pickupAddress,
    this.deliveryLocation,
    this.deliveryAddress,
    this.estimatedFee = 0,
    this.distanceKm = 0,
    this.paymentMethod = 'escrow',
    this.showSummary = false,
    this.userBalance = 0,
    this.serviceCategory = 'beli',
    this.receiverName,
    this.receiverPhone,
    this.deliveryName,
  });

  CreateOrderState copyWith({
    bool? isLoading,
    String? error,
    String? itemDetails,
    double? estimatedCost,
    double? weightKg,
    double? volumeLiters,
    LatLng? pickupLocation,
    String? pickupAddress,
    LatLng? deliveryLocation,
    String? deliveryAddress,
    double? estimatedFee,
    double? distanceKm,
    String? paymentMethod,
    bool? showSummary,
    double? userBalance,
    String? serviceCategory,
    String? receiverName,
    String? receiverPhone,
    String? deliveryName,
  }) {
    return CreateOrderState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      itemDetails: itemDetails ?? this.itemDetails,
      estimatedCost: estimatedCost ?? this.estimatedCost,
      weightKg: weightKg ?? this.weightKg,
      volumeLiters: volumeLiters ?? this.volumeLiters,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      deliveryLocation: deliveryLocation ?? this.deliveryLocation,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      estimatedFee: estimatedFee ?? this.estimatedFee,
      distanceKm: distanceKm ?? this.distanceKm,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      showSummary: showSummary ?? this.showSummary,
      userBalance: userBalance ?? this.userBalance,
      serviceCategory: serviceCategory ?? this.serviceCategory,
      receiverName: receiverName ?? this.receiverName,
      receiverPhone: receiverPhone ?? this.receiverPhone,
      deliveryName: deliveryName ?? this.deliveryName,
    );
  }

  bool get canEstimate => pickupLocation != null && deliveryLocation != null;
  bool get isValid {
    bool baseValid = itemDetails.isNotEmpty && pickupLocation != null && deliveryLocation != null;
    if (serviceCategory == 'beli') {
      return baseValid && estimatedCost > 0;
    } else {
      return baseValid && (receiverName?.isNotEmpty ?? false) && (receiverPhone?.isNotEmpty ?? false);
    }
  }
  double get totalPayment => serviceCategory == 'kirim' ? estimatedFee : (estimatedCost + estimatedFee);
  bool get isBalanceSufficient => paymentMethod == 'cod' || userBalance >= totalPayment;
}

class CreateOrderNotifier extends StateNotifier<CreateOrderState> {
  final OrderRepository _orderRepo;
  final Ref _ref;

  CreateOrderNotifier(this._orderRepo, this._ref) : super(CreateOrderState()) {
    // Dengarkan perubahan pada walletProvider untuk sinkronisasi saldo secara real-time
    _ref.listen(walletProvider, (previous, next) {
      if (next.wallet != null && next.wallet!.balance != state.userBalance) {
        state = state.copyWith(userBalance: next.wallet!.balance);
      }
    });
  }

  void updateItemDetails(String value) => state = state.copyWith(itemDetails: value);
  void updateEstimatedCost(double value) => state = state.copyWith(estimatedCost: value);
  void updateWeight(double value) {
    state = state.copyWith(weightKg: value);
    estimateFee();
  }
  void updateVolume(double value) {
    state = state.copyWith(volumeLiters: value);
    estimateFee();
  }
  
  void updatePickup(LatLng loc, String address) {
    state = state.copyWith(pickupLocation: loc, pickupAddress: address);
    estimateFee();
  }

  void updateDelivery(LatLng loc, String address) {
    state = state.copyWith(deliveryLocation: loc, deliveryAddress: address);
    estimateFee();
  }

  void updatePaymentMethod(String method) => state = state.copyWith(paymentMethod: method);
  void updateServiceCategory(String category) => state = state.copyWith(serviceCategory: category);
  void updateReceiverName(String value) => state = state.copyWith(receiverName: value);
  void updateReceiverPhone(String value) => state = state.copyWith(receiverPhone: value);
  void updateDeliveryName(String value) => state = state.copyWith(deliveryName: value);

  void reset() => state = CreateOrderState();

  void toggleSummary(bool value) => state = state.copyWith(showSummary: value);

  Future<void> prepareSummary() async {
    if (!state.isValid) {
      state = state.copyWith(error: "Mohon lengkapi semua data");
      return;
    }

    state = state.copyWith(isLoading: true, error: null);
    try {
      // Refresh wallet balance
      await _ref.read(walletProvider.notifier).fetchBalance();
      final walletState = _ref.read(walletProvider);
      
      state = state.copyWith(
        userBalance: walletState.wallet?.balance ?? 0,
        showSummary: true,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: "Gagal mengambil saldo terbaru");
    }
  }

  Future<void> estimateFee() async {
    if (!state.canEstimate) return;
    
    try {
      final payload = {
        'pickup_lat': state.pickupLocation!.latitude,
        'pickup_lng': state.pickupLocation!.longitude,
        'delivery_lat': state.deliveryLocation!.latitude,
        'delivery_lng': state.deliveryLocation!.longitude,
        'weight_kg': state.weightKg,
        'volume_liters': state.volumeLiters,
      };

      final result = await _orderRepo.estimateFee(payload);
      state = state.copyWith(
        estimatedFee: (result['estimated_fee'] ?? 0).toDouble(),
        distanceKm: (result['distance_km'] ?? 0).toDouble(),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<String?> submitOrder() async {
    if (!state.isValid) return "Mohon lengkapi semua data";
    if (!state.isBalanceSufficient) return "Saldo tidak mencukupi";

    state = state.copyWith(isLoading: true, error: null);
    try {
      final payload = {
        'item_details': state.itemDetails,
        'pickup_lat': state.pickupLocation!.latitude,
        'pickup_lng': state.pickupLocation!.longitude,
        'pickup_name': 'Shop', // Optional
        'pickup_address': state.pickupAddress,
        'delivery_lat': state.deliveryLocation!.latitude,
        'delivery_lng': state.deliveryLocation!.longitude,
        'estimated_cost': state.estimatedCost,
        'payment_method': state.paymentMethod,
        'weight_kg': state.weightKg,
        'volume_liters': state.volumeLiters,
        'service_category': state.serviceCategory,
        'receiver_name': state.receiverName,
        'receiver_phone': state.receiverPhone,
        'delivery_name': state.deliveryName,
      };

      debugPrint("[DEBUG] Payload: $payload");
      await _orderRepo.createOrder(payload);
      _ref.read(activityProvider.notifier).fetchActivities();
      state = state.copyWith(isLoading: false);
      return null; // Success
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return e.toString();
    }
  }
}

final createOrderProvider = StateNotifierProvider<CreateOrderNotifier, CreateOrderState>((ref) {
  final orderRepo = ref.watch(orderRepositoryProvider);
  return CreateOrderNotifier(orderRepo, ref);
});
