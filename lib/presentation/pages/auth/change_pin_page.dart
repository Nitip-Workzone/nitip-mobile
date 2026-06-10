import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screen_protector/screen_protector.dart';
import '../../providers/auth_provider.dart';

class ChangePinPage extends ConsumerStatefulWidget {
  const ChangePinPage({super.key});

  @override
  ConsumerState<ChangePinPage> createState() => _ChangePinPageState();
}

class _ChangePinPageState extends ConsumerState<ChangePinPage> {
  // Step 0 = enter old PIN, 1 = enter new PIN, 2 = confirm new PIN
  int step = 0;
  String oldPin = '';
  String newPin = '';
  String confirmPin = '';
  String error = '';
  bool isLoading = false;

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

  String get _currentPin {
    switch (step) {
      case 0: return oldPin;
      case 1: return newPin;
      case 2: return confirmPin;
      default: return '';
    }
  }

  set _currentPin(String val) {
    switch (step) {
      case 0: oldPin = val; break;
      case 1: newPin = val; break;
      case 2: confirmPin = val; break;
    }
  }

  String get _title {
    switch (step) {
      case 0: return 'PIN Lama';
      case 1: return 'PIN Baru';
      case 2: return 'Konfirmasi PIN';
      default: return '';
    }
  }

  String get _subtitle {
    switch (step) {
      case 0: return 'Masukkan 6 digit PIN lama Anda untuk verifikasi.';
      case 1: return 'Gunakan 6 digit angka baru untuk PIN transaksi Anda.';
      case 2: return 'Masukkan kembali 6 digit PIN baru untuk verifikasi.';
      default: return '';
    }
  }

  Color _dotColor(bool isFilled) {
    if (step == 0) {
      return isFilled ? const Color(0xFF2563EB) : const Color(0xFFF1F5F9);
    }
    return isFilled ? const Color(0xFF16A34A) : const Color(0xFFF1F5F9);
  }

  void _onKeyTap(String val) {
    if (isLoading) return;
    setState(() {
      error = '';
      if (_currentPin.length < 6) {
        _currentPin = _currentPin + val;
      }
      if (_currentPin.length == 6) {
        _onPinComplete();
      }
    });
  }

  void _onBackspace() {
    if (isLoading) return;
    setState(() {
      error = '';
      if (_currentPin.isNotEmpty) {
        _currentPin = _currentPin.substring(0, _currentPin.length - 1);
      }
    });
  }

  Future<void> _onPinComplete() async {
    if (step == 0) {
      // Old PIN entered, verify with backend first
      setState(() => isLoading = true);
      try {
        await ref.read(authProvider.notifier).verifyPin(oldPin);
        // PIN verified successfully
        if (mounted) {
          setState(() {
            isLoading = false;
            step = 1;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            isLoading = false;
            error = e.toString().replaceAll('Exception: ', '');
            oldPin = '';
          });
        }
      }
    } else if (step == 1) {
      // New PIN entered, move to confirm step
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) {
        setState(() => step = 2);
      }
    } else {
      // Confirm PIN entered, validate and submit
      if (newPin != confirmPin) {
        setState(() {
          error = 'PIN tidak cocok. Silakan ulangi.';
          confirmPin = '';
        });
        return;
      }
      if (oldPin == newPin) {
        setState(() {
          error = 'PIN baru tidak boleh sama dengan PIN lama.';
          newPin = '';
          confirmPin = '';
          step = 1;
        });
        return;
      }

      setState(() => isLoading = true);

      try {
        await ref.read(authProvider.notifier).changePin(oldPin, newPin);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PIN berhasil diubah'),
              backgroundColor: Color(0xFF16A34A),
            ),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            isLoading = false;
            error = e.toString().replaceAll('Exception: ', '');
            // Reset to old PIN step on error
            oldPin = '';
            newPin = '';
            confirmPin = '';
            step = 0;
          });
        }
      }
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
              _title,
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
                _subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                  height: 1.5,
                ),
              ),
            ),
            // Step indicator
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == step ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i <= step
                        ? (step == 0 ? const Color(0xFF2563EB) : const Color(0xFF16A34A))
                        : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            const SizedBox(height: 40),
            // PIN Dots
            if (isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (index) {
                  bool isFilled = index < _currentPin.length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _dotColor(isFilled),
                      border: isFilled
                          ? null
                          : Border.all(color: const Color(0xFFE2E8F0), width: 2),
                    ),
                  );
                }),
              ),
            if (error.isNotEmpty) ...[
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  error,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
            ],
            const Spacer(),
            // Keypad
            if (!isLoading) _buildKeypad(),
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
          children: [_buildKey('1'), _buildKey('2'), _buildKey('3')],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [_buildKey('4'), _buildKey('5'), _buildKey('6')],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [_buildKey('7'), _buildKey('8'), _buildKey('9')],
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