import '../models/order_model.dart';

abstract class OrderRepository {
  Future<List<OrderModel>> getMyOrders({int page = 1, int limit = 15});
  Future<List<OrderModel>> getAvailableOrders();
  Future<OrderModel> getOrderById(String id);
  Future<OrderModel> createOrder(Map<String, dynamic> data);
  Future<void> cancelOrder(String id);
  Future<void> acceptOrder(String id);
  Future<void> purchaseOrder(String id, String receiptPath);
  Future<void> adjustPrice(String id, double adjustedCost, String reason);
  Future<void> approveAdjustment(String id);
  Future<void> pickupOrder(String id);
  Future<void> completeOrder(String id, String completionCode, String deliveryImagePath);
  Future<Map<String, dynamic>> estimateFee(Map<String, dynamic> data);
}
