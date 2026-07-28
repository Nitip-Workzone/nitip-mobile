import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/support_ticket_model.dart';
import '../../data/repositories/support_repository_impl.dart';
import '../../domain/repositories/support_repository.dart';
import 'auth_provider.dart';

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
  Timer? _pollingTimer;

  SupportNotifier(this._repo) : super(SupportState());

  Future<void> fetchMyTickets() async {
    state = state.copyWith(isLoading: true);
    try {
      final tickets = await _repo.getMyTickets();
      state = state.copyWith(isLoading: false, tickets: tickets);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> fetchTicketDetail(String id) async {
    state = state.copyWith(isLoading: true);
    try {
      final ticket = await _repo.getTicketDetail(id);
      state = state.copyWith(currentTicket: ticket, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> fetchMessages(String ticketId, {bool isInitial = true}) async {
    if (isInitial) state = state.copyWith(isMessagesLoading: true);
    try {
      String? afterId;
      if (!isInitial && state.messages.isNotEmpty) {
        afterId = state.messages.last.id;
      }
      final msgs = await _repo.getMessages(ticketId, afterId: afterId);
      if (isInitial) {
        state = state.copyWith(messages: msgs, isMessagesLoading: false);
      } else {
        if (msgs.isNotEmpty) {
          state = state.copyWith(messages: [...state.messages, ...msgs]);
        }
      }
    } catch (e) {
      state = state.copyWith(isMessagesLoading: false);
    }
  }

  int _pollingFailCount = 0;

  void startPolling(String ticketId) {
    stopPolling();
    _pollingFailCount = 0;
    // P1: backoff 5s base, + incremental if fail, stops on background via lifecycle observer in page
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        await fetchMessages(ticketId, isInitial: false);
        _pollingFailCount = 0;
      } catch (_) {
        _pollingFailCount++;
        // Exponential backoff up to 30s if repeated fails (prod 512M safety)
        if (_pollingFailCount >= 3) {
          stopPolling();
          final backoff = Duration(seconds: (5 * (1 << (_pollingFailCount - 3))).clamp(5, 30));
          _pollingTimer = Timer.periodic(backoff, (_) async {
            try {
              await fetchMessages(ticketId, isInitial: false);
              // Reset to 5s on success
              startPolling(ticketId);
            } catch (_) {
              // keep backoff
            }
          });
        }
      }
    });
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<SupportTicketModel?> createTicket(Map<String, dynamic> payload) async {
    state = state.copyWith(isLoading: true);
    try {
      final ticket = await _repo.createTicket(payload);
      await fetchMyTickets();
      state = state.copyWith(isLoading: false);
      return ticket;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  Future<void> sendMessage(String ticketId, String message) async {
    try {
      final msg = await _repo.sendMessage(ticketId, message);
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
  return SupportNotifier(repo);
});
