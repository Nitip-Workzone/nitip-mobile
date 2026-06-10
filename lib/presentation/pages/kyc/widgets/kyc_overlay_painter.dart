import 'package:flutter/material.dart';

enum KycOverlayMode { ktp, selfie }

class KycOverlayPainter extends CustomPainter {
  final KycOverlayMode mode;

  KycOverlayPainter({required this.mode});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;

    final path = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    if (mode == KycOverlayMode.ktp) {
      // KTP Frame (Rectangle)
      final width = size.width * 0.85;
      final height = width / 1.58; // Standard ID Card Ratio
      final rect = Rect.fromCenter(
        center: Offset(size.width / 2, size.height * 0.45),
        width: width,
        height: height,
      );
      path.addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(16)));
    } else {
      // Selfie Frame (Circle/Oval)
      final width = size.width * 0.7;
      final height = width * 1.3;
      final rect = Rect.fromCenter(
        center: Offset(size.width / 2, size.height * 0.45),
        width: width,
        height: height,
      );
      path.addOval(rect);
    }

    // Use fillType evenOdd to create a "hole"
    path.fillType = PathFillType.evenOdd;
    canvas.drawPath(path, paint);

    // Draw Border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    if (mode == KycOverlayMode.ktp) {
      final width = size.width * 0.85;
      final height = width / 1.58;
      final rect = Rect.fromCenter(
        center: Offset(size.width / 2, size.height * 0.45),
        width: width,
        height: height,
      );
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(16)), borderPaint);
    } else {
      final width = size.width * 0.7;
      final height = width * 1.3;
      final rect = Rect.fromCenter(
        center: Offset(size.width / 2, size.height * 0.45),
        width: width,
        height: height,
      );
      canvas.drawOval(rect, borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
