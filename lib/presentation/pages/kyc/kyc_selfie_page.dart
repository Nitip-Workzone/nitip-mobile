import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screen_protector/screen_protector.dart';
import 'kyc_camera_page.dart';
import '../../providers/kyc_provider.dart';

import '../../../../core/theme/app_colors.dart';
const Color _kGreen = AppColors.primary;
const Color _kGreenLight = AppColors.primaryLight;

class KycSelfiePage extends ConsumerStatefulWidget {
  final String ktpPath;
  final String idCardNumber;

  const KycSelfiePage({super.key, required this.ktpPath, required this.idCardNumber});

  @override
  ConsumerState<KycSelfiePage> createState() => _KycSelfiePageState();
}

class _KycSelfiePageState extends ConsumerState<KycSelfiePage> {
  String? _selfiePath;

  @override
  void initState() {
    super.initState();
    ScreenProtector.preventScreenshotOn();
    ScreenProtector.protectDataLeakageOn();
  }

  @override
  void dispose() {
    ScreenProtector.preventScreenshotOff();
    ScreenProtector.protectDataLeakageOff();
    super.dispose();
  }

  Future<void> _openCamera() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const KycCameraPage(mode: KycOverlayMode.selfie),
      ),
    );
    if (result != null) {
      setState(() => _selfiePath = result);
    }
  }

  Future<void> _onSubmit() async {
    if (_selfiePath == null) return;

    await ref.read(kycProvider.notifier).submit(
          idCardNumber: widget.idCardNumber,
          idCardPath: widget.ktpPath,
          selfiePath: _selfiePath!,
        );

    if (mounted) {
      final kycState = ref.read(kycProvider);
      if (kycState.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(kycState.error!),
            backgroundColor: Colors.red,
          ),
        );
      } else if (kycState.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('KTP & Selfie berhasil disubmit! Menunggu verifikasi.'),
            backgroundColor: _kGreen,
          ),
        );
        // Pop kembali ke root
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final kycState = ref.watch(kycProvider);

    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.white,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1A1A1A)),
              onPressed: () => Navigator.pop(context),
            ),
            title: const _StepIndicator(current: 2, total: 3),
            centerTitle: true,
          ),
          body: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: kToolbarHeight + 20),
                      // Illustration
                      SizedBox(
                        height: 200,
                        child: Image.asset(
                          'assets/images/kyc_selfie.png',
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.face_retouching_natural_rounded,
                            size: 100,
                            color: _kGreen,
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),
                      const Text(
                        'Verifikasi Wajah',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A)),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Foto selfie Anda akan digunakan untuk mencocokkan wajah dengan foto KTP.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.6),
                      ),

                      const SizedBox(height: 28),

                      // Preview if captured
                      if (_selfiePath != null) ...[
                        Center(
                          child: ClipOval(
                            child: Image.file(
                              File(_selfiePath!),
                              width: 180,
                              height: 180,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextButton.icon(
                          onPressed: _openCamera,
                          icon: const Icon(Icons.refresh_rounded, color: _kGreen),
                          label: const Text('Foto Ulang', style: TextStyle(color: _kGreen)),
                        ),
                        const SizedBox(height: 16),
                      ] else ...[
                        // Take selfie button
                        InkWell(
                          onTap: _openCamera,
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.grey[200]!),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(color: _kGreenLight, borderRadius: BorderRadius.circular(12)),
                                  child: const Icon(Icons.camera_front_rounded, color: _kGreen, size: 26),
                                ),
                                const SizedBox(width: 16),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Ambil Selfie', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF1A1A1A))),
                                      SizedBox(height: 4),
                                      Text('Gunakan kamera depan perangkat Anda', style: TextStyle(fontSize: 12, color: Color(0xFF888888))),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Color(0xFFBBBBBB)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Tips
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _kGreenLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            _TipRow(icon: Icons.light_mode_outlined, text: 'Pastikan wajah terkena cahaya yang cukup'),
                            const SizedBox(height: 8),
                            _TipRow(icon: Icons.face_outlined, text: 'Lepaskan kacamata, masker, atau aksesori wajah'),
                            const SizedBox(height: 8),
                            _TipRow(icon: Icons.crop_free_rounded, text: 'Tempatkan wajah di tengah lingkaran panduan'),
                          ],
                        ),
                      ),
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
                    onPressed: _selfiePath != null && !kycState.isLoading ? _onSubmit : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kGreen,
                      disabledBackgroundColor: Colors.grey[200],
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: kycState.isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Kirim Verifikasi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (kycState.isLoading)
          Container(
            color: Colors.black.withValues(alpha: 0.3),
            child: const Center(
              child: CircularProgressIndicator(color: _kGreen),
            ),
          ),
      ],
    );
  }
}

class _TipRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _TipRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: _kGreen, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: TextStyle(fontSize: 12, color: Colors.grey[700]))),
      ],
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final int current;
  final int total;

  const _StepIndicator({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total, (i) {
        final isActive = i + 1 == current;
        final isDone = i + 1 < current;
        return Row(
          children: [
            if (i > 0)
              Container(width: 24, height: 2, color: isDone ? _kGreen : Colors.grey[300]),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive ? _kGreen : (isDone ? _kGreen : Colors.grey[200]),
              ),
              child: Center(
                child: isDone
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isActive ? Colors.white : Colors.grey[500],
                        ),
                      ),
              ),
            ),
          ],
        );
      }),
    );
  }
}
