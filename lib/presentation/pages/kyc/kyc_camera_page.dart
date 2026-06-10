import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/theme/app_colors.dart';
import 'widgets/kyc_overlay_painter.dart';

export 'widgets/kyc_overlay_painter.dart' show KycOverlayMode;

enum _KycCameraStep { camera, preview }

class KycCameraPage extends StatefulWidget {
  final KycOverlayMode mode;

  const KycCameraPage({super.key, required this.mode});

  @override
  State<KycCameraPage> createState() => _KycCameraPageState();
}

class _KycCameraPageState extends State<KycCameraPage> with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _cameraIndex = 0;
  bool _isPermissionGranted = false;
  bool _isInitializing = false;
  _KycCameraStep _step = _KycCameraStep.camera;
  String? _capturedPath;

  static const Color _kGreen = AppColors.primary;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Delay untuk memastikan widget sudah fully rendered
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _startCamera(_cameras[_cameraIndex]);
    }
  }

  Future<void> _initialize() async {
    final status = await Permission.camera.request();
    if (!status.isGranted || !mounted) return;

    setState(() => _isPermissionGranted = true);
    _cameras = await availableCameras();

    // Pilih kamera yang sesuai
    int targetIndex = _cameras.indexWhere(
      (c) => widget.mode == KycOverlayMode.selfie
          ? c.lensDirection == CameraLensDirection.front
          : c.lensDirection == CameraLensDirection.back,
    );
    _cameraIndex = targetIndex == -1 ? 0 : targetIndex;

    await _startCamera(_cameras[_cameraIndex]);
  }

  Future<void> _startCamera(CameraDescription cam) async {
    if (_isInitializing) return;
    _isInitializing = true;

    // Dispose controller lama jika ada
    final oldController = _controller;
    if (oldController != null) {
      setState(() => _controller = null);
      await oldController.dispose();
    }

    final newController = CameraController(
      cam,
      ResolutionPreset.medium,
      enableAudio: false,
      // Tidak memaksa format — biarkan driver kamera memilih sendiri
      // Ini adalah fix utama untuk kamera depan Huawei yang blank
    );

    try {
      await newController.initialize();
    } catch (e) {
      debugPrint('Camera init error: $e');
      _isInitializing = false;
      return;
    }

    if (!mounted) {
      newController.dispose();
      _isInitializing = false;
      return;
    }

    setState(() {
      _controller = newController;
      _isInitializing = false;
    });
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    await _startCamera(_cameras[_cameraIndex]);
  }

  Future<void> _capturePhoto() async {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized || ctrl.value.isTakingPicture) return;

    try {
      final XFile photo = await ctrl.takePicture();
      setState(() {
        _capturedPath = photo.path;
        _step = _KycCameraStep.preview;
      });
    } catch (e) {
      debugPrint('Capture error: $e');
    }
  }

  void _retake() {
    setState(() {
      _capturedPath = null;
      _step = _KycCameraStep.camera;
    });
  }

  void _confirm() {
    if (_capturedPath != null) {
      Navigator.pop(context, _capturedPath);
    }
  }

  bool get _isCameraReady =>
      _isPermissionGranted &&
      _controller != null &&
      _controller!.value.isInitialized;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _step == _KycCameraStep.preview ? _buildPreview() : _buildCamera(),
    );
  }

  // ── Camera View ──────────────────────────────────────────────────────────────
  Widget _buildCamera() {
    if (!_isPermissionGranted) {
      return const Center(
        child: Text('Izin kamera diperlukan', style: TextStyle(color: Colors.white)),
      );
    }

    if (!_isCameraReady || _isInitializing) {
      return const Center(child: CircularProgressIndicator(color: _kGreen));
    }

    return Stack(
      children: [
        // ── Camera preview - full screen, no constraints ──
        Positioned.fill(
          child: CameraPreview(_controller!),
        ),

        // ── Overlay guide frame ──
        Positioned.fill(
          child: CustomPaint(
            painter: KycOverlayPainter(mode: widget.mode),
          ),
        ),

        // ── Top bar ──
        Positioned(
          top: MediaQuery.of(context).padding.top + 12,
          left: 16,
          right: 16,
          child: Row(
            children: [
              _CircleBtn(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: () => Navigator.pop(context),
              ),
              const Spacer(),
              if (_cameras.length > 1)
                _CircleBtn(
                  icon: Icons.flip_camera_android_rounded,
                  onTap: _switchCamera,
                ),
            ],
          ),
        ),

        // ── Instruction label ──
        Positioned(
          bottom: 160,
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

        // ── Shutter button ──
        Positioned(
          bottom: 60,
          left: 0,
          right: 0,
          child: Center(
            child: GestureDetector(
              onTap: _capturePhoto,
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                ),
                child: Center(
                  child: Container(
                    width: 58,
                    height: 58,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Preview View ──────────────────────────────────────────────────────────────
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
                        side: BorderSide(color: Colors.grey[300]!),
                        minimumSize: const Size(0, 52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Ambil Ulang', style: TextStyle(color: Color(0xFF1A1A1A))),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _confirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        minimumSize: const Size(0, 52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Gunakan Foto', style: TextStyle(fontWeight: FontWeight.bold)),
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
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}
