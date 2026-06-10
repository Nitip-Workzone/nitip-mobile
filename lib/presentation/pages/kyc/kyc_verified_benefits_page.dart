import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class KycVerifiedBenefitsPage extends ConsumerWidget {
  const KycVerifiedBenefitsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final isRunner = user?.isRunner ?? false;
    final primary = isRunner ? AppColors.secondary : AppColors.primary;

    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Header gradient
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primary, primary.withValues(alpha: 0.75)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
                child: Column(
                  children: [
                    // Shield icon with glow
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.verified_user_rounded,
                        color: Colors.white,
                        size: 52,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Akun Terverifikasi ✓',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Identitas Anda telah berhasil diverifikasi.\nNikmati semua keuntungan eksklusif berikut.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.85),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Verified chip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.verified_rounded, color: Colors.white, size: 16),
                          SizedBox(width: 6),
                          Text(
                            'Status: Terverifikasi',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section title
                  const Text(
                    'Keuntungan Anda',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sebagai akun terverifikasi, Anda mendapatkan akses ke fitur-fitur premium.',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.5),
                  ),
                  const SizedBox(height: 20),

                  // Benefit cards — generic
                  _BenefitItem(
                    icon: Icons.verified_rounded,
                    color: primary,
                    title: 'Lencana Terverifikasi',
                    description:
                        'Badge centang biru di samping nama Anda menandakan akun terpercaya di komunitas Nitip.',
                    isActive: true,
                  ),
                  _BenefitItem(
                    icon: Icons.shield_rounded,
                    color: primary,
                    title: 'Perlindungan Transaksi',
                    description:
                        'Transaksi Anda dilindungi oleh sistem jaminan Nitip. Klaim sengketa lebih mudah diselesaikan.',
                    isActive: true,
                  ),
                  _BenefitItem(
                    icon: Icons.wallet_rounded,
                    color: primary,
                    title: 'Batas Saldo Lebih Besar',
                    description:
                        'Simpan saldo Nitip Pay lebih banyak dibanding akun yang belum terverifikasi.',
                    isActive: true,
                  ),

                  // Role-specific benefits
                  if (isRunner) ...[
                    _BenefitItem(
                      icon: Icons.flash_on_rounded,
                      color: primary,
                      title: 'Prioritas Notifikasi Order',
                      description:
                          'Dapatkan notifikasi pesanan masuk lebih cepat dan akses eksklusif ke order dengan nilai tinggi.',
                      isActive: true,
                    ),
                    _BenefitItem(
                      icon: Icons.star_rounded,
                      color: primary,
                      title: 'Profil Runner Unggulan',
                      description:
                          'Profil Anda akan muncul lebih tinggi di pencarian calon pembeli yang mencari runner.',
                      isActive: true,
                    ),
                  ] else ...[
                    _BenefitItem(
                      icon: Icons.local_shipping_rounded,
                      color: primary,
                      title: 'Akses ke Semua Runner',
                      description:
                          'Bisa memilih runner terverifikasi khusus untuk pesanan yang membutuhkan kepercayaan lebih.',
                      isActive: true,
                    ),
                    _BenefitItem(
                      icon: Icons.support_agent_rounded,
                      color: primary,
                      title: 'Prioritas Layanan CS',
                      description:
                          'Laporan dan keluhan Anda ditangani lebih cepat oleh tim Customer Service Nitip.',
                      isActive: true,
                    ),
                  ],

                  const SizedBox(height: 28),

                  // Security section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.lock_rounded, color: Color(0xFF16A34A), size: 20),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Data Anda Aman',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: Color(0xFF15803D),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Seluruh dokumen identitas dienkripsi dan hanya digunakan untuk keperluan verifikasi. Nitip tidak menyimpan atau membagikan data Anda kepada pihak ketiga.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF166534),
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // CTA — close button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Kembali ke Beranda',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BenefitItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final bool isActive;

  const _BenefitItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    this.isActive = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.04) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? color.withValues(alpha: 0.15) : Colors.grey.shade200,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isActive ? color.withValues(alpha: 0.12) : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: isActive ? color : Colors.grey, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: isActive ? const Color(0xFF1A1A1A) : Colors.grey,
                          ),
                        ),
                      ),
                      if (isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Aktif',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF16A34A),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
