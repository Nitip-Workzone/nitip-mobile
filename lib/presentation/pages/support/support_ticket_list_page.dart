import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/support_provider.dart';

class SupportTicketListPage extends ConsumerStatefulWidget {
  const SupportTicketListPage({super.key});

  @override
  ConsumerState<SupportTicketListPage> createState() => _SupportTicketListPageState();
}

class _SupportTicketListPageState extends ConsumerState<SupportTicketListPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(supportProvider.notifier).fetchMyTickets());
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'queued':
      case 'open':
        return 'Antrian';
      case 'assigned':
      case 'in_progress':
        return 'Diproses';
      case 'waiting_user':
        return 'Menunggu Anda';
      case 'resolved':
        return 'Selesai';
      case 'closed':
        return 'Ditutup';
      default:
        return s;
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'queued':
      case 'open':
        return Colors.orange;
      case 'assigned':
      case 'in_progress':
        return Colors.blue;
      case 'waiting_user':
        return Colors.purple;
      case 'resolved':
        return Colors.green;
      case 'closed':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(supportProvider);
    const primary = AppColors.primary;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Pusat Bantuan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/support/new'),
        backgroundColor: primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Tiket Baru', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.tickets.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.support_agent_rounded, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      const Text('Belum ada tiket bantuan', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('Buat tiket jika mengalami kendala', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () => context.push('/support/new'),
                        style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white),
                        child: const Text('Buat Tiket Pertama'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => ref.read(supportProvider.notifier).fetchMyTickets(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: state.tickets.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final t = state.tickets[index];
                      return InkWell(
                        onTap: () => context.push('/support/${t.id}'),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(child: Text(t.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: _statusColor(t.status).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: _statusColor(t.status).withValues(alpha: 0.3))),
                                    child: Text(_statusLabel(t.status), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _statusColor(t.status))),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(t.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Icon(Icons.category_outlined, size: 12, color: Colors.grey.shade400),
                                  const SizedBox(width: 4),
                                  Text(t.category, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                  const Spacer(),
                                  Text('${t.createdAt.day}/${t.createdAt.month}/${t.createdAt.year}', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
