import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screen_protector/screen_protector.dart';
import '../../providers/auth_provider.dart';

class PinSetupPage extends ConsumerStatefulWidget {
  const PinSetupPage({super.key});

  @override
  ConsumerState<PinSetupPage> createState() => _PinSetupPageState();
}

class _PinSetupPageState extends ConsumerState<PinSetupPage> {
  String firstPin = '';
  String confirmPin = '';
  bool isConfirming = false;
  String error = '';

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

  void _onKeyTap(String val) {
    setState(() {
      error = '';
      if (!isConfirming) {
        if (firstPin.length < 6) firstPin += val;
        if (firstPin.length == 6) {
          Future.delayed(const Duration(milliseconds: 300), () {
            setState(() => isConfirming = true);
          });
        }
      } else {
        if (confirmPin.length < 6) confirmPin += val;
        if (confirmPin.length == 6) {
          _submit();
        }
      }
    });
  }

  void _onBackspace() {
    setState(() {
      error = '';
      if (!isConfirming) {
        if (firstPin.isNotEmpty) firstPin = firstPin.substring(0, firstPin.length - 1);
      } else {
        if (confirmPin.isNotEmpty) {
          confirmPin = confirmPin.substring(0, confirmPin.length - 1);
        } else {
          isConfirming = false;
        }
      }
    });
  }

  Future<void> _submit() async {
    if (firstPin != confirmPin) {
      setState(() {
        error = 'PIN tidak cocok. Silakan coba lagi.';
        confirmPin = '';
      });
      return;
    }

    try {
      await ref.read(authProvider.notifier).setupPin(firstPin);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PIN berhasil diatur'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
        Navigator.pop(context, firstPin);
      }
    } catch (e) {
      setState(() {
        error = e.toString();
        confirmPin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            Text(
              isConfirming ? 'Konfirmasi PIN Baru' : 'Atur PIN Transaksi',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                isConfirming 
                  ? 'Masukkan kembali 6 digit PIN Anda untuk verifikasi.'
                  : 'Gunakan 6 digit angka untuk mengamankan transaksi penarikan dana Anda.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 48),
            // PIN Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (index) {
                String current = isConfirming ? confirmPin : firstPin;
                bool isFilled = index < current.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFilled ? const Color(0xFF2563EB) : const Color(0xFFF1F5F9),
                    border: isFilled 
                      ? null 
                      : Border.all(color: const Color(0xFFE2E8F0), width: 2),
                  ),
                );
              }),
            ),
            if (error.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                error,
                style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ],
            const Spacer(),
            // Keypad
            _buildKeypad(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypad() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildKey('1'),
            _buildKey('2'),
            _buildKey('3'),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildKey('4'),
            _buildKey('5'),
            _buildKey('6'),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildKey('7'),
            _buildKey('8'),
            _buildKey('9'),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const SizedBox(width: 80),
            _buildKey('0'),
            _buildBackspaceKey(),
          ],
        ),
      ],
    );
  }

  Widget _buildKey(String val) {
    return InkWell(
      onTap: () => _onKeyTap(val),
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 80,
        height: 80,
        alignment: Alignment.center,
        child: Text(
          val,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
          ),
        ),
      ),
    );
  }

  Widget _buildBackspaceKey() {
    return InkWell(
      onTap: _onBackspace,
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 80,
        height: 80,
        alignment: Alignment.center,
        child: const Icon(
          Icons.backspace_rounded,
          color: Color(0xFF1E293B),
          size: 28,
        ),
      ),
    );
  }
}
