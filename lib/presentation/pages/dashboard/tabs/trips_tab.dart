import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/config/app_config.dart';

import '../../../providers/trip_provider.dart';
import '../../trips/open_trip_sheet.dart';



class TripsTab extends ConsumerStatefulWidget {
  const TripsTab({super.key});

  @override
  ConsumerState<TripsTab> createState() => _TripsTabState();
}

class _TripsTabState extends ConsumerState<TripsTab> {
  WebViewController? _webViewController;
  String? _loadedTripId;
  final bool _isMapMaximized = false;
  bool _isMapLoading = true;
  bool _hasMapError = false;


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(tripProvider.notifier).fetchMyTrips(force: true);
    });
  }

  void _showOpenTripForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const OpenTripSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tripState = ref.watch(tripProvider);
    final currentTrip = tripState.currentTrip;
    final primary = AppColors.secondary; // Runner's accent

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Manajemen Trip',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textMain),
        ),
        centerTitle: false,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textMain),
            onPressed: () {
              // Reset WebView state so map reloads on next build
              setState(() {
                _webViewController = null;
                _loadedTripId = null;
                _isMapLoading = true;
                _hasMapError = false;
              });
              ref.read(tripProvider.notifier).fetchMyTrips(force: true);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(tripProvider.notifier).fetchMyTrips(force: true),
        color: primary,
        child: tripState.isLoading && !tripState.hasFetched
            ? const Center(child: CircularProgressIndicator())
            : currentTrip == null
                ? _buildEmptyState(primary)
                : _buildActiveTripView(currentTrip, primary, tripState),
      ),
    );
  }

  Widget _buildEmptyState(Color primary) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        height: MediaQuery.of(context).size.height - 200,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Premium Illustration/Icon Container
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.explore_outlined,
                size: 80,
                color: primary,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Belum Ada Trip Aktif',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppColors.textMain,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Buka trip baru untuk memposting rute perjalanan Anda dan mencocokkan pesanan kurir jarak jauh searah secara otomatis.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            // Glowing Premium Button
            GestureDetector(
              onTap: _showOpenTripForm,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: primary.withValues(alpha: 0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_road_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 10),
                    Text(
                      'Buka Trip Baru',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build Google Maps URL with origin & destination markers
  String _buildGoogleMapsUrl(dynamic trip) {
    final oLat = trip.originLat;
    final oLng = trip.originLng;
    final dLat = trip.destinationLat;
    final dLng = trip.destinationLng;
    // Google Maps directions URL: origin → destination
    return 'https://www.google.com/maps/dir/?api=1'
        '&origin=$oLat,$oLng'
        '&destination=$dLat,$dLng'
        '&travelmode=driving';
  }

  Future<void> _openGoogleMaps(dynamic trip) async {
    final url = Uri.parse(_buildGoogleMapsUrl(trip));
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tidak dapat membuka Google Maps. Pastikan aplikasi Google Maps terinstall.'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuka Google Maps: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildActiveTripView(dynamic trip, Color primary, TripState state) {
    if (_webViewController == null || _loadedTripId != trip.id) {
      _loadedTripId = trip.id;
      _isMapLoading = true;
      _hasMapError = false;
      _initWebView(trip);
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Premium Map Header with Fallback ──
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            height: _hasMapError ? null : (_isMapMaximized ? 400 : 240),
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                children: [
                  // WebView or Fallback
                  if (_hasMapError)
                    _buildMapFallback(trip, primary)
                  else if (_webViewController != null) ...[
                    WebViewWidget(
                      controller: _webViewController!,
                      gestureRecognizers: {
                        Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
                      },
                    ),
                    if (_isMapLoading)
                      Container(
                        color: Colors.white,
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                  ],

                  // Status Badge
                  Positioned(
                    top: 12,
                    left: 12,
                    child: _buildStatusBadge(trip.status),
                  ),
                ],
              ),
            ),
          ),

          // ── Detailed Trip Card ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              color: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: Colors.grey[20] ?? Colors.grey.shade200, width: 1.2),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Origin and Destination timeline
                    _buildRouteTimeline(trip.originName, trip.destinationName),
                    const Divider(height: 32),

                    // Capacity stats
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatTile(
                            icon: Icons.fitness_center_rounded,
                            label: 'Kapasitas Berat',
                            value: '${trip.availableWeightKg} / ${trip.maxWeightKg} Kg',
                            color: Colors.blueAccent,
                          ),
                        ),
                        Expanded(
                          child: _buildStatTile(
                            icon: Icons.inventory_2_rounded,
                            label: 'Kapasitas Volume',
                            value: '${trip.availableVolumeLiters} / ${trip.maxVolumeLiters} L',
                            color: Colors.amber[700]!,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Departure & Vehicle info
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatTile(
                            icon: Icons.calendar_month_rounded,
                            label: 'Keberangkatan',
                            value: DateFormat('d MMM yyyy, HH:mm', 'id_ID').format(trip.departureTime),
                            color: primary,
                          ),
                        ),
                        Expanded(
                          child: _buildStatTile(
                            icon: trip.vehicleType == 'car'
                                ? Icons.directions_car_rounded
                                : Icons.motorcycle_rounded,
                            label: 'Kendaraan',
                            value: trip.vehicleType == 'car' ? 'Mobil' : 'Motor',
                            color: Colors.teal,
                          ),
                        ),
                      ],
                    ),

                    if (trip.notes != null && trip.notes!.isNotEmpty) ...[
                      const Divider(height: 32),
                      const Text(
                        'Keterangan Perjalanan:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMain),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        trip.notes!,
                        style: const TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.4),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── Control Button Actions ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // Cancellation Button
                Expanded(
                  child: OutlinedButton(
                    onPressed: state.isLoading
                        ? null
                        : () => _showCancelConfirm(trip.id),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Colors.redAccent, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      foregroundColor: Colors.redAccent,
                    ),
                    child: const Text('Batalkan Trip', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ),
                const SizedBox(width: 16),

                // Primary Start/Complete Button
                Expanded(
                  child: ElevatedButton(
                    onPressed: state.isLoading
                        ? null
                        : () => _handlePrimaryAction(trip, state),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: trip.status == 'active' ? primary : Colors.green[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: state.isLoading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            trip.status == 'active' ? 'Mulai Perjalanan' : 'Selesaikan Trip',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _initWebView(dynamic trip) {
    final url = Uri.parse('${AppConfig.webBaseUrl}/map/route').replace(
      queryParameters: {
        'origin_lat': trip.originLat.toString(),
        'origin_lng': trip.originLng.toString(),
        'dest_lat': trip.destinationLat.toString(),
        'dest_lng': trip.destinationLng.toString(),
      },
    );

    _webViewController = WebViewController()
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
            // Only handle main frame errors (not sub-resource errors)
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
  }

  /// Fallback widget when WebView cannot load the map page
  Widget _buildMapFallback(dynamic trip, Color primary) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primary.withValues(alpha: 0.06),
            primary.withValues(alpha: 0.02),
          ],
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 28), // Space for status badge
          // Map icon
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.map_outlined, size: 36, color: primary),
          ),
          const SizedBox(height: 16),
          const Text(
            'Peta tidak dapat dimuat',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textMain,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Halaman peta rute tidak tersedia saat ini.\nAnda masih dapat melihat detail rute di bawah.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          // Route info summary
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              children: [
                const Icon(Icons.circle_rounded, color: Colors.green, size: 12),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    trip.originName ?? 'Asal',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMain),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.grey[400]),
                ),
                const Icon(Icons.flag_rounded, color: Colors.red, size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    trip.destinationName ?? 'Tujuan',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMain),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Open in Google Maps button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _openGoogleMaps(trip),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text(
                'Buka Rute di Google Maps',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: primary,
                side: BorderSide(color: primary.withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final isActive = status == 'active';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isActive ? Colors.amber[700] : Colors.green[600],
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            isActive ? 'SIAP JALAN' : 'PERJALANAN',
            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteTimeline(String origin, String dest) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.circle_rounded, color: Colors.green, size: 16),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Asal Keberangkatan', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  const SizedBox(height: 2),
                  Text(origin, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textMain)),
                ],
              ),
            ),
          ],
        ),
        // Line between points
        Container(
          height: 20,
          margin: const EdgeInsets.only(left: 7.5),
          child: const VerticalDivider(
            thickness: 1.5,
            color: Colors.grey,
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.flag_rounded, color: Colors.red, size: 18),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Tujuan Perjalanan', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  const SizedBox(height: 2),
                  Text(dest, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textMain)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textMain),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handlePrimaryAction(dynamic trip, TripState state) async {
    final notifier = ref.read(tripProvider.notifier);
    if (trip.status == 'active') {
      final ok = await notifier.startTrip(trip.id);
      if (ok) {
        _showSuccess('🚀 Perjalanan trip Anda telah dimulai!');
      }
    } else {
      final ok = await notifier.completeTrip(trip.id);
      if (ok) {
        _showSuccess('🎉 Selamat! Perjalanan trip Anda telah selesai.');
      }
    }
  }

  void _showCancelConfirm(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Batalkan Trip?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Apakah Anda yakin ingin membatalkan rute perjalanan trip aktif ini?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final ok = await ref.read(tripProvider.notifier).cancelTrip(id);
              if (ok) {
                _showSuccess('Trip berhasil dibatalkan.');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Ya, Batalkan'),
          ),
        ],
      ),
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.secondary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
