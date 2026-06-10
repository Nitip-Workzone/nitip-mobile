import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:screen_protector/screen_protector.dart';
import 'kyc_camera_page.dart';
import 'kyc_selfie_page.dart';

import '../../../../core/theme/app_colors.dart';
const Color _kGreen = AppColors.primary;
const Color _kGreenLight = AppColors.primaryLight;

class KycKtpPage extends StatefulWidget {
  const KycKtpPage({super.key});

  @override
  State<KycKtpPage> createState() => _KycKtpPageState();
}

class _KycKtpPageState extends State<KycKtpPage> {
  String? _ktpPath;
  final _nikController = TextEditingController();

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
    _nikController.dispose();
    super.dispose();
  }

  Future<void> _pickFromGallery() async {
    // Check permission for photos/storage
    PermissionStatus status;
    if (Platform.isAndroid) {
      status = await Permission.photos.status;
      if (status.isDenied) {
        status = await Permission.photos.request();
      }
      if (status.isDenied) {
        status = await Permission.storage.request();
      }
    } else {
      status = await Permission.photos.request();
    }

    if (status.isGranted || status.isLimited) {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (file != null) {
        setState(() => _ktpPath = file.path);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Izin galeri diperlukan untuk memilih foto.')),
        );
      }
    }
  }

  Future<void> _pickFromCamera() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const KycCameraPage(mode: KycOverlayMode.ktp),
      ),
    );
    if (result != null) {
      setState(() => _ktpPath = result);
    }
  }

  void _onNext() {
    if (_ktpPath == null) return;
    if (_nikController.text.length < 16) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('NIK harus 16 digit')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => KycSelfiePage(
          ktpPath: _ktpPath!,
          idCardNumber: _nikController.text,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
        title: const _StepIndicator(current: 1, total: 3),
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
                    height: 160,
                    child: Image.asset(
                      'assets/images/kyc_ktp.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.credit_card_rounded,
                        size: 100,
                        color: _kGreen,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  const Text(
                    'Foto KTP Anda',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A)),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Masukkan NIK dan upload foto KTP asli Anda yang masih berlaku.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.6),
                  ),

                  const SizedBox(height: 28),

                  // NIK Input
                  TextField(
                    controller: _nikController,
                    keyboardType: TextInputType.number,
                    maxLength: 16,
                    decoration: InputDecoration(
                      labelText: 'Nomor NIK',
                      hintText: 'Masukkan 16 digit NIK',
                      prefixIcon: const Icon(Icons.badge_outlined),
                      counterText: '',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _kGreen, width: 2),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Preview if captured
                  if (_ktpPath != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.file(
                        File(_ktpPath!),
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: () => setState(() => _ktpPath = null),
                      icon: const Icon(Icons.refresh_rounded, color: _kGreen),
                      label: const Text('Ambil Ulang', style: TextStyle(color: _kGreen)),
                    ),
                  ] else ...[
                    // Option: Camera
                    _OptionCard(
                      icon: Icons.camera_alt_outlined,
                      title: 'Ambil Foto Langsung',
                      desc: 'Gunakan kamera belakang untuk memfoto KTP',
                      onTap: _pickFromCamera,
                    ),
                    const SizedBox(height: 14),
                    // Option: Gallery / File
                    _OptionCard(
                      icon: Icons.photo_library_outlined,
                      title: 'Pilih dari Galeri',
                      desc: 'Upload foto KTP dari galeri perangkat Anda',
                      onTap: _pickFromGallery,
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Tips
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _kGreenLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Column(
                      children: [
                        _TipRow(icon: Icons.light_mode_outlined, text: 'Pastikan pencahayaan cukup, hindari kilat'),
                        SizedBox(height: 8),
                        _TipRow(icon: Icons.crop_free_rounded, text: 'Seluruh kartu harus masuk dalam bingkai'),
                        SizedBox(height: 8),
                        _TipRow(icon: Icons.text_fields_rounded, text: 'Pastikan teks NIK dan nama terbaca jelas'),
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
                onPressed: _ktpPath != null ? _onNext : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kGreen,
                  disabledBackgroundColor: Colors.grey[200],
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Lanjut ke Selfie', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  final VoidCallback onTap;

  const _OptionCard({required this.icon, required this.title, required this.desc, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
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
              child: Icon(icon, color: _kGreen, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF1A1A1A))),
                  const SizedBox(height: 4),
                  Text(desc, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Color(0xFFBBBBBB)),
          ],
        ),
      ),
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
