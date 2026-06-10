import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import 'kyc_ktp_page.dart';

class KycIntroPage extends ConsumerWidget {
  const KycIntroPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final kycStatus = authState.kycStatus ?? 'none';
    final isVerified = user?.isVerified ?? false;
    
    final isRunner = user?.isRunner ?? false;
    final primary = isRunner ? AppColors.secondary : AppColors.primary;
    final primaryLight = isRunner ? AppColors.secondaryLight : AppColors.primaryLight;

    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: kToolbarHeight + 40),
                  // Illustration — putih solid, tidak transparent
                  Container(
                    height: 220,
                    color: Colors.white,
                    child: Image.asset(
                      'assets/images/kyc_intro.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.verified_user_outlined,
                        size: 120,
                        color: primary,
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    'Verifikasi Identitas',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Selesaikan verifikasi untuk menikmati semua fitur Nitip secara penuh dan aman.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.6),
                  ),

                  const SizedBox(height: 32),

                  // Step indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _StepChip(number: 1, label: 'Foto KTP', icon: Icons.credit_card_rounded, color: primary),
                      _StepLine(color: primary),
                      _StepChip(number: 2, label: 'Selfie', icon: Icons.face_rounded, color: primary),
                      _StepLine(color: primary),
                      _StepChip(number: 3, label: 'Selesai', icon: Icons.check_circle_outline_rounded, color: primary),
                    ],
                  ),

                  const SizedBox(height: 32),

                  _BenefitCard(
                    icon: Icons.shield_rounded,
                    title: 'Data Anda Aman',
                    desc: 'Seluruh data identitas dienkripsi dan hanya digunakan untuk keperluan verifikasi.',
                    color: primary,
                    bgColor: primaryLight,
                  ),
                  const SizedBox(height: 12),
                  _BenefitCard(
                    icon: isRunner ? Icons.flash_on_rounded : Icons.wallet_rounded,
                    title: isRunner ? 'Prioritas Order' : 'Batas Saldo Lebih Besar',
                    desc: isRunner
                        ? 'Notifikasi pesanan masuk lebih cepat dan akses order nilai tinggi.'
                        : 'Simpan saldo Nitip Pay lebih banyak untuk transaksi jastip.',
                    color: primary,
                    bgColor: primaryLight,
                  ),
                  const SizedBox(height: 12),
                  _BenefitCard(
                    icon: Icons.verified_rounded,
                    title: 'Lencana Terverifikasi',
                    desc: 'Dapatkan badge centang untuk meningkatkan kepercayaan komunitas.',
                    color: primary,
                    bgColor: primaryLight,
                  ),

                  const SizedBox(height: 32),

                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Batasan Akun Non-Verifikasi',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _BenefitCard(
                    icon: Icons.shopping_bag_outlined,
                    title: 'Batas Transaksi Harian',
                    desc: 'Maksimal 5 pesanan per hari untuk pembuatan maupun penerimaan jasa.',
                    color: Colors.orange[800]!,
                    bgColor: Colors.orange[50]!,
                  ),
                  const SizedBox(height: 12),
                  _BenefitCard(
                    icon: Icons.payments_rounded,
                    title: 'Batas Penarikan Dana',
                    desc: 'Maksimal penarikan saldo adalah Rp 100.000 per hari.',
                    color: Colors.orange[800]!,
                    bgColor: Colors.orange[50]!,
                  ),
                  const SizedBox(height: 12),
                  _BenefitCard(
                    icon: Icons.payments_outlined,
                    title: 'Pembatasan Metode COD',
                    desc: 'Metode Cash on Delivery (COD) dinonaktifkan untuk akun belum terverifikasi.',
                    color: Colors.orange[800]!,
                    bgColor: Colors.orange[50]!,
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),

          // Bottom CTA
          Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4)),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: (kycStatus == 'pending' || isVerified)
                    ? null
                    : () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const KycKtpPage()));
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  disabledBackgroundColor: Colors.grey[200],
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  isVerified
                      ? 'Sudah Terverifikasi'
                      : (kycStatus == 'pending' ? 'Verifikasi Sedang Diproses' : 'Mulai Verifikasi'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepChip extends StatelessWidget {
  final int number;
  final String label;
  final IconData icon;
  final Color color;

  const _StepChip({required this.number, required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 1.5),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF555555))),
      ],
    );
  }
}

class _StepLine extends StatelessWidget {
  final Color color;
  const _StepLine({required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(height: 1.5, margin: const EdgeInsets.only(bottom: 20), color: color.withValues(alpha: 0.3)),
    );
  }
}

class _BenefitCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  final Color color;
  final Color bgColor;

  const _BenefitCard({required this.icon, required this.title, required this.desc, required this.color, required this.bgColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(14)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF1A1A1A))),
                const SizedBox(height: 4),
                Text(desc, style: TextStyle(fontSize: 12, color: Colors.grey[600], height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
