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
    final connectivityStatus = ref.watch(connectivityProvider);
    final isOffline = connectivityStatus == ConnectivityStatus.isDisconnected;

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          height: isOffline ? 36 : 0,
          child: isOffline
              ? Container(
                  width: double.infinity,
                  color: AppColors.error.withValues(alpha: 0.9),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.wifi_off_rounded, color: Colors.white, size: 14),
                      SizedBox(width: 8),
                      Text(
                        'Tidak ada koneksi internet',
                        style: TextStyle(
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