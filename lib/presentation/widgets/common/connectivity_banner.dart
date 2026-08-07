import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/connectivity_provider.dart';

/// A non-intrusive banner that appears at the top of the screen when the device
/// is offline. Automatically hides when connectivity is restored.
class ConnectivityBanner extends ConsumerWidget {
  final Widget child;

  const ConnectivityBanner({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivityState = ref.watch(connectivityProvider);
    final isOffline = connectivityState.status == ConnectivityStatus.isDisconnected;
    final isPoor = connectivityState.isPoorConnection && !isOffline;

    final showBanner = isOffline || isPoor;
    final bannerColor = isOffline
        ? AppColors.error.withValues(alpha: 0.9)
        : Colors.orange.shade800.withValues(alpha: 0.9);
    final bannerIcon = isOffline ? Icons.wifi_off_rounded : Icons.wifi_tethering_error_rounded;
    final bannerText = isOffline ? 'Tidak ada koneksi internet' : 'Koneksi internet lambat / tidak stabil';

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          height: showBanner ? 36 : 0,
          child: showBanner
              ? Container(
                  width: double.infinity,
                  color: bannerColor,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(bannerIcon, color: Colors.white, size: 14),
                      const SizedBox(width: 8),
                      Text(
                        bannerText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
        Expanded(child: child),
      ],
    );
  }
}