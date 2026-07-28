import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/support_provider.dart';

class SupportNewTicketPage extends ConsumerStatefulWidget {
  final String? orderId;
  const SupportNewTicketPage({super.key, this.orderId});

  @override
  ConsumerState<SupportNewTicketPage> createState() => _SupportNewTicketPageState();
}

class _SupportNewTicketPageState extends ConsumerState<SupportNewTicketPage> {
  String category = 'other';
  final titleCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  bool isSubmitting = false;

  final categories = [
    {'value': 'order_issue', 'label': 'Masalah Pesanan'},
    {'value': 'payment', 'label': 'Pembayaran'},
    {'value': 'account', 'label': 'Akun'},
    {'value': 'merchant', 'label': 'Toko/Merchant'},
    {'value': 'other', 'label': 'Lainnya'},
  ];

  @override
  void dispose() {
    titleCtrl.dispose();
    descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (titleCtrl.text.trim().length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Judul minimal 5 karakter')));
      return;
    }
    if (descCtrl.text.trim().length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deskripsi minimal 10 karakter')));
      return;
    }
    setState(() => isSubmitting = true);
    try {
      final ticket = await ref.read(supportProvider.notifier).createTicket({
        'title': titleCtrl.text.trim(),
        'description': descCtrl.text.trim(),
        'category': category,
        if (widget.orderId != null) 'order_id': widget.orderId,
      });
      if (ticket != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tiket berhasil dibuat! Menunggu CS'), backgroundColor: Colors.green));
        context.go('/support/${ticket.id}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal membuat tiket: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primary = AppColors.primary;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Buat Tiket Bantuan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.orderId != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: primary.withValues(alpha: 0.2))),
                child: Row(
                  children: [
                    Icon(Icons.receipt_long_rounded, size: 18, color: primary),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Terkait Order: ${widget.orderId!.substring(0, 8).toUpperCase()}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  ],
                ),
              ),
            if (widget.orderId != null) const SizedBox(height: 16),
            const Text('Kategori', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: category,
              decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
              items: categories.map((c) => DropdownMenuItem<String>(value: c['value']!, child: Text(c['label']!, style: const TextStyle(fontSize: 13)))).toList(),
              onChanged: (v) => setState(() => category = v ?? 'other'),
            ),
            const SizedBox(height: 16),
            const Text('Judul', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: titleCtrl,
              decoration: InputDecoration(hintText: 'Ringkasan masalah...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
            ),
            const SizedBox(height: 16),
            const Text('Deskripsi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: descCtrl,
              maxLines: 5,
              decoration: InputDecoration(hintText: 'Jelaskan detail masalah...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.all(16)),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: isSubmitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Kirim Tiket', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Tips: Cari solusi di FAQ sebelum membuat tiket. CS akan membalas via live chat (polling 5 detik).', style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
