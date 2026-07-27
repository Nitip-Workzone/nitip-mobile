import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/support_provider.dart';

class SupportTicketDetailPage extends ConsumerStatefulWidget {
  final String ticketId;
  const SupportTicketDetailPage({super.key, required this.ticketId});

  @override
  ConsumerState<SupportTicketDetailPage> createState() => _SupportTicketDetailPageState();
}

class _SupportTicketDetailPageState extends ConsumerState<SupportTicketDetailPage> {
  final messageCtrl = TextEditingController();
  final scrollCtrl = ScrollController();
  bool isSending = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(supportProvider.notifier).fetchTicketDetail(widget.ticketId);
      await ref.read(supportProvider.notifier).fetchMessages(widget.ticketId, isInitial: true);
      ref.read(supportProvider.notifier).startPolling(widget.ticketId);
    });
  }

  @override
  void dispose() {
    ref.read(supportProvider.notifier).stopPolling();
    messageCtrl.dispose();
    scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (scrollCtrl.hasClients) {
      scrollCtrl.animateTo(scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  Future<void> _send() async {
    if (messageCtrl.text.trim().isEmpty) return;
    setState(() => isSending = true);
    try {
      await ref.read(supportProvider.notifier).sendMessage(widget.ticketId, messageCtrl.text.trim());
      messageCtrl.clear();
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal kirim: $e')));
    } finally {
      if (mounted) setState(() => isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(supportProvider);
    final ticket = state.currentTicket;
    const primary = AppColors.primary;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(ticket?.title ?? 'Detail Tiket', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        actions: [
          if (ticket != null && ticket.status != 'closed' && ticket.status != 'resolved')
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () async {
                final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Tutup Tiket'), content: const Text('Yakin tutup tiket ini?'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')), ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Tutup'))]));
                if (confirm == true) {
                  await ref.read(supportProvider.notifier).closeTicket(widget.ticketId);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tiket ditutup')));
                    Navigator.pop(context);
                  }
                }
              },
            ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (ticket != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    color: primary.withValues(alpha: 0.06),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ticket.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text(ticket.description, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)), child: Text(ticket.status.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                            const SizedBox(width: 8),
                            Text(ticket.category, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                            if (ticket.orderId != null) ...[
                              const SizedBox(width: 8),
                              Text('Order #${ticket.orderId!.substring(0, 8).toUpperCase()}', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: state.isMessagesLoading && state.messages.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
                          controller: scrollCtrl,
                          padding: const EdgeInsets.all(16),
                          itemCount: state.messages.length,
                          itemBuilder: (context, index) {
                            final m = state.messages[index];
                            final isUser = m.senderRole == 'user';
                            return Align(
                              alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                                decoration: BoxDecoration(
                                  color: isUser ? primary : Colors.white,
                                  borderRadius: BorderRadius.circular(16).copyWith(bottomRight: isUser ? const Radius.circular(4) : null, bottomLeft: isUser ? null : const Radius.circular(4)),
                                  border: isUser ? null : Border.all(color: Colors.grey.shade200),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(m.message, style: TextStyle(fontSize: 13, color: isUser ? Colors.white : Colors.black87)),
                                    const SizedBox(height: 4),
                                    Text('${m.createdAt.hour}:${m.createdAt.minute.toString().padLeft(2, '0')} • ${isUser ? 'Anda' : 'CS'}', style: TextStyle(fontSize: 9, color: isUser ? Colors.white70 : Colors.grey.shade500)),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey.shade200))),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: messageCtrl,
                          decoration: InputDecoration(hintText: 'Ketik pesan...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), isDense: true),
                          minLines: 1,
                          maxLines: 4,
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: isSending ? null : _send,
                          style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white, shape: const CircleBorder(), padding: EdgeInsets.zero),
                          child: isSending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send_rounded, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
