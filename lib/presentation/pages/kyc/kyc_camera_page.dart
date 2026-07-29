import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/theme/app_colors.dart';
import 'widgets/kyc_overlay_painter.dart';

export 'widgets/kyc_overlay_painter.dart' show KycOverlayMode;

class KycCameraPage extends StatefulWidget {
  final KycOverlayMode mode;

  const KycCameraPage({super.key, required this.mode});

  @override
  State<KycCameraPage> createState() => _KycCameraPageState();
}

class _KycCameraPageState extends State<KycCameraPage> {
  String? _capturedPath;
  bool _isPicking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _takePhoto());
  }

  Future<void> _takePhoto() async {
    if (_isPicking) return;
    _isPicking = true;
    try {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Kami butuh akses kamera Anda untuk melanjutkan verifikasi.')),
          );
          Navigator.pop(context);
        }
        return;
      }

      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: widget.mode == KycOverlayMode.selfie
            ? CameraDevice.front
            : CameraDevice.rear,
        imageQuality: 85,
        maxWidth: 1280,
      );

      if (!mounted) return;

      if (file != null) {
        setState(() => _capturedPath = file.path);
      } else {
        // User cancelled picker
        if (_capturedPath == null) {
          Navigator.pop(context);
        }
      }
    } finally {
      _isPicking = false;
    }
  }

  void _retake() async {
    setState(() => _capturedPath = null);
    await _takePhoto();
  }

  void _confirm() {
    if (_capturedPath != null) {
      Navigator.pop(context, _capturedPath);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _capturedPath == null ? _buildPicking() : _buildPreview(),
    );
  }

  Widget _buildPicking() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 24),
          const Text('Membuka kamera...', style: TextStyle(color: Colors.white)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _takePhoto,
            icon: const Icon(Icons.camera_alt_rounded),
            label: const Text('Buka Kamera'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: widget.mode == KycOverlayMode.selfie
                    ? Image.file(File(_capturedPath!), fit: BoxFit.cover)
                    : Image.file(File(_capturedPath!), fit: BoxFit.contain),
              ),
              Positioned.fill(
                child: CustomPaint(
                  painter: KycOverlayPainter(mode: widget.mode),
                ),
              ),
              Positioned(
                top: MediaQuery.of(context).padding.top + 12,
                left: 16,
                child: _CircleBtn(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: () => Navigator.pop(context),
                ),
              ),
              Positioned(
                bottom: 100,
                left: 24,
                right: 24,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Text(
                      widget.mode == KycOverlayMode.selfie
                          ? 'Posisikan wajah dalam lingkaran'
                          : 'Posisikan KTP dalam kotak',
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Apakah foto sudah jelas?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A)),
              ),
              const SizedBox(height: 6),
              const Text(
                'Pastikan tidak blur dan data terbaca.',
                style: TextStyle(fontSize: 13, color: Color(0xFF888888)),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _retake,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1A1A1A),
                        side: const BorderSide(color: Color(0xFFE5E7EB)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Ulangi', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _confirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Pakai Foto Ini', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black45,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white30),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}
