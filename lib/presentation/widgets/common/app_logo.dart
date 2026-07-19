import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Widget logo aplikasi Nitip yang konsisten di seluruh UI.
/// Menggunakan logo 1-color vector-based yang modern, bersih, dan premium.
class AppLogo extends StatelessWidget {
  final double size;
  final Color? color;
  final bool showText;
  final double fontSize;
  final bool darkMode;

  const AppLogo({
    super.key,
    this.size = 24,
    this.color,
    this.showText = true,
    this.fontSize = 18,
    this.darkMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? (darkMode ? Colors.white : AppColors.primary);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Premium 1-color vector brand icon
        Container(
          width: size * 1.5,
          height: size * 1.5,
          decoration: BoxDecoration(
            color: effectiveColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(size * 0.42),
            border: Border.all(
              color: effectiveColor.withValues(alpha: 0.12),
              width: size * 0.08,
            ),
          ),
          child: Center(
            child: Image.asset(
              darkMode ? 'assets/images/logo_white.png' : 'assets/images/logo_premium.png',
              width: size * 1.2,
              height: size * 1.2,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Icon(
                Icons.shopping_bag_rounded,
                color: effectiveColor,
                size: size * 0.75,
              ),
            ),
          ),
        ),
        if (showText) ...[
          SizedBox(width: size * 0.4),
          Text(
            'NITIP',
            style: TextStyle(
              color: effectiveColor,
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
        ],
      ],
    );
  }
}
