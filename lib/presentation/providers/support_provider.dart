import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/support_ticket_model.dart';
import '../../data/repositories/support_repository_impl.dart';
import '../../domain/repositories/support_repository.dart';
import 'auth_provider.dart';
import 'notification_provider.dart';
import '../../data/models/notification_model.dart';

final supportRepositoryProvider = Provider<SupportRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return SupportRepositoryImpl(apiClient);
});

class SupportState {
  final bool isLoading;
  final bool isMessagesLoading;
  final List<SupportTicketModel> tickets;
  final List<SupportMessageModel> messages;
  final SupportTicketModel? currentTicket;
  final String? error;

  SupportState({
    this.isLoading = false,
    this.isMessagesLoading = false,
    this.tickets = const [],
    this.messages = const [],
    this.currentTicket,
    this.error,
  });

  SupportState copyWith({
    bool? isLoading,
    bool? isMessagesLoading,
    List<SupportTicketModel>? tickets,
    List<SupportMessageModel>? messages,
    SupportTicketModel? currentTicket,
    Object? error = const Object(),
  }) {
    return SupportState(
      isLoading: isLoading ?? this.isLoading,
      isMessagesLoading: isMessagesLoading ?? this.isMessagesLoading,
      tickets: tickets ?? this.tickets,
      messages: messages ?? this.messages,
      currentTicket: currentTicket ?? this.currentTicket,
      error: error == const Object() ? this.error : error as String?,
    );
  }

  SupportState clearCurrentTicket() => SupportState(
        isLoading: isLoading,
        isMessagesLoading: isMessagesLoading,
        tickets: tickets,
        messages: messages,
        currentTicket: null,
        error: error,
      );
}

class SupportNotifier extends StateNotifier<SupportState> {
  final SupportRepository _repo;
  final Ref _ref;
  Timer? _pollingTimer;

  SupportNotifier(this._repo, this._ref) : super(SupportState());

  Future<void> fetchMyTickets() async {
    if (!mounted) return;
    state = state.copyWith(isLoading: true);
    try {
      final tickets = await _repo.getMyTickets();
      if (!mounted) return;
      state = state.copyWith(isLoading: false, tickets: tickets);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> fetchTicketDetail(String id) async {
    if (!mounted) return;
    state = state.copyWith(isLoading: true);
    try {
      final ticket = await _repo.getTicketDetail(id);
      if (!mounted) return;
      state = state.copyWith(currentTicket: ticket, isLoading: false);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> fetchMessages(String ticketId, {bool isInitial = true}) async {
    if (isInitial) {
      if (!mounted) return;
      state = state.copyWith(isMessagesLoading: true);
    }
    try {
      String? afterId;
      if (!isInitial && state.messages.isNotEmpty) {
        afterId = state.messages.last.id;
      }
      final msgs = await _repo.getMessages(ticketId, afterId: afterId);
      if (!mounted) return;
      if (isInitial) {
        state = state.copyWith(messages: msgs, isMessagesLoading: false);
      } else {
        if (msgs.isNotEmpty) {
          final newMsgs = msgs.where((m) => !state.messages.any((existing) => existing.id == m.id)).toList();
          if (newMsgs.isNotEmpty) {
            state = state.copyWith(messages: [...state.messages, ...newMsgs]);
            
            // Play local notification sound if new CS/Admin reply is received
            final hasNewCsMsg = newMsgs.any((m) => m.senderRole == 'cs' || m.senderRole == 'admin');
            if (hasNewCsMsg) {
              final lastMsg = newMsgs.last;
              _ref.read(notificationProvider.notifier).showLocalNotification(
                NotificationModel(
                  id: lastMsg.id,
                  userId: '',
                  title: 'Bantuan Nitip',
                  message: lastMsg.message,
                  type: 'chat',
                  isRead: false,
                  metadata: {'ticket_id': ticketId},
                  createdAt: DateTime.now(),
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isMessagesLoading: false);
    }
  }

  void startPolling(String ticketId) {
    // Polling disabled to reduce server load
  }

  void stopPolling() {
    // Polling disabled
  }

  Future<SupportTicketModel?> createTicket(Map<String, dynamic> payload) async {
    if (!mounted) return null;
    state = state.copyWith(isLoading: true);
    try {
      final ticket = await _repo.createTicket(payload);
      await fetchMyTickets();
      if (!mounted) return ticket;
      state = state.copyWith(isLoading: false);
      return ticket;
    } catch (e) {
      if (!mounted) return null;
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  Future<void> sendMessage(String ticketId, String message) async {
    try {
      final msg = await _repo.sendMessage(ticketId, message);
      if (!mounted) return;
      state = state.copyWith(messages: [...state.messages, msg]);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> closeTicket(String ticketId) async {
    await _repo.closeTicket(ticketId);
    await fetchMyTickets();
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}

final supportProvider = StateNotifierProvider<SupportNotifier, SupportState>((ref) {
  final repo = ref.watch(supportRepositoryProvider);
  return SupportNotifier(repo, ref);
});
