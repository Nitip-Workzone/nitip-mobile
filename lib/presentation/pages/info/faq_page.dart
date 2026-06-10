import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class FaqPage extends StatelessWidget {
  const FaqPage({super.key});

  @override
  Widget build(BuildContext context) {
    final faqs = [
      {
        'q': 'Apa itu e-KYC Nitip?',
        'a': 'Proses verifikasi identitas resmi untuk memastikan setiap pengguna adalah individu yang valid dan dapat dipercaya dalam komunitas Nitip.',
      },
      {
        'q': 'Mengapa saya perlu melakukan verifikasi?',
        'a': 'Verifikasi membantu membangun kepercayaan. Untuk Runner, ini wajib untuk mengambil pesanan dan meningkatkan Trust Score. Untuk Penitip, ini meningkatkan batas saldo dan prioritas keamanan.',
      },
      {
        'q': 'Data apa saja yang dikumpulkan?',
        'a': 'Kami memerlukan foto KTP asli dan foto Selfie untuk proses pencocokan wajah otomatis. Kami tidak menyimpan data sensitif selain untuk keperluan identifikasi.',
      },
      {
        'q': 'Apakah data saya aman?',
        'a': 'Sangat aman. Data Anda dienkripsi dan hanya digunakan untuk verifikasi internal oleh sistem dan admin Nitip. Kami tidak membagikan data Anda ke pihak ketiga.',
      },
      {
        'q': 'Berapa lama proses verifikasi?',
        'a': 'Proses peninjauan biasanya memakan waktu maksimal 1x24 jam kerja.',
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('FAQ & Bantuan'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textMain,
        elevation: 0,
      ),
      backgroundColor: AppColors.surface,
      body: ListView.separated(
        padding: const EdgeInsets.all(24),
        itemCount: faqs.length,
        separatorBuilder: (context, index) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: ExpansionTile(
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
              title: Text(
                faqs[index]['q']!,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.textMain,
                ),
              ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              expandedAlignment: Alignment.topLeft,
              children: [
                Text(
                  faqs[index]['a']!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
