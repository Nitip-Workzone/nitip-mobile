import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:latlong2/latlong.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/config/app_config.dart';

class LocationPickerSheet extends StatefulWidget {
  final String title;
  final LatLng? initialLocation;
  final Color primaryColor;

  const LocationPickerSheet({
    super.key,
    required this.title,
    this.initialLocation,
    required this.primaryColor,
  });

  @override
  State<LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<LocationPickerSheet> {
  late final WebViewController _webViewController;
  final LocationService _locationService = LocationService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  
  LatLng _currentCenter = const LatLng(0.8811, 124.014); // Default Lolak
  String _currentAddress = "Mencari alamat...";
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    if (widget.initialLocation != null) {
      _currentCenter = widget.initialLocation!;
      _updateAddress(_currentCenter);
    } else {
      _loadCurrentLocation();
    }

    final queryParams = widget.initialLocation != null ? {
      'lat': widget.initialLocation!.latitude.toString(),
      'lng': widget.initialLocation!.longitude.toString(),
    } : <String, String>{};

    final url = Uri.parse('${AppConfig.webBaseUrl}/map/picker').replace(
      queryParameters: queryParams,
    );

    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..addJavaScriptChannel(
        'LocationChannel',
        onMessageReceived: (JavaScriptMessage message) {
          try {
            final data = jsonDecode(message.message);
            final lat = data['lat'] as double;
            final lng = data['lng'] as double;
            final address = data['address'] as String;
            setState(() {
              _currentCenter = LatLng(lat, lng);
              _currentAddress = address;
            });
          } catch (e) {
            debugPrint('Error decoding WebView message: $e');
          }
        },
      )
      ..loadRequest(url);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentLocation() async {
    setState(() => _isLoading = true);
    final pos = await _locationService.getCurrentPosition();
    setState(() => _isLoading = false);
    
    if (pos != null) {
      setState(() => _currentCenter = pos);
      _webViewController.runJavaScript('if (typeof moveMap === "function") { moveMap(${pos.latitude}, ${pos.longitude}); }');
      await _updateAddress(pos);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Gagal mendapatkan lokasi. Pastikan GPS aktif dan izin diberikan.")),
        );
      }
    }
  }

  Future<void> _updateAddress(LatLng point) async {
    final address = await _locationService.getAddressFromCoords(point.latitude, point.longitude);
    if (mounted) {
      setState(() {
        _currentAddress = address ?? "Alamat tidak ditemukan";
      });
    }
  }

  Future<void> _handleSearch() async {
    if (_searchController.text.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    
    setState(() => _isLoading = true);
    final results = await _locationService.searchPlaces(
      _searchController.text,
      lat: _currentCenter.latitude,
      lng: _currentCenter.longitude,
    );
    setState(() {
      _isLoading = false;
      _searchResults = results;
    });
    
    if (results.isEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lokasi tidak ditemukan")),
      );
    }
  }

  void _selectLocation(Map<String, dynamic> place) {
    final pos = LatLng(place['lat'], place['lng']);
    _webViewController.runJavaScript('if (typeof moveMap === "function") { moveMap(${pos.latitude}, ${pos.longitude}, "${place['display_name']}"); }');
    setState(() {
      _currentCenter = pos;
      _currentAddress = place['display_name'];
      _searchResults = []; // Clear suggestions after selection
      _searchController.text = ""; // Clear search bar
    });
    _searchFocusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFF1F5F9)),
              ),
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _handleSearch(),
                decoration: InputDecoration(
                  hintText: "Cari alamat atau tempat...",
                  hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                  prefixIcon: Icon(Icons.search_rounded, color: widget.primaryColor),
                  suffixIcon: _isLoading 
                    ? UnconstrainedBox(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: widget.primaryColor,
                          ),
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_searchController.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 20),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            ),
                          IconButton(
                            icon: const Icon(Icons.arrow_forward_rounded),
                            onPressed: _handleSearch,
                          ),
                        ],
                      ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
                focusNode: _searchFocusNode,
                onChanged: (val) {
                  if (_debounce?.isActive ?? false) _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 600), () {
                    if (val.length > 3) {
                      _handleSearch();
                    } else if (val.isEmpty) {
                      setState(() => _searchResults = []);
                    }
                  });
                },
              ),
            ),
          ),

          // Map WebView
          Expanded(
            child: Stack(
              children: [
                WebViewWidget(
                  controller: _webViewController,
                  gestureRecognizers: {
                    Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
                  },
                ),

                // Current Location Button
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: FloatingActionButton(
                    mini: true,
                    backgroundColor: Colors.white,
                    onPressed: _loadCurrentLocation,
                    child: Icon(Icons.my_location, color: widget.primaryColor),
                  ),
                ),

                // Search Results Overlay
                if (_searchResults.isNotEmpty)
                  Positioned(
                    top: 0,
                    left: 16,
                    right: 16,
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 300),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 8))
                        ],
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _searchResults.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final place = _searchResults[index];
                          return ListTile(
                            leading: Icon(Icons.location_on_outlined, color: widget.primaryColor, size: 20),
                            title: Text(
                              place['display_name'],
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                            onTap: () => _selectLocation(place),
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Footer info
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 20, offset: const Offset(0, -4))
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
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
                    const Text(
                      "Lokasi Terpilih",
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _currentAddress,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, color: Color(0xFF475569), height: 1.5),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, {
                    'location': _currentCenter,
                    'address': _currentAddress,
                  }),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: const Text(
                    "Konfirmasi Lokasi",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
