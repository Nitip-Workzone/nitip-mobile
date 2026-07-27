import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/config/app_config.dart';
import '../../providers/auth_provider.dart';

class MerchantDashboardPage extends ConsumerStatefulWidget {
  const MerchantDashboardPage({super.key});

  @override
  ConsumerState<MerchantDashboardPage> createState() => _MerchantDashboardPageState();
}

class _MerchantDashboardPageState extends ConsumerState<MerchantDashboardPage> {
  WebViewController? _webViewController;
  bool _isLoading = true;
  bool _hasError = false;
  String? _loadedToken;
  bool _isHandlingSessionExpired = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryInitWebView();
    });
  }

  void _tryInitWebView() {
    final authState = ref.read(authProvider);
    final token = authState.accessToken;

    if (token == null || token.isEmpty) {
      debugPrint('[MerchantWebView] No token available, triggering native logout');
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
      _handleSessionExpired();
      return;
    }

    if (_loadedToken == token && _webViewController != null) return;

    _loadedToken = token;
    _initWebView(token);
  }

  void _handleSessionExpired() {
    if (_isHandlingSessionExpired) return;
    _isHandlingSessionExpired = true;
    debugPrint('[MerchantWebView] Session expired detected -> logout native');
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        await ref.read(authProvider.notifier).logout();
      } catch (e) {
        debugPrint('[MerchantWebView] Error during expired logout: $e');
      } finally {
        _isHandlingSessionExpired = false;
      }
    });
  }

  bool _isLoginWebPage(Uri uri) {
    // Deteksi apakah WebView mengarah ke halaman login web (tanpa token query)
    // Kasus expired: Nuxt middleware redirect /merchant/menu atau /merchant/* ke /merchant/login
    final path = uri.path;
    final hasTokenQuery = uri.queryParameters.containsKey('token') && (uri.queryParameters['token']?.isNotEmpty ?? false);

    // Jika path adalah login web dan tidak bawa token => token expired / session invalid
    if (hasTokenQuery) return false;

    if (path == '/merchant/login' || path == '/merchant/login/' || path == '/login' || path == '/login/') {
      return true;
    }
    // Kadang web redirect ke root dengan param? tetap anggap expired jika WebView sebelumnya sudah login dan tiba-tiba balik ke login
    if (_loadedToken != null && (path == '/merchant/login' || path.contains('/merchant/login'))) {
      return true;
    }
    return false;
  }

  void _initWebView(String token) {
    // PENTING: Gunakan token sebagai query parameter langsung ke halaman merchant/login
    // Middleware auth.global.ts di Nuxt sudah menangani ?token= untuk auto-login
    final bridgeUrl = Uri.parse('${AppConfig.webBaseUrl}/merchant/login')
        .replace(queryParameters: {'token': token});
    debugPrint('[MerchantWebView] Initializing via bridge: $bridgeUrl');

    // Inisialisasi controller terlebih dahulu dan assign ke field kelas,
    // agar bisa direferensikan di dalam closure NavigationDelegate.
    final newController = WebViewController(
      onPermissionRequest: (WebViewPermissionRequest request) {
        debugPrint('[MerchantWebView] Granting webview permission request');
        request.grant();
      },
    );
    _webViewController = newController;

    // Cek jika platform adalah Android, aktifkan handler file chooser untuk <input type="file">
    if (newController.platform is AndroidWebViewController) {
      final androidController = newController.platform as AndroidWebViewController;
      androidController.setOnShowFileSelector((FileSelectorParams params) async {
        try {
          // Tampilkan dialog/bottom sheet untuk memilih Kamera atau Galeri
          final ImageSource? source = await showModalBottomSheet<ImageSource>(
            context: context,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (BuildContext context) {
              return SafeArea(
                child: Wrap(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Pilih Sumber Gambar',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textMain),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
                      title: const Text('Pilih dari Galeri'),
                      onTap: () => Navigator.pop(context, ImageSource.gallery),
                    ),
                    ListTile(
                      leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
                      title: const Text('Ambil Foto (Kamera)'),
                      onTap: () => Navigator.pop(context, ImageSource.camera),
                    ),
                  ],
                ),
              );
            },
          );

          if (source == null) return [];

          // Request izin kamera jika memilih kamera
          if (source == ImageSource.camera) {
            final permission = await Permission.camera.request();
            if (!permission.isGranted) {
              debugPrint('[MerchantWebView] Camera permission denied');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Izin akses kamera ditolak. Silakan berikan izin di pengaturan perangkat Anda.')),
                );
              }
              return [];
            }
          }

          final ImagePicker picker = ImagePicker();
          final XFile? image = await picker.pickImage(
            source: source,
            maxWidth: 1024,
            maxHeight: 1024,
            imageQuality: 85,
          );
          if (image != null) {
            final fileUri = Uri.file(image.path).toString();
            debugPrint('[MerchantWebView] Selected image URI: $fileUri');
            return [fileUri];
          }
        } catch (e) {
          debugPrint('[MerchantWebView] Error picking image: $e');
        }
        return [];
      });
    }

    newController
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..addJavaScriptChannel(
        'NitipLogout',
        onMessageReceived: (JavaScriptMessage message) {
          debugPrint('[MerchantWebView] JS channel NitipLogout received: ${message.message}');
          _handleSessionExpired();
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            final uri = Uri.tryParse(request.url);
            if (uri != null) {
              if (_isLoginWebPage(uri)) {
                // Skip jika ini request awal dengan token (bridge login)
                final isBridgeRequest = request.url.contains('/merchant/login') && uri.queryParameters.containsKey('token');
                if (!isBridgeRequest) {
                  debugPrint('[MerchantWebView] Blocked web login page navigation -> native logout: $uri');
                  _handleSessionExpired();
                  return NavigationDecision.prevent;
                }
              }
            }
            return NavigationDecision.navigate;
          },
          onUrlChange: (UrlChange change) {
            final urlStr = change.url ?? '';
            final uri = Uri.tryParse(urlStr);
            if (uri != null && _isLoginWebPage(uri)) {
              final isBridge = urlStr.contains('/merchant/login') && uri.queryParameters.containsKey('token');
              if (!isBridge) {
                debugPrint('[MerchantWebView] onUrlChange detected login web -> native logout: $uri');
                _handleSessionExpired();
              }
            }
          },
          onPageStarted: (String url) {
            final uri = Uri.tryParse(url);
            if (uri != null && _isLoginWebPage(uri)) {
              final isBridge = url.contains('/merchant/login') && uri.queryParameters.containsKey('token');
              if (!isBridge) {
                debugPrint('[MerchantWebView] onPageStarted login web detected -> native logout: $uri');
                // Jangan set loading, langsung logout
                _handleSessionExpired();
              }
            }
            if (mounted) {
              setState(() {
                _isLoading = true;
                _hasError = false;
              });
            }
          },
          onPageFinished: (String url) async {
            debugPrint('[MerchantWebView] Page finished: $url');

            final uri = Uri.tryParse(url);
            if (uri != null && _isLoginWebPage(uri)) {
              final isBridge = url.contains('/merchant/login') && uri.queryParameters.containsKey('token');
              if (!isBridge) {
                debugPrint('[MerchantWebView] Page finished still on login web -> force native logout');
                _handleSessionExpired();
                if (mounted) {
                  setState(() {
                    _isLoading = false;
                  });
                }
                return;
              }
            }

            // Unregister semua Service Worker PWA agar tidak mengintervensi
            // navigasi & routing internal. WebView mobile tidak perlu PWA caching.
            // Dan inject JS helper untuk memanggil NitipLogout channel jika web detect 401
            const jsHelpers = '''
              (function() {
                if ('serviceWorker' in navigator) {
                  navigator.serviceWorker.getRegistrations().then(function(registrations) {
                    for (let reg of registrations) {
                      reg.unregister();
                      console.log('[WebView Mobile] Service Worker unregistered:', reg.scope);
                    }
                  });
                }
                // Helper: expose function for web to trigger native logout when session expired
                window.triggerNativeLogout = function(reason) {
                  try {
                    if (window.NitipLogout) {
                      window.NitipLogout.postMessage(reason || 'session_expired');
                    }
                  } catch (e) {
                    console.log('[WebView Mobile] triggerNativeLogout error', e);
                  }
                };
                // Intercept 401 di fetch/XHR untuk merchant portal (optional best-effort)
                (function() {
                  const origFetch = window.fetch;
                  window.fetch = async function() {
                    const resp = await origFetch.apply(this, arguments);
                    try {
                      if (resp.status === 401) {
                        const url = arguments[0];
                        if (typeof url === 'string' && url.includes('/api/')) {
                          console.log('[WebView Mobile] 401 detected on API, triggering native logout');
                          window.triggerNativeLogout('api_401');
                        }
                      }
                    } catch (e) {}
                    return resp;
                  };
                })();
              })();
            ''';
            try {
              await _webViewController?.runJavaScript(jsHelpers);
            } catch (e) {
              debugPrint('[MerchantWebView] JS injection failed: $e');
            }

            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('[WebView Merchant Error] Code: ${error.errorCode}, Desc: ${error.description}');
            if (error.errorCode == -999 ||
                error.description.contains('net::ERR_CACHE_MISS') ||
                error.description.contains('Frame load interrupted') ||
                error.description.contains('cache') ||
                error.description.contains('ERR_UNKNOWN_URL_SCHEME')) {
              return;
            }
            if (mounted) {
              setState(() {
                _hasError = true;
                _isLoading = false;
              });
            }
          },
        ),
      )
      ..loadRequest(bridgeUrl);

    if (mounted) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    }
  }



  void _reload() {
    _loadedToken = null;
    _webViewController = null;
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    _tryInitWebView();
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keluar Aplikasi', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Apakah Anda yakin ingin keluar dari akun Merchant Anda?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(authProvider.notifier).logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final token = authState.accessToken;

    if (token != null && token.isNotEmpty && _loadedToken != token) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _tryInitWebView();
      });
    }

    // Wrap with PopScope to handle back gestures/buttons
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final controller = _webViewController;
        if (controller != null && await controller.canGoBack()) {
          // If webview can navigate backward, do so
          await controller.goBack();
        } else {
          // If we reached the end of history, trigger the logout dialog
          await _handleLogout();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          title: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.storefront_rounded, color: AppColors.primary, size: 16),
              ),
              const SizedBox(width: 10),
              const Text(
                'Mitra Merchant',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.textMain,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
              tooltip: 'Muat Ulang',
              onPressed: _reload,
              focusNode: FocusNode(skipTraversal: true),
            ),
            IconButton(
              icon: const Icon(Icons.logout_rounded, color: AppColors.error),
              tooltip: 'Keluar',
              onPressed: _handleLogout,
              focusNode: FocusNode(skipTraversal: true),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(
              height: 1,
              color: AppColors.border.withValues(alpha: 0.5),
            ),
          ),
        ),
        body: Stack(
          children: [
            if (!_hasError && _webViewController != null)
              WebViewWidget(controller: _webViewController!)
            else if (_hasError)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.signal_wifi_off_rounded,
                          size: 48,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Gagal Memuat Portal Merchant',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: AppColors.textMain,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Pastikan Anda terhubung ke internet dan server tersedia.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                      ),
                      const SizedBox(height: 28),
                      ElevatedButton.icon(
                        onPressed: _reload,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Coba Lagi'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_isLoading && !_hasError)
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(
                  minHeight: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
