import 'package:flutter/material.dart';

class WithdrawInquiryCard extends StatelessWidget {
  final String accountName;
  final String accountNo;
  final String bankName;
  final String? logoPath;

  const WithdrawInquiryCard({
    super.key,
    required this.accountName,
    required this.accountNo,
    required this.bankName,
    this.logoPath,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified_user_rounded, color: Color(0xFF16A34A), size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'Rekening Terverifikasi',
                      style: TextStyle(
                        color: const Color(0xFF16A34A),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (logoPath != null)
                Image.asset(logoPath!, height: 24, errorBuilder: (_, __, ___) => const SizedBox())
              else
                const Icon(Icons.account_balance_rounded, color: Color(0xFF64748B), size: 24),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            accountName.toUpperCase(),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1E293B),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                bankName,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: Color(0xFFCBD5E1),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                accountNo,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: Color(0xFFF1F5F9), height: 1),
          const SizedBox(height: 16),
          const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: Color(0xFF94A3B8), size: 14),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Pastikan nama pemilik rekening sudah sesuai untuk menghindari kesalahan transfer.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
