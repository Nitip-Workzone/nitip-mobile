import '../../data/models/support_ticket_model.dart';

abstract class SupportRepository {
  Future<List<SupportTicketModel>> getMyTickets();
  Future<SupportTicketModel> getTicketDetail(String id);
  Future<SupportTicketModel> createTicket(Map<String, dynamic> payload);
  Future<List<SupportMessageModel>> getMessages(String ticketId, {String? afterId});
  Future<SupportMessageModel> sendMessage(String ticketId, String message);
  Future<void> closeTicket(String ticketId);
}
