import 'dart:io';
import 'package:nitip_flutter_mobile/presentation/widgets/common/safe_webview_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../domain/models/order_model.dart';
import '../../providers/activity_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/explore_orders_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/order_status_provider.dart';
import 'qr_scanner_page.dart';



class OrderDetailPage extends ConsumerStatefulWidget {
  final String orderId;

  const OrderDetailPage({super.key, required this.orderId});

  @override
  ConsumerState<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends ConsumerState<OrderDetailPage> {
  bool _isProcessing = false;
  bool _localCompleted = false; // low-burden guard to prevent revert to ready after complete
  bool _hasShownReadySnack = false;
  WebViewController? _mapWebViewController;
  WebViewController? _previewMapWebViewController;
  bool _isMapLoading = true;
  bool _hasMapError = false;
  bool _isPreviewMapLoading = true;
  bool _hasPreviewMapError = false;
  String? _lastMapStatus; // Track status to detect changes
  String? _lastNotifiedStatus;

  @override
  void initState() {
    super.initState();
    // Trigger order status realtime provider early (autoDispose family)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // ignore return, provider will start connect
        ref.read(orderStatusProvider(widget.orderId));
      }
    });
  }

  OrderModel _resolveOrder(
      ActivityState activityState,
      ExploreOrdersState exploreState,
      OrderStatusState? realtimeState,
      ) {
    OrderModel base = activityState.activeOrders.firstWhere(
          (o) => o.id == widget.orderId,
      orElse: () => activityState.pastOrders.firstWhere(
            (o) => o.id == widget.orderId,
        orElse: () => exploreState.availableOrders.firstWhere(
              (o) => o.id == widget.orderId,
          orElse: () => OrderModel.empty(),
        ),
      ),
    );

    // Local completed guard – highest priority after actual completed status
    if (_localCompleted && base.id.isNotEmpty) {
      if (base.status != 'completed') {
        return base.copyWith(status: 'completed');
      }
      return base;
    }

    // Realtime status overrides cache if newer and not stale
    if (realtimeState != null && realtimeState.status.isNotEmpty && base.id.isNotEmpty) {
      final rtStatus = realtimeState.status.toLowerCase();
      // If base already completed, keep completed (lock)
      if (base.status == 'completed') return base;
      // If realtime says completed, respect it
      if (rtStatus == 'completed') {
        if (base.status != rtStatus) {
          return base.copyWith(status: rtStatus);
        }
      } else if (base.status != rtStatus) {
        // Only override if not locked completed
        // Simple heuristic: realtime newer than base
        return base.copyWith(status: rtStatus);
      }
    }

    return base;
  }

  void _initPreviewMapWebView(OrderModel order) {
    final url = Uri.parse('${AppConfig.webBaseUrl}/map/route').replace(queryParameters: {
      'origin_lat': order.pickupLat.toString(),
      'origin_lng': order.pickupLng.toString(),
      'dest_lat': order.deliveryLat.toString(),
      'dest_lng': order.deliveryLng.toString(),
    });
    _previewMapWebViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() => _isPreviewMapLoading = true);
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _isPreviewMapLoading = false);
        },
        onWebResourceError: (error) {
          if (error.isForMainFrame ?? true) {
            if (mounted) {
              setState(() {
                _hasPreviewMapError = true;
                _isPreviewMapLoading = false;
              });
            }
          }
        },
      ))
      ..loadRequest(url);
  }

  Widget _buildPreviewRouteMap(OrderModel order, Color primary) {
    if (order.pickupLat == 0 && order.pickupLng == 0) {
      return const SizedBox.shrink();
    }
    if (_previewMapWebViewController == null) {
      _initPreviewMapWebView(order);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Pratinjau Rute Peta'),
        const SizedBox(height: 8),
        Container(
          height: 220,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              if (_previewMapWebViewController != null)
                SafeWebViewWidget(controller: _previewMapWebViewController!),
              if (_isPreviewMapLoading)
                Positioned.fill(
                  child: Container(
                    color: Colors.white.withValues(alpha: 0.8),
                    child: Center(child: CircularProgressIndicator(color: primary, strokeWidth: 2)),
                  ),
                ),
              if (_hasPreviewMapError)
                Positioned.fill(
                  child: Container(
                    color: Colors.grey.shade50,
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.map_outlined, size: 32, color: Colors.grey),
                          SizedBox(height: 8),
                          Text('Gagal memuat peta', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.info_outline_rounded, size: 12, color: Colors.grey.shade500),
            const SizedBox(width: 4),
            const Expanded(
              child: Text(
                'Rute dari lokasi beli ke alamat pengantaran',
                style: TextStyle(fontSize: 10, color: AppColors.textMuted),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Build map URL based on order status:
  /// - accepted/purchasing: origin = runner location, dest = pickup (go to store)
  /// - delivering/on_progress: origin = runner location, dest = delivery (go to customer)
  void _initOrderWebView(OrderModel order, {double? runnerLat, double? runnerLng}) {
    final isDelivering = order.status == 'delivering';

    final queryParams = <String, String>{};

    if (isDelivering) {
      // Delivering: origin = runner's current location (or pickup as fallback), dest = delivery
      queryParams['origin_lat'] = (runnerLat ?? order.pickupLat).toString();
      queryParams['origin_lng'] = (runnerLng ?? order.pickupLng).toString();
      queryParams['dest_lat'] = order.deliveryLat.toString();
      queryParams['dest_lng'] = order.deliveryLng.toString();
    } else {
      // Going to pickup: origin = runner's current location (or pickup as fallback), dest = pickup
      queryParams['origin_lat'] = (runnerLat ?? order.pickupLat).toString();
      queryParams['origin_lng'] = (runnerLng ?? order.pickupLng).toString();
      queryParams['dest_lat'] = order.pickupLat.toString();
      queryParams['dest_lng'] = order.pickupLng.toString();
    }

    final url = Uri.parse('${AppConfig.webBaseUrl}/map/route').replace(
      queryParameters: queryParams,
    );

    _mapWebViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _isMapLoading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _isMapLoading = false);
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame ?? true) {
              if (mounted) {
                setState(() {
                  _hasMapError = true;
                  _isMapLoading = false;
                });
              }
            }
          },
        ),
      )
      ..loadRequest(url);

    _lastMapStatus = order.status;
  }

  /// Reload map when order status changes (e.g. accepted → delivering)
  void _reloadMapIfNeeded(OrderModel order, {double? runnerLat, double? runnerLng}) {
    if (_lastMapStatus != null && _lastMapStatus != order.status) {
      // Status changed — reset state variables synchronously.
      // This is safe since it runs during the build cycle, and the null check 
      // on _mapWebViewController below will immediately trigger re-initialization.
      _lastMapStatus = order.status;
      _mapWebViewController = null;
      _isMapLoading = true;
      _hasMapError = false;
    }
  }

  Future<File?> _pickImage(BuildContext context) async {
    final picker = ImagePicker();
    File? selectedFile;

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Pilih Sumber Foto',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.primaryLight,
                child: Icon(Icons.camera_alt_rounded, color: AppColors.primary),
              ),
              title: const Text('Kamera', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Ambil foto langsung dengan kamera'),
              onTap: () async {
                final XFile? file = await picker.pickImage(
                  source: ImageSource.camera,
                  imageQuality: 80,
                );
                if (file != null) {
                  selectedFile = File(file.path);
                }
                if (context.mounted) Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.primaryLight,
                child: Icon(Icons.photo_library_rounded, color: AppColors.primary),
              ),
              title: const Text('Galeri', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Pilih foto dari galeri perangkat'),
              onTap: () async {
                final XFile? file = await picker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 80,
                );
                if (file != null) {
                  selectedFile = File(file.path);
                }
                if (context.mounted) Navigator.pop(context);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    return selectedFile;
  }

  Widget _buildImageSelector({
    required File? selectedFile,
    required VoidCallback onTap,
    required VoidCallback onClear,
    required String placeholderText,
  }) {
    if (selectedFile != null) {
      return Stack(
        children: [
          Container(
            width: double.infinity,
            height: 140,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
              image: DecorationImage(
                image: FileImage(selectedFile),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: onClear,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
              ),
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 140,
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey.shade300,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_rounded, size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              placeholderText,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Text(
              'Format JPG, PNG (Maks 5MB)',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white),
        ),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 96, left: 16, right: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }


  Future<void> _openExternalMap(double lat, double lng, String label) async {
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    try {
      final success = await launchUrl(url, mode: LaunchMode.platformDefault);
      if (!success) {
        await launchUrl(url, mode: LaunchMode.inAppBrowserView);
      }
    } catch (e) {
      try {
        await launchUrl(url);
      } catch (err) {
        if (!mounted) return;
        _showSnackBar('Tidak dapat membuka peta untuk $label.', isError: true);
      }
    }
  }

  Future<void> _openIntegratedGoogleMapsRoute({
    required double runnerLat,
    required double runnerLng,
    required double pickupLat,
    required double pickupLng,
    required double deliveryLat,
    required double deliveryLng,
  }) async {
    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&origin=$runnerLat,$runnerLng'
      '&destination=$deliveryLat,$deliveryLng'
      '&waypoints=$pickupLat,$pickupLng'
      '&travelmode=two_wheeler',
    );
    try {
      final success = await launchUrl(url, mode: LaunchMode.platformDefault);
      if (!success) {
        await launchUrl(url, mode: LaunchMode.inAppBrowserView);
      }
    } catch (e) {
      try {
        await launchUrl(url);
      } catch (err) {
        if (!mounted) return;
        _showSnackBar('Tidak dapat membuka Google Maps.', isError: true);
      }
    }
  }



  String _sanitizePhone(String phone) {
    var sanitized = phone.replaceAll(RegExp(r'\D'), '');
    if (sanitized.startsWith('0')) {
      sanitized = '62${sanitized.substring(1)}';
    }
    if (sanitized.startsWith('+')) {
      sanitized = sanitized.replaceAll('+', '');
    }
    // Handle if still has leading 8 without 62 (after + removal)
    if (sanitized.startsWith('8')) {
      sanitized = '62$sanitized';
    }
    return sanitized;
  }

  Future<void> _contactViaWhatsApp(String phone, String message) async {
    final sanitizedPhone = _sanitizePhone(phone);
    final encodedMsg = Uri.encodeComponent(message);

    // 1. Try native whatsapp:// scheme
    final whatsappScheme = Uri.parse('whatsapp://send?phone=$sanitizedPhone&text=$encodedMsg');
    final waMeUrl = Uri.parse('https://wa.me/$sanitizedPhone?text=$encodedMsg');
    final apiWaUrl = Uri.parse('https://api.whatsapp.com/send?phone=$sanitizedPhone&text=$encodedMsg');

    try {
      // Native app
      if (await canLaunchUrl(whatsappScheme)) {
        if (await launchUrl(whatsappScheme, mode: LaunchMode.externalApplication)) return;
      }
      // wa.me (universal link - will open WhatsApp if installed, else browser)
      if (await canLaunchUrl(waMeUrl)) {
        if (await launchUrl(waMeUrl, mode: LaunchMode.externalApplication)) return;
      }
      // api.whatsapp.com fallback
      if (await canLaunchUrl(apiWaUrl)) {
        if (await launchUrl(apiWaUrl, mode: LaunchMode.externalApplication)) return;
      }
    } catch (_) {}

    // All failed -> guide to Play Store/App Store with WhatsApp search
    if (!mounted) return;
    await _showWhatsAppInstallDialog(sanitizedPhone);
  }

  Future<void> _showWhatsAppInstallDialog(String sanitizedPhone) async {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('WhatsApp Tidak Terinstal', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sepertinya aplikasi WhatsApp belum terpasang di perangkat Anda.', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  const Icon(Icons.phone_rounded, size: 16, color: AppColors.textMuted),
                  const SizedBox(width: 6),
                  Expanded(child: Text(sanitizedPhone, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Copy number
              Clipboard.setData(ClipboardData(text: sanitizedPhone));
              _showSnackBar('Nomor telepon disalin ke clipboard');
            },
            child: const Text('Salin Nomor'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              await _openWhatsAppStore();
            },
            icon: const Icon(Icons.shopping_bag_rounded, size: 16),
            label: const Text('Buka Play Store'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openWhatsAppStore() async {
    // Try Play Store search via market scheme, fallback to http
    const marketSearch = 'market://search?q=whatsapp';
    const playStoreSearchHttp = 'https://play.google.com/store/search?q=whatsapp&c=apps';
    const appStoreSearch = 'https://apps.apple.com/search?term=whatsapp';

    try {
      final marketUri = Uri.parse(marketSearch);
      if (await canLaunchUrl(marketUri)) {
        if (await launchUrl(marketUri, mode: LaunchMode.externalApplication)) return;
      }
      // Fallback http Play Store search
      final httpUri = Uri.parse(playStoreSearchHttp);
      if (await canLaunchUrl(httpUri)) {
        await launchUrl(httpUri, mode: LaunchMode.externalApplication);
        return;
      }
      // iOS fallback
      final iosUri = Uri.parse(appStoreSearch);
      if (await canLaunchUrl(iosUri)) {
        await launchUrl(iosUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('Gagal membuka Play Store. Silakan cari WhatsApp secara manual di Play Store.', isError: true);
    }
  }

  Future<void> _makePhoneCall(String phone) async {
    final sanitized = _sanitizePhone(phone);
    final telUrl = Uri.parse('tel:$sanitized');
    try {
      if (await canLaunchUrl(telUrl)) {
        if (await launchUrl(telUrl, mode: LaunchMode.externalApplication)) return;
      }
    } catch (_) {}
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Panggilan Gagal', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tidak dapat melakukan panggilan telepon langsung.', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  const Icon(Icons.phone_rounded, size: 16),
                  const SizedBox(width: 6),
                  Expanded(child: Text(sanitized, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Clipboard.setData(ClipboardData(text: sanitized));
              _showSnackBar('Nomor telepon disalin');
            },
            child: const Text('Salin Nomor'),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activityState = ref.watch(activityProvider);
    final exploreState = ref.watch(exploreOrdersProvider);
    final realtimeState = ref.watch(orderStatusProvider(widget.orderId));
    final user = ref.watch(authProvider).user;
    final isRunner = user?.isRunner ?? false;
    final primary = isRunner ? AppColors.secondary : AppColors.primary;

    final order = _resolveOrder(activityState, exploreState, realtimeState);

    // Side effect: notify when cooking -> ready (low burden, once)
    if (isRunner && order.id.isNotEmpty && order.status == 'ready' && _lastNotifiedStatus != 'ready') {
      _lastNotifiedStatus = 'ready';
      if (!_hasShownReadySnack) {
        _hasShownReadySnack = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showSnackBar('Makanan siap diambil! Silakan menuju merchant.');
            // Haptic light
            HapticFeedback.mediumImpact();
          }
        });
      }
    }
    if (order.status != 'ready') {
      _lastNotifiedStatus = order.status;
    }

    if (order.id.isEmpty) {
      // Jika salah satu provider sedang mengambil data atau belum pernah mengambil data,
      // tampilkan loading indicator (bukan layar error "tidak ditemukan")
      if (activityState.isLoading || exploreState.isLoading || !activityState.hasFetched) {
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Detail Pesanan', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMain)),
            centerTitle: true,
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.textMain),
              onPressed: () => context.pop(),
            ),
          ),
          body: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: AppColors.primary),
                SizedBox(height: 16),
                Text(
                  'Memuat detail pesanan...',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        );
      }

      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Detail Pesanan', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMain)),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textMain),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: AppColors.textMuted),
              const SizedBox(height: 16),
              const Text('Pesanan tidak ditemukan atau telah selesai.', style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.w500)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('Kembali ke Dashboard', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }

    final bool isActiveRunnerTask = isRunner && order.status != 'pending';
    final isCompleted = order.status == 'completed' || _localCompleted;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          isActiveRunnerTask 
              ? 'Tugas Aktif Anda'
              : (isRunner ? 'Detail Tugas' : 'Detail Pesanan'), 
          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMain),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textMain), 
          onPressed: () => context.pop(),
        ),
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
              await Future.wait([
                ref.read(activityProvider.notifier).fetchActivities(force: true),
                ref.read(exploreOrdersProvider.notifier).fetchAvailableOrders(),
              ]);
            },
            color: primary,
            child: (isActiveRunnerTask || isCompleted)
                ? _buildActiveRunnerTaskLayout(order, primary)
                : _buildPreviewLayout(order, primary, isRunner),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomActionBar(order, primary, isRunner, isCompletedOverride: isCompleted),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewLayout(OrderModel order, Color primary, bool isRunner) {
    final isDelivering = order.status == 'delivering';
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      children: [
        _buildStatusHeader(order, primary, isRunner),
        const SizedBox(height: 20),

        if (!isRunner && order.adjustmentStatus == 'PENDING') ...[
          _buildAdjustmentApprovalCard(order, primary),
          const SizedBox(height: 20),
        ],

        _buildSectionTitle('Detail Barang'),
        const SizedBox(height: 8),
        _buildOrderInfoCard(order, primary),
        const SizedBox(height: 20),

        if (isRunner && order.receiverName != null) ...[
          _buildSectionTitle(order.serviceCategory == 'kirim' ? 'Informasi Penerima' : 'Kontak Penitip (Customer)'),
          const SizedBox(height: 8),
          _buildContactCard(
            name: order.receiverName!,
            phone: order.receiverPhone ?? '',
            label: order.serviceCategory == 'kirim' ? 'Penerima Paket' : 'Penitip / Pemesan',
            message: order.serviceCategory == 'kirim' 
                ? 'Halo ${order.receiverName}, saya Runner Nitip ingin mengonfirmasi pengantaran paket Anda.'
                : 'Halo ${order.receiverName}, saya Runner Nitip sedang memproses pesanan jastip Anda.',
            primary: primary,
          ),
          const SizedBox(height: 20),
        ],

        _buildSectionTitle('Alamat & Rute Pengiriman'),
        const SizedBox(height: 8),
        _buildLocationDetails(order, primary),
        const SizedBox(height: 16),
        _buildPreviewRouteMap(order, primary),
        const SizedBox(height: 20),

        _buildSectionTitle('Rincian Pembayaran'),
        const SizedBox(height: 8),
        _buildPaymentDetails(order, primary, isRunner),
        _buildUploadedImagesSection(order, primary),
        _buildFeedbackSection(order, primary),
        if (!isRunner && order.paymentStatus == 'unpaid' && order.paymentMethod == 'escrow' && order.paymentSource == 'qris')
          _buildQRISPaymentSection(order, primary),
        const SizedBox(height: 20),

        if (!isRunner && order.completionCode != null && isDelivering)
          _buildQrSection(order.completionCode!, primary),

        // Review button for completed orders (requester only)
        if (!isRunner && order.status == 'completed') ...[
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () => context.push('/orders/${order.id}/review'),
              icon: const Icon(Icons.rate_review_rounded, size: 20),
              label: const Text('Beri Review untuk Runner', style: TextStyle(fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.secondary,
                side: const BorderSide(color: AppColors.secondary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAdjustmentApprovalCard(OrderModel order, Color primary) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.warning),
              SizedBox(width: 8),
              Text(
                'Penyesuaian Harga Belanja',
                style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMain, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Runner mendapati perubahan harga di toko menjadi ${CurrencyFormatter.formatToIdr(order.adjustedCost, withSymbol: true)}.\nAlasan: ${order.adjustmentReason ?? "-"}',
            style: const TextStyle(fontSize: 12, color: AppColors.textMain),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                setState(() => _isProcessing = true);
                final success = await ref.read(activityProvider.notifier).approveAdjustment(order.id);
                setState(() => _isProcessing = false);
                if (success) {
                  _showSnackBar('Penyesuaian harga disetujui.');
                } else {
                  _showSnackBar('Gagal menyetujui penyesuaian.', isError: true);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isProcessing 
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Setujui Perubahan Harga', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveRunnerTaskLayout(OrderModel order, Color primary) {
    final bool isCompleted = order.status == 'completed';

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 100),
      children: [
        // ── 1. Hero Status Header (full-width colored strip) ──
        _buildRunnerStatusHeader(order, primary),

        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 2. Compact Progress Strip ──
              _buildCompactProgressStrip(order, primary),
              const SizedBox(height: 12),

              if (!isCompleted) ...[
                // ── 3. Hero Destination Card ──
                _buildHeroDestinationCard(order, primary),
                const SizedBox(height: 12),

                // ── 4. Map & Navigation ──
                _buildActualMapWidget(order, primary),
                const SizedBox(height: 20),

                // ── 5. Quick Actions ──
                _buildQuickActionsPanel(order, primary),
                const SizedBox(height: 20),
              ],

              // ── 6. Details Section (Expanded if completed) ──
              if (isCompleted) ...[
                const SizedBox(height: 8),
                _buildActiveContactCard(order, primary),
                const SizedBox(height: 16),
                _buildOrderInfoCard(order, primary),
                const SizedBox(height: 16),
                _buildPaymentDetails(order, primary, true),
                _buildUploadedImagesSection(order, primary),
                _buildFeedbackSection(order, primary),
              ] else ...[
                _buildCollapsibleDetailsCard(order, primary),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRunnerStatusHeader(OrderModel order, Color primary) {
    final bool isBeli = order.serviceCategory == 'beli';
    Color bgColor = primary;
    IconData icon;
    String statusLine;
    String actionLine;

    if (order.isFoodOrder) {
      switch (order.status) {
        case 'merchant_accepted':
          icon = Icons.storefront_rounded;
          statusLine = 'Diterima Dapur';
          actionLine = 'Menunggu Runner mengambil pesanan.';
          break;
        case 'cooking':
          icon = Icons.restaurant_menu_rounded;
          statusLine = 'Menuju Merchant';
          actionLine = 'Pergi ke merchant. Dapur sedang memasak pesanan.';
          break;
        case 'ready':
          icon = Icons.storefront_rounded;
          statusLine = 'Jemput Makanan';
          actionLine = 'Makanan siap dijemput di merchant';
          break;
        case 'delivering':
        case 'on_progress':
          icon = Icons.electric_moped_rounded;
          statusLine = 'Sedang Mengantar';
          actionLine = 'Minta kode QR saat serah terima';
          break;
        default:
          icon = Icons.check_circle_rounded;
          statusLine = 'Selesai';
          actionLine = 'Makanan berhasil diantarkan!';
      }
    } else if (isBeli) {
      switch (order.status) {
        case 'accepted':
          icon = Icons.storefront_rounded;
          statusLine = 'Pergi ke Toko';
          actionLine = 'Beli barang, lalu unggah struk';
          break;
        case 'purchasing':
          icon = Icons.inventory_2_rounded;
          statusLine = 'Belanja Selesai';
          actionLine = 'Ambil barang & mulai pengantaran';
          break;
        case 'delivering':
        case 'on_progress':
          icon = Icons.electric_moped_rounded;
          statusLine = 'Sedang Mengantar';
          actionLine = 'Minta kode QR saat serah terima';
          break;
        default:
          icon = Icons.check_circle_rounded;
          statusLine = 'Selesai';
          actionLine = 'Tugas berhasil diselesaikan!';
      }
    } else {
      switch (order.status) {
        case 'accepted':
          icon = Icons.hail_rounded;
          statusLine = 'Jemput Paket';
          actionLine = 'Ambil barang dari pengirim';
          break;
        case 'delivering':
        case 'on_progress':
          icon = Icons.electric_moped_rounded;
          statusLine = 'Sedang Mengantar';
          actionLine = 'Minta kode QR saat serah terima';
          break;
        default:
          icon = Icons.check_circle_rounded;
          statusLine = 'Selesai';
          actionLine = 'Tugas berhasil diselesaikan!';
      }
    }

    // Commission amount to display as motivator
    final commission = order.deliveryFee - order.serviceFee - order.checkingFee;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusLine,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      actionLine,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
              if (commission > 0) ...[  
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Komisi',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.white.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Rp ${commission ~/ 1000}rb',
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          if (order.adjustmentStatus != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    order.adjustmentStatus == 'APPROVED' ? Icons.check_circle_rounded :
                    order.adjustmentStatus == 'REJECTED' ? Icons.cancel_rounded : Icons.hourglass_top_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      order.adjustmentStatus == 'APPROVED' ? 'Penyesuaian Harga Disetujui' :
                      order.adjustmentStatus == 'REJECTED' ? 'Penyesuaian Harga Ditolak' : 'Menunggu Persetujuan Penyesuaian',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactProgressStrip(OrderModel order, Color primary) {
    final bool isBeli = order.serviceCategory == 'beli';
    final List<({String label, IconData icon})> steps = order.isFoodOrder
        ? [
            (label: 'Terima', icon: Icons.check_rounded),
            (label: 'Masak', icon: Icons.restaurant_menu_rounded),
            (label: 'Siap', icon: Icons.storefront_rounded),
            (label: 'Kirim', icon: Icons.electric_moped_rounded),
            (label: 'Selesai', icon: Icons.flag_rounded),
          ]
        : isBeli
            ? [
                (label: 'Terima', icon: Icons.check_rounded),
                (label: 'Belanja', icon: Icons.shopping_cart_rounded),
                (label: 'Kirim', icon: Icons.electric_moped_rounded),
                (label: 'Selesai', icon: Icons.flag_rounded),
              ]
            : [
                (label: 'Terima', icon: Icons.check_rounded),
                (label: 'Pickup', icon: Icons.hail_rounded),
                (label: 'Kirim', icon: Icons.electric_moped_rounded),
                (label: 'Selesai', icon: Icons.flag_rounded),
              ];

    int activeStep = 1; // "Terima" (index 0) is always completed in active mode
    if (order.isFoodOrder) {
      if (order.status == 'accepted') {
        activeStep = 1;
      } else if (order.status == 'cooking') {
        activeStep = 1;
      } else if (order.status == 'ready') {
        activeStep = 2;
      } else if (order.status == 'delivering' || order.status == 'on_progress') {
        activeStep = 3;
      } else if (order.status == 'completed') {
        activeStep = 4;
      }
    } else if (isBeli) {
      if (order.status == 'accepted') {
        activeStep = 1;
      } else if (order.status == 'purchasing') {
        activeStep = 2;
      } else if (order.status == 'delivering' || order.status == 'on_progress') {
        activeStep = 2;
      } else if (order.status == 'completed') {
        activeStep = 3;
      }
    } else {
      if (order.status == 'accepted') {
        activeStep = 1;
      } else if (order.status == 'delivering' || order.status == 'on_progress') {
        activeStep = 2;
      } else if (order.status == 'completed') {
        activeStep = 3;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ── Connecting Background Line ──
          Positioned(
            top: 15, // Vertically centered with the 30dp height circular nodes
            left: 30, // Centered to first step column (width 60)
            right: 30, // Centered to last step column (width 60)
            child: Row(
              children: List.generate(steps.length - 1, (index) {
                final isLineCompleted = index < activeStep;
                return Expanded(
                  child: Container(
                    height: 2.5,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    color: isLineCompleted ? AppColors.success : Colors.grey.shade200,
                  ),
                );
              }),
            ),
          ),

          // ── Stepper Step Columns (Node + Label) ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(steps.length, (index) {
              final isCompleted = index < activeStep;
              final isActive = index == activeStep;
              final step = steps[index];

              return SizedBox(
                width: 60, // Fixed width ensures mathematically perfect alignment of text & nodes!
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Circular Icon Node
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: isActive ? 30 : 26,
                      height: isActive ? 30 : 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCompleted
                            ? AppColors.success
                            : isActive
                                ? primary
                                : Colors.grey.shade100,
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: primary.withValues(alpha: 0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Icon(
                          isCompleted ? Icons.check_rounded : step.icon,
                          size: isActive ? 15 : 12,
                          color: isCompleted || isActive ? Colors.white : Colors.grey.shade400,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Centered Label
                    Text(
                      step.label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                        color: isActive ? AppColors.textMain : AppColors.textMuted,
                        letterSpacing: isActive ? 0.2 : 0,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroDestinationCard(OrderModel order, Color primary) {
    final bool isBeli = order.serviceCategory == 'beli';
    final bool goingToPickup = (order.status == 'accepted');

    Color accentColor = primary;
    IconData accentIcon = Icons.storefront_rounded;
    String typeTag = 'TOKO / MERCHANT';
    String destName = 'Toko Merchant';
    String destAddress = '-';

    if (isBeli) {
      if (goingToPickup) {
        accentIcon = Icons.storefront_rounded;
        typeTag = 'TOKO / MERCHANT';
        destName = (order.pickupName != null && order.pickupName!.trim().isNotEmpty) ? order.pickupName! : 'Toko Merchant';
        destAddress = (order.pickupAddress != null && order.pickupAddress!.trim().isNotEmpty) ? order.pickupAddress! : 'Alamat Merchant';
      } else {
        accentIcon = Icons.home_rounded;
        typeTag = 'ALAMAT PENITIP';
        destName = (order.receiverName != null && order.receiverName!.trim().isNotEmpty) ? order.receiverName! : 'Penitip';
        destAddress = (order.deliveryAddress != null && order.deliveryAddress!.trim().isNotEmpty) ? order.deliveryAddress! : 'Alamat Penitip';
      }
    } else {
      if (goingToPickup) {
        accentIcon = Icons.hail_rounded;
        typeTag = 'LOKASI PICKUP';
        destName = (order.pickupName != null && order.pickupName!.trim().isNotEmpty) ? order.pickupName! : 'Pengirim';
        destAddress = (order.pickupAddress != null && order.pickupAddress!.trim().isNotEmpty) ? order.pickupAddress! : 'Alamat Pickup';
      } else {
        accentIcon = Icons.location_on_rounded;
        typeTag = 'ALAMAT PENERIMA';
        destName = (order.receiverName != null && order.receiverName!.trim().isNotEmpty) ? order.receiverName! : 'Penerima';
        destAddress = (order.deliveryAddress != null && order.deliveryAddress!.trim().isNotEmpty) ? order.deliveryAddress! : 'Alamat Penerima';
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left vertical indicator bar
          Container(
            width: 4,
            height: 42,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 14),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(accentIcon, color: accentColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  typeTag,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: accentColor,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  destName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textMain,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  destAddress,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsPanel(OrderModel order, Color primary) {
    final name = order.receiverName ?? 'Penerima';
    final phone = order.receiverPhone ?? '';
    final message = order.serviceCategory == 'kirim'
        ? 'Halo $name, saya Runner Nitip ingin mengonfirmasi pengantaran paket Anda.'
        : 'Halo $name, saya Runner Nitip sedang memproses pesanan jastip Anda.';

    final canAdjustPrice = order.serviceCategory == 'beli' && order.status == 'accepted' && order.adjustmentStatus != 'PENDING' && order.adjustmentStatus != 'APPROVED';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Aksi Cepat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 12),
        if (order.adjustmentStatus == 'PENDING') ...[
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.warning.withValues(alpha: 0.5))),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 20),
                const SizedBox(width: 8),
                const Expanded(child: Text('Menunggu persetujuan perubahan harga dari penitip.', style: TextStyle(fontSize: 12, color: AppColors.textMain))),
              ],
            ),
          ),
        ],
        Row(
          children: [
            Expanded(
              child: _buildQuickActionItem(
                icon: Icons.chat_bubble_outline_rounded,
                label: 'Chat Penitip',
                color: const Color(0xFF25D366),
                onTap: () {
                  if (phone.isNotEmpty) {
                    _contactViaWhatsApp(phone, message);
                  } else {
                    _showSnackBar('Nomor telepon tidak tersedia', isError: true);
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            if (canAdjustPrice)
              Expanded(
                child: _buildQuickActionItem(
                  icon: Icons.price_change_outlined,
                  label: 'Sesuaikan Harga',
                  color: AppColors.warning,
                  onTap: () => _showPriceAdjustmentDialog(context, order),
                ),
              )
            else
              Expanded(
                child: _buildQuickActionItem(
                  icon: Icons.phone_rounded,
                  label: 'Telepon',
                  color: primary,
                  onTap: () {
                    if (phone.isNotEmpty) {
                      _makePhoneCall(phone);
                    } else {
                      _showSnackBar('Nomor telepon tidak tersedia', isError: true);
                    }
                  },
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showPriceAdjustmentDialog(BuildContext context, OrderModel order) {
    final priceController = TextEditingController(text: order.estimatedCost.toInt().toString());
    final reasonController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setStateModal) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 24,
              right: 24,
              top: 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Sesuaikan Harga', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textMain)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Masukkan harga asli (di nota) karena ada kenaikan/perbedaan harga.', style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
                const SizedBox(height: 16),
                TextField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Harga Baru (Rp)',
                    prefixText: 'Rp ',
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: reasonController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Alasan Perubahan (Misal: Harga naik)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: AppColors.warning,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: isSubmitting ? null : () async {
                      final priceStr = priceController.text.replaceAll(RegExp(r'[^0-9]'), '');
                      if (priceStr.isEmpty || reasonController.text.isEmpty) {
                        _showSnackBar('Mohon lengkapi harga dan alasan', isError: true);
                        return;
                      }
                      final newPrice = double.tryParse(priceStr) ?? 0;
                      if (newPrice <= order.estimatedCost) {
                        _showSnackBar('Harga baru harus lebih besar dari estimasi', isError: true);
                        return;
                      }

                      setStateModal(() => isSubmitting = true);
                      final success = await ref.read(activityProvider.notifier).adjustPrice(order.id, newPrice, reasonController.text);
                      
                      if (!context.mounted) return;
                      Navigator.pop(context);
                      
                      if (success) {
                        _showSnackBar('Berhasil mengajukan penyesuaian harga.');
                      } else {
                        _showSnackBar('Gagal mengajukan penyesuaian.', isError: true);
                      }
                    },
                    child: isSubmitting
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Ajukan Perubahan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCollapsibleDetailsCard(OrderModel order, Color primary) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Theme(
          data: ThemeData().copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            backgroundColor: Colors.white,
            collapsedBackgroundColor: Colors.white,
            tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            title: Row(
              children: [
                Icon(Icons.assignment_rounded, color: primary, size: 20),
                const SizedBox(width: 12),
                const Text(
                  'Rincian Lengkap & Kontak',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textMain),
                ),
              ],
            ),
            childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            children: [
              const Divider(height: 1, color: Colors.grey),
              const SizedBox(height: 16),
              
              // A. Customer / Receiver Contact Info
              _buildActiveContactCard(order, primary),
              const SizedBox(height: 20),

              // B. Item Details
              _buildOrderInfoCard(order, primary),
              const SizedBox(height: 20),

              // C. Financial Details
              _buildPaymentDetails(order, primary, true),
              _buildUploadedImagesSection(order, primary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActualMapWidget(OrderModel order, Color primary) {
    final runnerLoc = ref.watch(userLocationProvider);
    final runnerLatLng = runnerLoc;

    // Check if status changed → reload map with new coordinates
    _reloadMapIfNeeded(order, runnerLat: runnerLatLng?.latitude, runnerLng: runnerLatLng?.longitude);

    // Initialize WebView on first build or after status change reset
    if (_mapWebViewController == null && !_hasMapError) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initOrderWebView(
          order,
          runnerLat: runnerLatLng?.latitude,
          runnerLng: runnerLatLng?.longitude,
        );
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── WebView Map Display ──
        if (!_hasMapError) ...[
          Container(
            width: double.infinity,
            height: 220,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                if (_mapWebViewController != null)
                  SafeWebViewWidget(
                    controller: _mapWebViewController!,
                    gestureRecognizers: {
                      Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
                    },
                  ),
                if (_isMapLoading)
                  Container(
                    color: Colors.grey.shade50,
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Memuat peta rute...',
                            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Fullscreen button
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () {
                      if (runnerLatLng != null) {
                        _openIntegratedGoogleMapsRoute(
                          runnerLat: runnerLatLng.latitude,
                          runnerLng: runnerLatLng.longitude,
                          pickupLat: order.pickupLat,
                          pickupLng: order.pickupLng,
                          deliveryLat: order.deliveryLat,
                          deliveryLng: order.deliveryLng,
                        );
                      } else {
                        _openExternalMap(order.pickupLat, order.pickupLng, 'Toko');
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.open_in_new_rounded, size: 16, color: AppColors.textMain),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // ── Google Maps Navigation Button ──
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              if (runnerLatLng != null) {
                _openIntegratedGoogleMapsRoute(
                  runnerLat: runnerLatLng.latitude,
                  runnerLng: runnerLatLng.longitude,
                  pickupLat: order.pickupLat,
                  pickupLng: order.pickupLng,
                  deliveryLat: order.deliveryLat,
                  deliveryLng: order.deliveryLng,
                );
              } else {
                _openExternalMap(order.pickupLat, order.pickupLng, 'Toko');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
              foregroundColor: Colors.white,
              elevation: 2,
              shadowColor: AppColors.secondary.withValues(alpha: 0.3),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            icon: const Icon(Icons.navigation_rounded, size: 20),
            label: const Text(
              'Buka Rute Terpadu di Google Maps',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.2),
            ),
          ),
        ),
        if (!_hasMapError) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.secondary.withValues(alpha: 0.1), width: 0.8),
            ),
            child: Row(
              children: [
                Icon(Icons.touch_app_rounded, color: AppColors.secondary, size: 16),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Ketuk ikon ⤢ pada peta untuk membuka rute di Google Maps.',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMain,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActiveContactCard(OrderModel order, Color primary) {
    final name = order.receiverName ?? 'Penerima';
    final phone = order.receiverPhone ?? '';
    final label = order.serviceCategory == 'kirim' ? 'Penerima Paket' : 'Penitip / Pemesan';
    final message = order.serviceCategory == 'kirim' 
        ? 'Halo $name, saya Runner Nitip ingin mengonfirmasi pengantaran paket Anda.'
        : 'Halo $name, saya Runner Nitip sedang memproses pesanan jastip Anda.';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 15,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: primary.withValues(alpha: 0.08),
                child: Icon(Icons.person, color: primary, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.textMain,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (phone.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(height: 1, color: Colors.grey),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _contactViaWhatsApp(phone, message),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                    label: const Text('WhatsApp', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _makePhoneCall(phone),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primary,
                      side: BorderSide(color: primary.withValues(alpha: 0.3)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.phone_rounded, size: 18),
                    label: const Text('Hubungi', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContactCard({
    required String name,
    required String phone,
    required String label,
    required String message,
    required Color primary,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: primary.withValues(alpha: 0.08),
            child: Icon(Icons.person, color: primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textMain)),
                const SizedBox(height: 2),
                Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          ),
          if (phone.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.success, size: 24),
              onPressed: () => _contactViaWhatsApp(phone, message),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar(OrderModel order, Color primary, bool isRunner, {bool isCompletedOverride = false}) {
    final bool isCompletedEffective = isCompletedOverride || order.status == 'completed' || _localCompleted;
    if (_isProcessing) {
      return Container(
        color: Colors.white,
        padding: const EdgeInsets.all(24),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (isCompletedEffective) {
      return Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Pesanan selesai. Pendapatan telah masuk dompet.',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMain)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.push('/support/new?order_id=${order.id}'),
                icon: const Icon(Icons.support_agent_rounded, size: 18),
                label: const Text('Butuh Bantuan? Buat Tiket CS', style: TextStyle(fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey.shade700,
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final user = ref.read(authProvider).user;
    final isRequester = user?.id == order.requesterId;
    final isMerchant = order.merchantId != null && !isRunner && !isRequester;

    Widget? mainAction;

    if (isRunner) {
      if (order.status == 'pending') {
        mainAction = _buildActionButton(
          label: 'Ambil Tugas Ini',
          icon: Icons.check_circle_outline_rounded,
          color: AppColors.secondary,
          onPressed: () => _handleAccept(context, order.id),
        );
      } else if (order.isFoodOrder && (order.status == 'accepted' || order.status == 'cooking')) {
        mainAction = SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: null, // Disabled: wait for kitchen
            icon: const Icon(Icons.hourglass_top_rounded, size: 20),
            label: const Text('Menunggu Dapur Menyiapkan...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        );
      } else if (order.isFoodOrder && order.status == 'ready') {
        mainAction = _buildActionButton(
          label: 'Jemput & Mulai Pengantaran',
          icon: Icons.local_shipping_rounded,
          color: primary,
          onPressed: () => _handlePickup(context, order.id),
        );
      } else if (order.status == 'accepted') {
        if (order.serviceCategory == 'beli') {
          mainAction = _buildActionButton(
            label: 'Belanja & Unggah Struk',
            icon: Icons.receipt_long_rounded,
            color: AppColors.warning,
            onPressed: () => _handlePurchase(context, order.id),
          );
        } else {
          mainAction = _buildActionButton(
            label: 'Ambil & Mulai Pengantaran',
            icon: Icons.local_shipping_rounded,
            color: primary,
            onPressed: () => _handlePickup(context, order.id),
          );
        }
      } else if (order.status == 'purchasing') {
        mainAction = _buildActionButton(
          label: 'Ambil & Mulai Pengantaran',
          icon: Icons.local_shipping_rounded,
          color: primary,
          onPressed: () => _handlePickup(context, order.id),
        );
      } else if (order.status == 'delivering' || order.status == 'on_progress') {
        mainAction = _buildActionButton(
          label: 'Konfirmasi Selesai (Scan/Input QR)',
          icon: Icons.qr_code_scanner_rounded,
          color: AppColors.success,
          onPressed: () => _showCompletionDialog(context, order.id),
        );
      }
    }

    final cancelBtn = _buildCancelButton(order, isRunner, isRequester, isMerchant);
    final disputeBtn = _buildDisputeButton(order, isRequester);

    if (mainAction == null && cancelBtn == null && disputeBtn == null) {
      return Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => context.push('/support/new?order_id=${order.id}'),
            icon: const Icon(Icons.support_agent_rounded, size: 18),
            label: const Text('Butuh Bantuan? Buat Tiket CS', style: TextStyle(fontSize: 13)),
            style: OutlinedButton.styleFrom(
              foregroundColor: primary,
              side: BorderSide(color: primary.withValues(alpha: 0.3)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      );
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (mainAction != null) ...[
            mainAction,
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.push('/support/new?order_id=${order.id}'),
                icon: const Icon(Icons.support_agent_rounded, size: 18),
                label: const Text('Butuh Bantuan? Buat Tiket CS', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey.shade700,
                  side: BorderSide(color: Colors.grey.shade300),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            if (cancelBtn != null || disputeBtn != null) const SizedBox(height: 8),
          ],
          if (cancelBtn != null) cancelBtn,
          if (disputeBtn != null) ...[
            const SizedBox(height: 8),
            disputeBtn,
          ],
        ],
      ),
    );
  }

  void _handleAccept(BuildContext context, String orderId) async {
    setState(() => _isProcessing = true);
    final success = await ref.read(exploreOrdersProvider.notifier).acceptOrder(orderId);
    setState(() => _isProcessing = false);

    if (!context.mounted) return;
    if (success) {
      // Reload both history/active tasks and explore lists to ensure client state is 100% in sync
      await Future.wait([
        ref.read(exploreOrdersProvider.notifier).fetchAvailableOrders(),
        ref.read(activityProvider.notifier).fetchActivities(force: true),
      ]);
      _showSnackBar('Pesanan berhasil diambil!');
      // Stay on the detail page; the re-fetched states automatically transition from preview to active task layout!
    } else {
      final error = ref.read(exploreOrdersProvider).error ?? 'Gagal mengambil pesanan';
      if (error.contains('KycRequiredException') || error.contains('KYC_REQUIRED') || error.contains('verifikasi e-KYC')) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Butuh Verifikasi e-KYC'),
            content: const Text(
              'Batas harian menerima pesanan untuk akun non-verifikasi telah tercapai.\n\n'
              'Selesaikan verifikasi e-KYC (Facebook & Selfie) sekarang untuk mendapatkan akses tanpa batas!',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.push('/kyc-intro');
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary),
                child: const Text('Verifikasi Sekarang'),
              ),
            ],
          ),
        );
        return;
      }
      _showSnackBar(error, isError: true);
    }
  }

  Widget _buildOrderInfoCard(OrderModel order, Color primary) {
    return _buildCard(
      child: Column(
        children: [
          _buildDetailRow(order.serviceCategory == 'kirim' ? 'Isi Paket' : 'Nama Barang', order.itemDetails),
          const Divider(height: 24),
          Row(
            children: [
              _buildInfoTag(Icons.scale_outlined, '${order.weightKg} kg'),
              const SizedBox(width: 8),
              _buildInfoTag(
                Icons.inventory_2_outlined, 
                order.volumeLiters <= 1 ? 'Kecil (1L)' : order.volumeLiters <= 5 ? 'Sedang (5L)' : 'Besar',
              ),
              const SizedBox(width: 8),
              _buildInfoTag(
                order.serviceCategory == 'kirim' ? Icons.local_shipping_outlined : Icons.shopping_bag_outlined, 
                order.serviceCategory.toUpperCase(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationDetails(OrderModel order, Color primary) {
    final isRunner = ref.watch(authProvider).user?.isRunner ?? false;
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLocationRow(
            order.serviceCategory == 'kirim' ? 'Titik Penjemputan Paket' : 'Merchant / Lokasi Beli', 
            order.pickupAddress ?? 'Toko/Lokasi Merchant', 
            order.serviceCategory == 'kirim' ? Icons.hail_rounded : Icons.storefront_rounded, 
            Colors.orange
          ),
          const Padding(
            padding: EdgeInsets.only(left: 10),
            child: SizedBox(height: 16, child: VerticalDivider(width: 1, thickness: 1)),
          ),
          _buildLocationRow(
            'Titik Pengantaran', 
            order.deliveryAddress ?? 'Lokasi Tujuan Penitip', 
            Icons.location_on_rounded, 
            primary
          ),
          
          const SizedBox.shrink(),
          if (isRunner) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  final runnerLatLng = ref.read(userLocationProvider);
                  if (runnerLatLng != null) {
                    _openIntegratedGoogleMapsRoute(
                      runnerLat: runnerLatLng.latitude,
                      runnerLng: runnerLatLng.longitude,
                      pickupLat: order.pickupLat,
                      pickupLng: order.pickupLng,
                      deliveryLat: order.deliveryLat,
                      deliveryLng: order.deliveryLng,
                    );
                  } else {
                    _openExternalMap(order.pickupLat, order.pickupLng, 'Titik Jemput');
                  }
                },
                icon: const Icon(Icons.navigation_rounded, color: Colors.white, size: 18),
                label: const Text(
                  'Navigasi Google Maps (Rute Terpadu)',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF34A853), // Google Green
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 2,
                  shadowColor: const Color(0xFF34A853).withValues(alpha: 0.3),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade100, width: 0.8),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline_rounded, color: Colors.orange.shade800, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Peta bermasalah? Ketuk tombol hijau diatas untuk navigasi offline & realtime di Google Maps.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.orange.shade900,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }



  Widget _buildUploadedImagesSection(OrderModel order, Color primary) {
    // Backend single source of truth https://upload.nihtip.com/ — FE menerima url mentah langsung tanpa tambahan
    final hasReceipt = order.receiptImageUrl != null && order.receiptImageUrl!.trim().isNotEmpty;
    final hasDeliveryProof = order.deliveryImageUrl != null && order.deliveryImageUrl!.trim().isNotEmpty;

    if (!hasReceipt && !hasDeliveryProof) return const SizedBox.shrink();

    void openFullscreen(String url, String label) {
      showDialog(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.92),
        builder: (_) => GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
            ),
            body: Center(
              child: InteractiveViewer(
                panEnabled: true,
                minScale: 0.8,
                maxScale: 5.0,
                child: CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.contain,
                  placeholder: (ctx, _) => const CircularProgressIndicator(color: Colors.white),
                  errorWidget: (ctx, _, __) => const Icon(Icons.broken_image_rounded, color: Colors.white54, size: 60),
                ),
              ),
            ),
          ),
        ),
      );
    }

    Widget buildThumb(String url, String label) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: AppColors.textMuted),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => openFullscreen(url, label),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    height: 110,
                    width: double.infinity,
                    child: CachedNetworkImage(
                      imageUrl: url,
                      placeholder: (context, url) => Container(
                        color: Colors.grey.shade100,
                        child: const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey.shade100,
                        child: const Center(child: Icon(Icons.broken_image_rounded, size: 28, color: Colors.grey)),
                      ),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                // Fullscreen hint icon
                Positioned(
                  bottom: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.zoom_out_map_rounded, size: 13, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        _buildSectionTitle('Bukti Foto'),
        const SizedBox(height: 8),
        _buildCard(
          child: hasReceipt && hasDeliveryProof
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: buildThumb(order.receiptImageUrl!, 'Struk Belanja')),
                    const SizedBox(width: 10),
                    Expanded(child: buildThumb(order.deliveryImageUrl!, 'Bukti Serah Terima')),
                  ],
                )
              : hasReceipt
                  ? buildThumb(order.receiptImageUrl!, 'Struk Belanja (Kwitansi)')
                  : buildThumb(order.deliveryImageUrl!, 'Bukti Penyerahan Barang'),
        ),
      ],
    );
  }


  Widget _buildFeedbackSection(OrderModel order, Color primary) {
    if (order.feedbackRating == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        _buildSectionTitle('Ulasan Penitip'),
        const SizedBox(height: 8),
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ...List.generate(5, (index) {
                    final isSelected = index < order.feedbackRating!;
                    return Icon(
                      isSelected ? Icons.star_rounded : Icons.star_border_rounded,
                      color: isSelected ? Colors.amber : Colors.grey.shade300,
                      size: 20,
                    );
                  }),
                  const SizedBox(width: 8),
                  Text(
                    '${order.feedbackRating}/5',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textMain),
                  ),
                ],
              ),
              if (order.feedbackComment != null && order.feedbackComment!.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  order.feedbackComment!,
                  style: const TextStyle(fontSize: 13, color: AppColors.textMain, fontStyle: FontStyle.italic),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }


  Widget _buildQRISPaymentSection(OrderModel order, Color primary) {
    if (order.qrisData == null || order.qrisData!.isEmpty) return const SizedBox.shrink();

    final qrisStr = order.qrisData!;
    final String qrisUrl;
    if (qrisStr.startsWith('000201')) {
      qrisUrl = 'https://api.qrserver.com/v1/create-qr-code/?size=300x300&margin=10&data=${Uri.encodeComponent(qrisStr)}';
    } else {
      qrisUrl = qrisStr;
    }

    // ignore: unused_local_variable
    final isSandbox = qrisStr.contains('sandbox') ||
        qrisStr.contains('mock') ||
        qrisStr.contains('localhost') ||
        qrisStr.startsWith('000201');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        _buildSectionTitle('Selesaikan Pembayaran QRIS'),
        const SizedBox(height: 8),
        _buildCard(
          child: Column(
            children: [
              const Text(
                'Silakan scan QRIS di bawah ini menggunakan aplikasi mobile banking atau e-wallet pilihan Anda.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: 16),
              
              // Official QRIS Sheet Card
              Container(
                width: 250,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade200, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Header: QRIS & GPN Logo
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Stylized QRIS text
                        Row(
                          children: [
                            Text(
                              'QR',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF0F265C),
                                fontFamily: 'Inter',
                              ),
                            ),
                            Text(
                              'IS',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFFDF2524),
                                fontFamily: 'Inter',
                              ),
                            ),
                          ],
                        ),
                        // Red GPN Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDF2524),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'GPN',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 7,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Divider(color: Colors.grey.shade100, height: 1, thickness: 1),
                    const SizedBox(height: 8),

                    // Merchant Info
                    Text(
                      order.pickupName ?? 'KEDAI KRIMMI',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMain,
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'NMID: ID1026556507279',
                      style: TextStyle(
                        fontSize: 8,
                        color: Colors.grey,
                        fontFamily: 'Courier',
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),

                    // QR Image Frame
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade100, width: 1),
                      ),
                      child: CachedNetworkImage(
                        imageUrl: qrisUrl,
                        width: 160,
                        height: 160,
                        placeholder: (context, url) => const SizedBox(
                          width: 160,
                          height: 160,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        errorWidget: (context, url, error) => const SizedBox(
                          width: 160,
                          height: 160,
                          child: Center(child: Icon(Icons.broken_image_rounded, size: 30, color: Colors.grey)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Supported Bank/Ewallet logos at bottom
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _buildSmallBrandBadge('GoPay', const Color(0xFF00AED6)),
                        _buildSmallBrandBadge('SPay', const Color(0xFFEE4D2D)),
                        _buildSmallBrandBadge('OVO', const Color(0xFF4C3497)),
                        _buildSmallBrandBadge('DANA', const Color(0xFF118EEA)),
                        _buildSmallBrandBadge('Mandiri', const Color(0xFF003A6E)),
                        _buildSmallBrandBadge('BCA', const Color(0xFF0060AF)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Status: Menunggu Pembayaran',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.warning),
              ),
              const SizedBox(height: 8),
              const Text(
                'Setelah membayar, status pesanan Anda akan otomatis aktif.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: AppColors.textMuted, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
      ],
    );
  }


  Widget _buildPaymentDetails(OrderModel order, Color primary, bool isRunner) {
    // Ongkir full untuk requester (10k), bukan bersih runner 6.250 — request bilang pengecekan awal 10rb
    // Food: hanya ongkir full, tidak ada pengecekan
    final baseJastip = order.deliveryFee; // full untuk requester
    final runnerOngkir = order.deliveryFee - order.serviceFee - order.checkingFee; // bersih runner
    final bool isFood = (order.merchantId != null && order.merchantId!.isNotEmpty) || order.itemDetails.toLowerCase().contains('nitip food');
    return _buildCard(
      child: Column(
        children: [
          // Untuk nitip-food: requester hanya lihat ongkir full 10k, runner hanya ongkir bersih diterima, tidak total + biaya makanan
          if (isFood) ...[
            if (isRunner) ...[
              _buildSummaryRow('Ongkir Diterima Runner', CurrencyFormatter.formatToIdr(runnerOngkir, withSymbol: true), isBold: true, color: primary),
              const SizedBox(height: 8),
              Text('Biaya makanan ditanggung requester • Fee merchant potong saat settlement (biaya layanan tidak tampil ke requester)', style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontStyle: FontStyle.italic)),
            ] else ...[
              _buildSummaryRow('Harga Makanan', CurrencyFormatter.formatToIdr(order.estimatedCost, withSymbol: true)),
              const SizedBox(height: 8),
              _buildSummaryRow('Ongkos Kirim', CurrencyFormatter.formatToIdr(baseJastip, withSymbol: true)),
              const Divider(height: 24),
              _buildSummaryRow('Total Pembayaran', CurrencyFormatter.formatToIdr(order.estimatedCost + baseJastip, withSymbol: true), isBold: true, color: primary),
            ],
          ] else ...[
            // Non-food: beli / kirim — requester hanya ongkir full, bukan bersih
            if (order.serviceCategory == 'beli') ...[
              _buildSummaryRow('Harga Barang', CurrencyFormatter.formatToIdr(order.estimatedCost, withSymbol: true)),
              const SizedBox(height: 8),
            ],
            if (isRunner) ...[
              _buildSummaryRow('Komisi Bersih Anda', CurrencyFormatter.formatToIdr(runnerOngkir, withSymbol: true)),
            ] else ...[
              _buildSummaryRow('Ongkos Kirim', CurrencyFormatter.formatToIdr(baseJastip, withSymbol: true)),
            ],
            const Divider(height: 24),
            _buildSummaryRow(
              isRunner ? 'Total Pendapatan/Reimbursement' : 'Total Pembayaran',
              CurrencyFormatter.formatToIdr(isRunner ? (order.totalPayment) : (order.estimatedCost + baseJastip), withSymbol: true),
              isBold: true,
              color: primary,
            ),
          ],
          const SizedBox(height: 12),
          _buildPaymentMethodTag(order.paymentMethod, primary, isRunner),
          if (isFood && isRunner)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: const Color(0xFFFFF8E1), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFFFC107).withValues(alpha: 0.3))),
                child: Row(
                  children: [
                    const Icon(Icons.restaurant_rounded, size: 14, color: Color(0xFFE65100)),
                    const SizedBox(width: 6),
                    const Expanded(child: Text('FOOD: Hanya ongkir yang Anda terima. Biaya makanan tidak perlu talangi.', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFFBF360C)))),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSmallBrandBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.8),
      ),
      child: Text(label, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: color)),
    );
  }

  Widget _buildActionButton({required String label, required IconData icon, required Color color, required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildQrSection(String code, Color primary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        _buildSectionTitle('Konfirmasi Penyelesaian'),
        const SizedBox(height: 8),
        _buildCard(
          child: Column(
            children: [
              const Text(
                'Tunjukkan kode QR ini kepada Runner untuk dipindai saat barang telah Anda terima.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: 20),
              QrImageView(
                data: code,
                version: QrVersions.auto,
                size: 200.0,
                eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
                dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
              ),
              const SizedBox(height: 12),
              Text(
                'KODE: $code',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 2),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _handlePurchase(BuildContext context, String orderId) async {
    File? selectedReceiptFile;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Unggah Struk Belanja'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ambil foto atau pilih struk belanja barang dari galeri untuk pesanan ini:',
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
                const SizedBox(height: 16),
                _buildImageSelector(
                  selectedFile: selectedReceiptFile,
                  placeholderText: 'Pilih Foto Struk Belanja',
                  onTap: () async {
                    final file = await _pickImage(context);
                    if (file != null) {
                      setDialogState(() => selectedReceiptFile = file);
                    }
                  },
                  onClear: () {
                    setDialogState(() => selectedReceiptFile = null);
                  },
                ),
                if (selectedReceiptFile == null) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Foto struk belanja wajib diunggah',
                    style: TextStyle(color: Colors.red, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: selectedReceiptFile == null
                  ? null
                  : () async {
                      if (formKey.currentState?.validate() ?? false) {
                        final localPath = selectedReceiptFile!.path;
                        Navigator.pop(context);

                        setState(() => _isProcessing = true);
                        final success = await ref.read(activityProvider.notifier).purchaseOrder(orderId, localPath);
                        setState(() => _isProcessing = false);

                        if (context.mounted) {
                          _showSnackBar(
                            success ? 'Struk belanja berhasil diunggah!' : 'Gagal mengunggah struk belanja',
                            isError: !success,
                          );
                        }
                      }
                    },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  void _handlePickup(BuildContext context, String orderId) async {
    setState(() => _isProcessing = true);
    final success = await ref.read(activityProvider.notifier).pickupOrder(orderId);
    setState(() => _isProcessing = false);

    if (context.mounted) {
      _showSnackBar(
        success ? 'Pesanan sedang Anda proses!' : 'Gagal memproses pesanan',
        isError: !success,
      );
    }
  }

  void _showCompletionDialog(BuildContext context, String orderId) {
    final codeController = TextEditingController();
    File? selectedDeliveryFile;
    final formKey = GlobalKey<FormState>();

    // Retrieve expected completion code from active order
    final activeOrder = ref.read(activityProvider).activeOrders.firstWhere(
          (o) => o.id == orderId,
          orElse: () => throw Exception('Order not found'),
        );
    final expectedCode = activeOrder.completionCode ?? '';
    final timeDiff = DateTime.now().difference(activeOrder.updatedAt);
    final isStagnant = timeDiff.inMinutes > 30 && activeOrder.status == 'delivering';

    showDialog(
      context: context,
      builder: (context) {
        bool isSubmitting = false;
        String? errorMessage;

        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Konfirmasi Selesai'),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isStagnant) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Selesai Tanpa PIN: Anda dapat menyelesaikan pesanan tanpa kode PIN/QR karena status telah stagnan > 30 menit. Foto bukti wajib diunggah.',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.warning),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const Text('Scan QR pada aplikasi Penitip atau masukkan kode konfirmasi di bawah ini:'),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: codeController,
                      decoration: InputDecoration(
                        labelText: 'Kode Konfirmasi',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primary),
                          tooltip: 'Scan QR Code',
                          onPressed: () async {
                            final scannedCode = await Navigator.push<String>(
                              context,
                              MaterialPageRoute(
                                builder: (context) => QrScannerPage(expectedCode: expectedCode),
                              ),
                            );
                            if (scannedCode != null) {
                              codeController.text = scannedCode;
                              _showSnackBar('Kode Konfirmasi berhasil dipindai!');
                            }
                          },
                        ),
                      ),
                      validator: (val) {
                        if (isStagnant && selectedDeliveryFile != null) {
                          return null; // Bypass PIN code requirement
                        }
                        if (val == null || val.isEmpty) return 'Kode wajib diisi';
                        return null;
                      },
                      autofocus: true,
                      enabled: !isSubmitting,
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: AppColors.error, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                errorMessage!,
                                style: const TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    const Text(
                      'Foto bukti penyerahan barang (Wajib jika tanpa PIN):',
                      style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 8),
                    _buildImageSelector(
                      selectedFile: selectedDeliveryFile,
                      placeholderText: 'Pilih Foto Bukti Penyerahan',
                      onTap: isSubmitting
                          ? () {}
                          : () async {
                              final file = await _pickImage(context);
                              if (file != null) {
                                setDialogState(() => selectedDeliveryFile = file);
                              }
                            },
                      onClear: isSubmitting
                          ? () {}
                          : () {
                              setDialogState(() => selectedDeliveryFile = null);
                            },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(context), 
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final code = codeController.text.trim();
                        final localPath = selectedDeliveryFile?.path ?? '';

                        if (isStagnant && code.isEmpty && localPath.isEmpty) {
                          setDialogState(() {
                            errorMessage = 'Foto bukti wajib diunggah untuk penyelesaian tanpa PIN.';
                          });
                          return;
                        }

                        if (formKey.currentState?.validate() ?? false) {
                          setDialogState(() {
                            isSubmitting = true;
                            errorMessage = null;
                          });
                          
                          final success = await ref.read(activityProvider.notifier).completeOrder(orderId, code, localPath);

                          if (success) {
                            if (mounted) {
                              setState(() => _localCompleted = true);
                            }
                            if (context.mounted) {
                              Navigator.pop(context); // Close the dialog
                            }
                            _showSnackBar('Pesanan Selesai! Pendapatan telah ditambahkan ke dompet Anda.');
                          } else {
                            setDialogState(() {
                              isSubmitting = false;
                              errorMessage = 'Kode konfirmasi salah atau gagal memproses penyelesaian.';
                            });
                          }
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Konfirmasi'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget? _buildCancelButton(OrderModel order, bool isRunner, bool isRequester, bool isMerchant) {
    if (order.status == 'completed' || order.status == 'cancelled') return null;

    final timeDiff = DateTime.now().difference(order.updatedAt);
    final isStagnant = timeDiff.inMinutes > 30;

    bool canNormalCancel = false;
    if (isRequester) {
      if (order.isFoodOrder) {
        canNormalCancel = order.status == 'pending' || order.status == 'merchant_accepted';
      } else if (order.serviceCategory == 'kirim') {
        canNormalCancel = order.status == 'pending' || order.status == 'accepted';
      } else { // beli
        canNormalCancel = order.status == 'pending' || order.status == 'accepted';
      }
    }

    final isAllowedToCancel = canNormalCancel || (isStagnant && (isRequester || isRunner || isMerchant));
    if (!isAllowedToCancel) return null;

    return Container(
      width: double.infinity,
      height: 48,
      margin: const EdgeInsets.only(top: 8),
      child: OutlinedButton.icon(
        onPressed: () => _showCancelDialog(context, order.id, isStagnant: !canNormalCancel),
        icon: const Icon(Icons.cancel_outlined, size: 20),
        label: Text(
          !canNormalCancel ? 'Batalkan Pesanan (Stagnan > 30m)' : 'Batalkan Pesanan',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.error,
          side: const BorderSide(color: AppColors.error),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget? _buildDisputeButton(OrderModel order, bool isRequester) {
    if (order.status != 'completed' || !isRequester) return null;
    final timeDiff = DateTime.now().difference(order.updatedAt);
    if (timeDiff.inHours > 24) return null;

    return Container(
      width: double.infinity,
      height: 48,
      margin: const EdgeInsets.only(top: 8),
      child: OutlinedButton.icon(
        onPressed: () => _showDisputeDialog(context, order.id),
        icon: const Icon(Icons.gavel_rounded, size: 20),
        label: const Text('Ajukan Dispute / Sengketa', style: TextStyle(fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.warning,
          side: const BorderSide(color: AppColors.warning),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  void _showCancelDialog(BuildContext context, String orderId, {required bool isStagnant}) {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        bool isSubmitting = false;
        String? errorMessage;

        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Batalkan Pesanan'),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isStagnant 
                      ? 'Status pesanan tidak berubah selama lebih dari 30 menit. Anda dapat membatalkannya, tetapi wajib memberikan alasan pembatalan.'
                      : 'Apakah Anda yakin ingin membatalkan pesanan ini? Jika dibatalkan sekarang, tidak ada biaya penalti.'),
                    if (isStagnant) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: reasonController,
                        decoration: const InputDecoration(
                          labelText: 'Alasan Pembatalan',
                          border: OutlineInputBorder(),
                          hintText: 'Contoh: Runner tidak kunjung bergerak / salah rute...',
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Alasan pembatalan wajib diisi';
                          return null;
                        },
                        maxLines: 3,
                        enabled: !isSubmitting,
                      ),
                    ],
                    if (errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(errorMessage!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(context),
                child: const Text('Tutup'),
              ),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        if (!isStagnant || (formKey.currentState?.validate() ?? false)) {
                          setDialogState(() {
                            isSubmitting = true;
                            errorMessage = null;
                          });

                          try {
                            final reason = isStagnant ? reasonController.text.trim() : null;
                            await ref.read(orderRepositoryProvider).cancelOrder(orderId, reason: reason);
                            
                            if (context.mounted) {
                              Navigator.pop(context); // Close dialog
                              ref.invalidate(activityProvider);
                              _showSnackBar('Pesanan berhasil dibatalkan');
                              Navigator.pop(context); // Go back
                            }
                          } catch (e) {
                            setDialogState(() {
                              isSubmitting = false;
                              errorMessage = e.toString().replaceAll('Exception: ', '');
                            });
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
                child: isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Batalkan'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDisputeDialog(BuildContext context, String orderId) {
    final reasonController = TextEditingController();
    final proofController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        bool isSubmitting = false;
        String? errorMessage;

        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Ajukan Dispute / Sengketa'),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Silakan masukkan alasan dispute dan URL bukti (misalnya link gambar dari storage):'),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: reasonController,
                      decoration: const InputDecoration(
                        labelText: 'Alasan Sengketa',
                        border: OutlineInputBorder(),
                        hintText: 'Jelaskan masalah secara detail...',
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Alasan sengketa wajib diisi';
                        return null;
                      },
                      maxLines: 3,
                      enabled: !isSubmitting,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: proofController,
                      decoration: const InputDecoration(
                        labelText: 'URL Bukti Gambar',
                        border: OutlineInputBorder(),
                        hintText: 'https://...',
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'URL bukti sengketa wajib diisi';
                        if (!val.startsWith('http://') && !val.startsWith('https://')) return 'URL tidak valid';
                        return null;
                      },
                      enabled: !isSubmitting,
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(errorMessage!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(context),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        if (formKey.currentState?.validate() ?? false) {
                          setDialogState(() {
                            isSubmitting = true;
                            errorMessage = null;
                          });

                          try {
                            final reason = reasonController.text.trim();
                            final proof = proofController.text.trim();
                            await ref.read(orderRepositoryProvider).disputeOrder(orderId, reason, proof);
                            
                            if (context.mounted) {
                              Navigator.pop(context); // Close dialog
                              ref.invalidate(activityProvider);
                              _showSnackBar('Dispute berhasil diajukan');
                            }
                          } catch (e) {
                            setDialogState(() {
                              isSubmitting = false;
                              errorMessage = e.toString().replaceAll('Exception: ', '');
                            });
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning, foregroundColor: Colors.white),
                child: isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Kirim Dispute'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusHeader(OrderModel order, Color primary, bool isRunner) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primary.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: primary, shape: BoxShape.circle),
                child: const Icon(Icons.access_time_filled_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getStatusTitle(order.status, isRunner, order.isFoodOrder),
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getStatusDesc(order.status, isRunner, order.isFoodOrder),
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (order.adjustmentStatus != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    order.adjustmentStatus == 'APPROVED' ? Icons.check_circle_rounded :
                    order.adjustmentStatus == 'REJECTED' ? Icons.cancel_rounded : Icons.hourglass_top_rounded,
                    color: AppColors.warning,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      order.adjustmentStatus == 'APPROVED' ? 'Penyesuaian Harga Disetujui' :
                      order.adjustmentStatus == 'REJECTED' ? 'Penyesuaian Harga Ditolak' : 'Menunggu Persetujuan Penyesuaian',
                      style: const TextStyle(color: AppColors.warning, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textMuted, letterSpacing: 0.5),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: child,
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoTag(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.textMuted),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
        ],
      ),
    );
  }

  Widget _buildLocationRow(String label, String address, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(address, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 14, color: isBold ? Colors.black : AppColors.textMuted, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color ?? Colors.black)),
      ],
    );
  }

  Widget _buildPaymentMethodTag(String method, Color primary, bool isRunner) {
    final isEscrow = method == 'escrow';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isEscrow ? primary.withValues(alpha: 0.05) : Colors.orange.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isEscrow ? primary.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isEscrow ? Icons.account_balance_wallet_rounded : Icons.payments_rounded, size: 14, color: isEscrow ? primary : Colors.orange.shade800),
          const SizedBox(width: 8),
          Text(
            isEscrow 
              ? (isRunner ? 'Saldo akan masuk ke Dompet' : 'Dibayar dengan Saldo Dompet')
              : (isRunner ? 'Terima tunai di lokasi (COD)' : 'Bayar di Tempat (COD)'),
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isEscrow ? primary : Colors.orange.shade800),
          ),
        ],
      ),
    );
  }

  String _getStatusTitle(String status, bool isRunner, bool isFoodOrder) {
    switch (status.toLowerCase()) {
      case 'pending': return isRunner ? 'Tugas Baru Tersedia' : (isFoodOrder ? 'Menunggu Dapur Menerima' : 'Menunggu Runner');
      case 'merchant_accepted': return 'Pesanan Diterima Dapur';
      case 'accepted': return isRunner ? 'Tugas Diterima' : 'Pesanan Diterima';
      case 'cooking': return isFoodOrder ? 'Dapur Sedang Memasak' : (isRunner ? 'Tugas Diterima' : 'Pesanan Diterima');
      case 'ready': return 'Pesanan Siap Diambil';
      case 'purchasing': return isRunner ? 'Sedang Belanja' : 'Sedang Dibeli';
      case 'delivering': return isRunner ? 'Dalam Pengantaran' : 'Dalam Pengantaran';
      case 'on_progress': return isRunner ? 'Dalam Pengerjaan' : 'Sedang Diproses';
      case 'completed': return 'Selesai';
      case 'cancelled': return 'Dibatalkan';
      default: return 'Status: ${status.toUpperCase()}';
    }
  }

  String _getStatusDesc(String status, bool isRunner, bool isFoodOrder) {
    switch (status.toLowerCase()) {
      case 'pending': return isRunner ? 'Ambil tugas ini segera sebelum diambil Runner lain.' : (isFoodOrder ? 'Pesanan Anda sedang menunggu konfirmasi dari pihak dapur.' : 'Pesanan Anda sedang dicarikan Runner terdekat.');
      case 'merchant_accepted': return isRunner ? 'Pesanan telah disetujui dapur. Silakan ambil tugas ini.' : 'Pesanan Anda telah disetujui dapur. Sistem sedang mencari runner terdekat.';
      case 'accepted': return isRunner ? 'Anda telah menyetujui untuk menjalankan tugas ini.' : 'Runner telah menyetujui pesanan Anda.';
      case 'cooking': return isFoodOrder ? (isRunner ? 'Harap tunggu makanan disiapkan oleh merchant.' : 'Dapur sedang memasak pesanan Anda.') : (isRunner ? 'Anda telah menyetujui untuk menjalankan tugas ini.' : 'Runner telah menyetujui pesanan Anda.');
      case 'ready': return isRunner ? 'Makanan siap dijemput di merchant.' : 'Makanan Anda sudah matang dan siap dijemput oleh runner.';
      case 'purchasing': return isRunner ? 'Anda sedang membelikan barang pesanan.' : 'Runner sedang membelikan barang pesanan Anda.';
      case 'delivering': return isRunner ? 'Anda sedang mengantarkan barang ke tujuan.' : 'Runner sedang mengantarkan barang ke lokasi Anda.';
      case 'on_progress': return isRunner ? 'Anda sedang menuju lokasi atau mengantar barang.' : 'Runner sedang menuju lokasi atau mengantar barang.';
      case 'completed': return isRunner ? 'Tugas selesai. Pendapatan telah masuk ke saldo Anda.' : 'Transaksi selesai. Terima kasih telah menggunakan Nitip!';
      case 'cancelled': return 'Pesanan ini telah dibatalkan.';
      default: return '-';
    }
  }
}
