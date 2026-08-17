import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';

class KycStatusPage extends ConsumerWidget {
  const KycStatusPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final kycStatus = authState.kycStatus ?? 'none';
    final isVerified = authState.user?.isVerified ?? false;

    String title;
    String desc;
    IconData icon;
    Color iconColor;
    Color bgColor;

    if (isVerified || kycStatus == 'approved') {
      title = 'Akun Terverifikasi!';
      desc = 'Selamat! Identitas Anda telah terverifikasi. Anda kini dapat menikmati seluruh fitur Nitip.';
      icon = Icons.verified_rounded;
      iconColor = const Color(0xFF10B981);
      bgColor = const Color(0xFFD1FAE5);
    } else if (kycStatus == 'pending') {
      title = 'Verifikasi Sedang Diproses';
      desc = 'Terima kasih telah melengkapi data identitas. Admin kami sedang meninjau dokumen Anda. Proses ini biasanya memakan waktu 1×24 jam.';
      icon = Icons.access_time_rounded;
      iconColor = const Color(0xFFF59E0B);
      bgColor = const Color(0xFFFEF3C7);
    } else if (kycStatus == 'rejected') {
      title = 'Verifikasi Ditolak';
      desc = 'Mohon maaf, dokumen verifikasi Anda tidak memenuhi syarat kami. Silakan perbaiki dan ajukan ulang.';
      icon = Icons.error_outline_rounded;
      iconColor = const Color(0xFFEF4444);
      bgColor = const Color(0xFFFEE2E2);
    } else {
      title = 'Belum Ada Pengajuan';
      desc = 'Anda belum mengajukan verifikasi e-KYC. Silakan mulai verifikasi untuk transaksi tanpa batas.';
      icon = Icons.shield_outlined;
      iconColor = Colors.grey;
      bgColor = Colors.grey.shade100;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1A1A1A)),
          onPressed: () => context.pop(),
        ),
        title: const Text('Status Verifikasi', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle, border: Border.all(color: iconColor.withValues(alpha: 0.2), width: 4)),
                    child: Icon(icon, size: 56, color: iconColor),
                  ),
                  const SizedBox(height: 24),
                  Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A)), textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  Text(desc, style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.5), textAlign: TextAlign.center),
                  const SizedBox(height: 32),
                  if (kycStatus == 'pending') ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Apa selanjutnya?', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          _BulletPoint(text: 'Anda akan menerima notifikasi jika verifikasi disetujui.'),
                          const SizedBox(height: 8),
                          _BulletPoint(text: 'Lencana terverifikasi akan otomatis muncul di profil Anda.'),
                        ],
                      ),
                    ),
                  ],
                  if (kycStatus == 'rejected') ...[
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () => context.push('/kyc-intro'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        child: const Text('Ajukan Ulang Verifikasi', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4))]),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => context.go('/dashboard'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade100, foregroundColor: const Color(0xFF1A1A1A), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text('Kembali ke Beranda', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BulletPoint extends StatelessWidget {
  final String text;
  const _BulletPoint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(width: 6, height: 6, margin: const EdgeInsets.only(top: 6), decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: TextStyle(fontSize: 12, color: Colors.grey[600], height: 1.4))),
      ],
    );
  }
}
