import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/config/app_config.dart';
import '../../../core/services/crash_service.dart';

/// Reusable error widget for WebView 500 / "Terjadi Gangguan Pada Server"
/// Best practice: no bloat, shows retry + open external + report
class WebViewErrorWidget extends StatelessWidget {
  final String? failingUrl;
  final VoidCallback onRetry;
  final String title;
  final String message;

  const WebViewErrorWidget({
    super.key,
    this.failingUrl,
    required this.onRetry,
    this.title = 'Gagal Memuat Peta',
    this.message = 'Server web.nihtip.com sedang gangguan (500) atau internet terputus.',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.cloud_off_rounded, size: 40, color: Colors.orange),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textMain),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          if (failingUrl != null) ...[
            const SizedBox(height: 8),
            Text(
              failingUrl!,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 10, fontFamily: 'monospace'),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final url = failingUrl != null ? Uri.tryParse(failingUrl!) : null;
                final fallback = url ?? Uri.parse('${AppConfig.webBaseUrl}/map/viewer');
                if (await canLaunchUrl(fallback)) {
                  await launchUrl(fallback, mode: LaunchMode.externalApplication);
                }
              },
              icon: const Icon(Icons.open_in_browser_rounded, size: 18),
              label: const Text('Buka di Browser'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              CrashService.logError(
                'Manual WebView error report',
                null,
                reason: 'webview_manual_report',
                extras: {'url': failingUrl ?? 'unknown', 'webBaseUrl': AppConfig.webBaseUrl},
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Laporan error dikirim ke Crashlytics')),
              );
            },
            child: const Text('Laporkan Error', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }
}
