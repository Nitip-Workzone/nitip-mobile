import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/support_provider.dart';

class SupportTicketDetailPage extends ConsumerStatefulWidget {
  final String ticketId;
  const SupportTicketDetailPage({super.key, required this.ticketId});

  @override
  ConsumerState<SupportTicketDetailPage> createState() => _SupportTicketDetailPageState();
}

class _SupportTicketDetailPageState extends ConsumerState<SupportTicketDetailPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(supportProvider.notifier).fetchTicketDetail(widget.ticketId);
    });
  }

  Future<void> _launchWhatsapp(String phone, String ticketId, String title) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '').replaceFirst(RegExp(r'^0'), '62');
    final message = 'Halo CS Nitip, saya butuh bantuan terkait tiket bantuan #${ticketId.substring(0, 8).toUpperCase()} saya: $title';
    final url = Uri.parse('https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tidak dapat membuka WhatsApp.')));
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Terjadi kesalahan saat membuka WhatsApp.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(supportProvider);
    final ticket = state.currentTicket;
    const primary = AppColors.primary;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/support');
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/support');
              }
            },
          ),
          title: const Text('Detail Tiket Bantuan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: Colors.black,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () async {
                await ref.read(supportProvider.notifier).fetchTicketDetail(widget.ticketId);
              },
            ),
            if (ticket != null && ticket.status != 'closed' && ticket.status != 'resolved')
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (value) async {
                  if (value == 'close') {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Selesaikan Tiket'),
                        content: const Text('Tandai masalah ini telah selesai/terpecahkan? Anda tidak dapat mengajukan pertanyaan lagi setelah tiket ditutup.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
                          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Selesaikan'))
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await ref.read(supportProvider.notifier).closeTicket(widget.ticketId);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tiket berhasil ditandai selesai')));
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/support');
                        }
                      }
                    }
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'close',
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 18),
                        SizedBox(width: 8),
                        Text('Tandai Selesai', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
        body: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : ticket == null
                ? const Center(child: Text('Tiket tidak ditemukan'))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Card Detail
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.grey.shade100),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: primary.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      ticket.category.toUpperCase(),
                                      style: const TextStyle(
                                        color: primary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '#${ticket.id.substring(0, 8).toUpperCase()}',
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                ticket.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                ticket.description,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                  height: 1.4,
                                ),
                              ),
                              if (ticket.orderId != null) ...[
                                const SizedBox(height: 16),
                                Divider(color: Colors.grey.shade100),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(Icons.receipt_long_rounded, size: 16, color: Colors.grey.shade400),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Order Terkait: ',
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                    ),
                                    Text(
                                      ticket.orderId!.substring(0, 8).toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Status Penanganan',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                        ),
                        const SizedBox(height: 16),

                        // Timeline Progress
                        _buildTimelineItem(
                          title: 'Tiket Dibuat',
                          subtitle: 'Laporan Anda telah berhasil masuk ke sistem antrian Nitip.',
                          isCompleted: true,
                          isLast: false,
                        ),
                        _buildTimelineItem(
                          title: 'Diproses CS',
                          subtitle: ticket.assignedCsId != null
                              ? 'Ditangani oleh CS: ${ticket.assignedCsName ?? 'Petugas CS'}'
                              : 'Menunggu petugas Customer Service mengambil tiket Anda.',
                          isCompleted: ticket.assignedCsId != null || ticket.status == 'resolved' || ticket.status == 'closed',
                          isLast: false,
                        ),
                        _buildTimelineItem(
                          title: 'Selesai',
                          subtitle: ticket.status == 'resolved' || ticket.status == 'closed'
                              ? 'Masalah selesai diidentifikasi dan ditutup.'
                              : 'Tiket akan ditandai selesai setelah solusi diberikan.',
                          isCompleted: ticket.status == 'resolved' || ticket.status == 'closed',
                          isLast: true,
                        ),

                        const SizedBox(height: 32),

                        // WhatsApp Action Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.green.shade100),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.chat_bubble_rounded, color: Colors.green, size: 40),
                              const SizedBox(height: 12),
                              const Text(
                                'Hubungi CS via WhatsApp',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Colors.green,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Gunakan WhatsApp untuk melakukan obrolan langsung secara cepat dan interaktif dengan CS kami.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green.shade800,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton.icon(
                                  onPressed: () => _launchWhatsapp(
                                    ticket.assignedCsWhatsapp ?? '6282125197825',
                                    ticket.id,
                                    ticket.title,
                                  ),
                                  icon: const Icon(Icons.send_rounded, size: 18),
                                  label: const Text('Mulai Chat WhatsApp', style: TextStyle(fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildTimelineItem({
    required String title,
    required String subtitle,
    required bool isCompleted,
    required bool isLast,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isCompleted ? Colors.green : Colors.grey.shade200,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isCompleted ? Icons.check : Icons.radio_button_unchecked,
                color: isCompleted ? Colors.white : Colors.grey.shade400,
                size: 14,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 48,
                color: isCompleted ? Colors.green.shade200 : Colors.grey.shade200,
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isCompleted ? Colors.black87 : Colors.grey.shade400,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: isCompleted ? Colors.grey.shade600 : Colors.grey.shade400,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }
}
