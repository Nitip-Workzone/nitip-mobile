import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screen_protector/screen_protector.dart';

class PinInputSheet extends ConsumerStatefulWidget {
  final Function(String pin) onConfirm;
  final String title;

  const PinInputSheet({
    super.key,
    required this.onConfirm,
    this.title = 'Masukkan PIN Transaksi',
  });

  @override
  ConsumerState<PinInputSheet> createState() => _PinInputSheetState();
}

class _PinInputSheetState extends ConsumerState<PinInputSheet> {
  String pin = '';

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
    if (pin.length < 6) {
      setState(() {
        pin += val;
      });
      if (pin.length == 6) {
        widget.onConfirm(pin);
        Navigator.pop(context);
      }
    }
  }

  void _onBackspace() {
    if (pin.isNotEmpty) {
      setState(() {
        pin = pin.substring(0, pin.length - 1);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            widget.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 32),
          // PIN Dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(6, (index) {
              bool isFilled = index < pin.length;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 10),
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isFilled ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                  border: isFilled 
                    ? null 
                    : Border.all(color: const Color(0xFFCBD5E1), width: 1),
                ),
              );
            }),
          ),
          const SizedBox(height: 48),
          // Keypad
          _buildKeypad(),
          const SizedBox(height: 24),
        ],
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
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildKey('4'),
            _buildKey('5'),
            _buildKey('6'),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildKey('7'),
            _buildKey('8'),
            _buildKey('9'),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const SizedBox(width: 80, height: 80),
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
            fontSize: 28,
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
          color: Color(0xFF64748B),
          size: 24,
        ),
      ),
    );
  }
}
