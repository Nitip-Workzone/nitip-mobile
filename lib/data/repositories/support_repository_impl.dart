import '../../data/network/api_client.dart';
import '../../domain/repositories/support_repository.dart';
import '../models/support_ticket_model.dart';

class SupportRepositoryImpl implements SupportRepository {
  final ApiClient apiClient;

  SupportRepositoryImpl(this.apiClient);

  @override
  Future<List<SupportTicketModel>> getMyTickets() async {
    final res = await apiClient.dio.get('/support/tickets?limit=50');
    final data = res.data['data'] as List?;
    if (data == null) return [];
    return data.map((e) => SupportTicketModel.fromJson(e)).toList();
  }

  @override
  Future<SupportTicketModel> getTicketDetail(String id) async {
    final res = await apiClient.dio.get('/support/tickets/$id');
    return SupportTicketModel.fromJson(res.data['data']);
  }

  @override
  Future<SupportTicketModel> createTicket(Map<String, dynamic> payload) async {
    final res = await apiClient.dio.post('/support/tickets', data: payload);
    return SupportTicketModel.fromJson(res.data['data']);
  }

  @override
  Future<List<SupportMessageModel>> getMessages(String ticketId, {String? afterId}) async {
    final query = afterId != null ? '?after_id=$afterId&limit=100' : '?limit=100';
    final res = await apiClient.dio.get('/support/tickets/$ticketId/messages$query');
    final data = res.data['data'] as List?;
    if (data == null) return [];
    return data.map((e) => SupportMessageModel.fromJson(e)).toList();
  }

  @override
  Future<SupportMessageModel> sendMessage(String ticketId, String message) async {
    final res = await apiClient.dio.post('/support/tickets/$ticketId/messages', data: {
      'message': message,
    });
    return SupportMessageModel.fromJson(res.data['data']);
  }

  @override
  Future<void> closeTicket(String ticketId) async {
    await apiClient.dio.post('/support/tickets/$ticketId/close');
  }
}
