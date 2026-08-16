import 'package:flutter/material.dart';
import 'package:nitip_flutter_mobile/presentation/widgets/common/safe_webview_widget.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../../core/config/app_config.dart';

class LocationDetailSheet extends StatefulWidget {
  final LatLng location;
  final String address;
  final Color primaryColor;

  const LocationDetailSheet({
    super.key,
    required this.location,
    required this.address,
    required this.primaryColor,
  });

  @override
  State<LocationDetailSheet> createState() => _LocationDetailSheetState();
}

class _LocationDetailSheetState extends State<LocationDetailSheet> {
  late final WebViewController _webViewController;
  bool _copiedCoords = false;
  bool _hasWebViewError = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    final colorHex = (widget.primaryColor.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0');
    final url = Uri.parse('${AppConfig.webBaseUrl}/map/viewer').replace(
      queryParameters: {
        'lat': widget.location.latitude.toString(),
        'lng': widget.location.longitude.toString(),
        'color': colorHex,
      },
    );
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() { _isLoading = true; _hasWebViewError = false; });
          },
          onPageFinished: (pageUrl) {
            if (mounted) setState(() => _isLoading = false);
            // Detect Nuxt error page "Terjadi Gangguan Pada Server" via JS title check
            _webViewController.runJavaScript("""
              (function(){
                var title = document.title || '';
                var body = document.body ? document.body.innerText : '';
                if (title.includes('Gangguan') || body.includes('Terjadi Gangguan Pada Server') || body.includes('500') && body.includes('Server')) {
                  console.log('[LocationDetailSheet] Detected error page');
                  if (window.flutter_inappwebview) {}
                  // Notify via channel if needed
                }
              })();
            """);
          },
          onWebResourceError: (error) {
            if (error.description.contains('500') || error.description.contains('Internal Server Error') || error.description.contains('Gangguan')) {
              if (mounted) setState(() { _hasWebViewError = true; _isLoading = false; });
            }
          },
        ),
      )
      ..loadRequest(url);
  }

  void _copyToClipboard(String text, bool isCoords) {
    Clipboard.setData(ClipboardData(text: text));
    setState(() {
      if (isCoords) {
        _copiedCoords = true;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              isCoords ? "Koordinat berhasil disalin!" : "Alamat berhasil disalin!",
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        backgroundColor: widget.primaryColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );

    if (isCoords) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _copiedCoords = false;
          });
        }
      });
    }
  }

  Future<void> _openInGoogleMaps() async {
    final lat = widget.location.latitude;
    final lng = widget.location.longitude;
    final url = Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$lng");

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw "Tidak dapat membuka peta.";
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Gagal membuka Google Maps. Silakan salin koordinat."),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lat = widget.location.latitude;
    final lng = widget.location.longitude;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle indicator
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: widget.primaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.location_on_rounded, color: widget.primaryColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Detail Lokasi Saya",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                      Text(
                        "Posisi GPS Aktif Runner",
                        style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, size: 18, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),

          // Interactive Map Area - with error fallback for 500 "Terjadi Gangguan Pada Server"
          Expanded(
            child: Stack(
              children: [
                if (!_hasWebViewError)
                  SafeWebViewWidget(
                    controller: _webViewController,
                    gestureRecognizers: {
                      Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
                    },
                  )
                else
                  Container(
                    color: Colors.white,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.orange),
                        const SizedBox(height: 12),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            'Peta web.nihtip.com sedang gangguan (500)\nGunakan Google Maps sementara',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() { _hasWebViewError = false; _isLoading = true; });
                            final colorHex = (widget.primaryColor.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0');
                            final url = Uri.parse('${AppConfig.webBaseUrl}/map/viewer').replace(
                              queryParameters: {
                                'lat': widget.location.latitude.toString(),
                                'lng': widget.location.longitude.toString(),
                                'color': colorHex,
                              },
                            );
                            _webViewController.loadRequest(url);
                          },
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Coba Lagi'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.primaryColor,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _openInGoogleMaps,
                          icon: const Icon(Icons.map_rounded, size: 18),
                          label: const Text('Buka Google Maps'),
                        ),
                      ],
                    ),
                  ),

                if (_isLoading && !_hasWebViewError)
                  const Positioned(
                    top: 0, left: 0, right: 0,
                    child: LinearProgressIndicator(minHeight: 3),
                  ),

                // Map Actions Overlay
                if (!_hasWebViewError)
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: FloatingActionButton(
                      mini: true,
                      backgroundColor: Colors.white,
                      foregroundColor: widget.primaryColor,
                      elevation: 4,
                      onPressed: () => _webViewController.runJavaScript(
                        'if (typeof moveMap === "function") { moveMap(${widget.location.latitude}, ${widget.location.longitude}); }',
                      ),
                      child: const Icon(Icons.my_location),
                    ),
                  ),
              ],
            ),
          ),

          // Details Card & Share Panel
          Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 34),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, -6)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Info block
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "ALAMAT LENGKAP",
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 1),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.address.isNotEmpty ? widget.address : "Mencari detail lokasi...",
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF334155), height: 1.4),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        "KOORDINAT GPS",
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 1),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              "$lat, $lng",
                              style: const TextStyle(
                                fontSize: 13,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _copyToClipboard("$lat, $lng", true),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: _copiedCoords ? const Color(0xFFDCFCE7) : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _copiedCoords ? const Color(0xFF86EFAC) : const Color(0xFFCBD5E1),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _copiedCoords ? Icons.check_rounded : Icons.copy_rounded,
                                    size: 13,
                                    color: _copiedCoords ? const Color(0xFF16A34A) : widget.primaryColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _copiedCoords ? "Tersalin" : "Salin",
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: _copiedCoords ? const Color(0xFF15803D) : widget.primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Primary actions row
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _copyToClipboard(widget.address, false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: widget.primaryColor, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          backgroundColor: Colors.white,
                          foregroundColor: widget.primaryColor,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.assignment_turned_in_rounded, size: 18, color: widget.primaryColor),
                            const SizedBox(width: 8),
                            Text(
                              "Salin Alamat",
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: widget.primaryColor),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _openInGoogleMaps,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.map_rounded, size: 18),
                            SizedBox(width: 8),
                            Text(
                              "Google Maps",
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


