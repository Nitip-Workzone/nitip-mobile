import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/config/app_config.dart';
import '../../../core/services/crash_service.dart';
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
  bool _isInitializing = false;
  String _lastErrorDetails = '';
  String _lastLoadedUrl = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryInitWebView();
    });
  }

  void _tryInitWebView() async {
    final authState = ref.read(authProvider);
    final token = authState.accessToken;

    if (token == null || token.isEmpty) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
          _lastErrorDetails = 'No token available in SecureStorage';
        });
      }
      _handleSessionExpired();
      return;
    }

    if (_loadedToken == token && _webViewController != null) {
      return;
    }

    if (_isInitializing) {
      return;
    }

    _isInitializing = true;
    _loadedToken = token;
    _initWebView(token);
  }

  void _handleSessionExpired() {
    if (_isHandlingSessionExpired) return;
    _isHandlingSessionExpired = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        await ref.read(authProvider.notifier).logout();
      } catch (_) {
      } finally {
        _isHandlingSessionExpired = false;
      }
    });
  }

  bool _isLoginWebPage(Uri uri) {
    final path = uri.path;
    final hasTokenQuery = uri.queryParameters.containsKey('token') && (uri.queryParameters['token']?.isNotEmpty ?? false);
    if (hasTokenQuery) return false;
    if (path == '/merchant/login' || path == '/merchant/login/' || path == '/login' || path == '/login/') {
      return true;
    }
    if (_loadedToken != null && path.contains('/merchant/login')) {
      return true;
    }
    return false;
  }

  Future<void> _initWebView(String token) async {
    final String safeToken = token.replaceAll("'", r"\'");
    final targetUrl = Uri.parse('${AppConfig.webBaseUrl}/merchant/login').replace(queryParameters: {'token': token});

    final newController = WebViewController(
      onPermissionRequest: (WebViewPermissionRequest request) {
        request.grant();
      },
    );

    try {
      await newController.clearCache();
      await newController.clearLocalStorage();
    } catch (_) {}

    // Set cookie BEFORE loadRequest agar middleware langsung authenticated
    try {
      final cookieManager = WebViewCookieManager();
      final domain = Uri.parse(AppConfig.webBaseUrl).host;
      await cookieManager.setCookie(
        WebViewCookie(name: 'auth_token', value: token, domain: domain, path: '/'),
      );
    } catch (_) {}

    _webViewController = newController;

    if (newController.platform is AndroidWebViewController) {
      final androidController = newController.platform as AndroidWebViewController;
      androidController.setOnShowFileSelector((FileSelectorParams params) async {
        try {
          final ImageSource? source = await showModalBottomSheet<ImageSource>(
            context: context,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            builder: (BuildContext context) {
              return SafeArea(
                child: Wrap(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Pilih Sumber Gambar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textMain)),
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
          if (source == ImageSource.camera) {
            final permission = await Permission.camera.request();
            if (!permission.isGranted) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Izin akses kamera ditolak. Silakan berikan izin di pengaturan perangkat Anda.')),
                );
              }
              return [];
            }
          }

          final ImagePicker picker = ImagePicker();
          final XFile? image = await picker.pickImage(source: source, maxWidth: 1024, maxHeight: 1024, imageQuality: 85);
          if (image != null) {
            return [Uri.file(image.path).toString()];
          }
        } catch (_) {}
        return [];
      });
    }

    newController
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setUserAgent('Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36 NitipMerchant/1.0')
      ..setOnConsoleMessage((JavaScriptConsoleMessage msg) {
        // Only log interesting errors to crash service, no debugPrint flood
        if (msg.message.contains('Gangguan') || msg.message.contains('500') || msg.message.contains('Server')) {
          CrashService.logError('WebView JS console error: ${msg.message}', null, reason: 'webview_js_console', extras: {'url': targetUrl.toString()});
        }
        if (kDebugMode) {
          // debugPrint('[MerchantWebView][JS] ${msg.message}');
        }
      })
      ..addJavaScriptChannel('NitipLogout', onMessageReceived: (JavaScriptMessage message) {
        _handleSessionExpired();
      })
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            return NavigationDecision.navigate;
          },
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = true;
                _hasError = false;
              });
            }
          },
          onPageFinished: (String url) async {
            final String injectJs = """
              (function() {
                try {
                  var token = '$safeToken';
                  try {
                    localStorage.setItem('auth_token', token);
                    localStorage.setItem('token', token);
                    var maxAge = 60 * 60 * 24 * 7;
                    document.cookie = 'auth_token=' + token + '; path=/; max-age=' + maxAge + '; SameSite=Lax';
                    sessionStorage.setItem('auth_token', token);
                  } catch(e) {}

                  var path = window.location.pathname;
                  if (path === '/merchant/login' || path === '/login' || path.includes('/merchant/login')) {
                    if (token && token.length > 20) {
                      setTimeout(function() { 
                        var cur = window.location.pathname;
                        if (cur === '/merchant/login' || cur.includes('/merchant/login')) {
                          window.location.href = '/merchant/menu'; 
                        }
                      }, 500);
                    }
                  }
                } catch (e) {}

                if ('serviceWorker' in navigator) {
                  navigator.serviceWorker.getRegistrations().then(function(registrations) {
                    for (var reg of registrations) { try { reg.unregister(); } catch(e) {} }
                  });
                }
                if ('caches' in window) {
                  caches.keys().then(function(names){
                    for (var n of names) { try { caches.delete(n); } catch(e) {} }
                  });
                }

                window.triggerNativeLogout = function(reason) {
                  try {
                    if (window.NitipLogout) { window.NitipLogout.postMessage(reason || 'session_expired'); }
                  } catch (e) {}
                };

                // Lightweight 401 detector — no payload/body logging for perf & security
                (function() {
                  if (window.__nitipFetchPatched) return;
                  window.__nitipFetchPatched = true;
                  var origFetch = window.fetch;
                  window.fetch = async function() {
                    var url = arguments[0];
                    var urlStr = typeof url === 'string' ? url : (url.url || String(url));
                    try {
                      var resp = await origFetch.apply(this, arguments);
                      if (resp.status === 401 && urlStr.indexOf('/api/') !== -1) {
                        window.triggerNativeLogout('api_401');
                      }
                      return resp;
                    } catch (err) {
                      throw err;
                    }
                  };
                  var origOpen = XMLHttpRequest.prototype.open;
                  var origSend = XMLHttpRequest.prototype.send;
                  XMLHttpRequest.prototype.open = function() {
                    this._method = arguments[0];
                    this._url = arguments[1];
                    return origOpen.apply(this, arguments);
                  };
                  XMLHttpRequest.prototype.send = function() {
                    var self = this;
                    self.addEventListener('load', function() {
                      if (self.status === 401 && self._url && self._url.indexOf('/api/') !== -1) {
                        window.triggerNativeLogout('xhr_401');
                      }
                    });
                    return origSend.apply(this, arguments);
                  };
                })();
              })();
            """;
            try {
              await newController.runJavaScript(injectJs);
            } catch (_) {}

            // Detect Nuxt error page via JS title
            try {
              final String title = await newController.runJavaScriptReturningResult('document.title') as String;
              final String bodySnippet = await newController.runJavaScriptReturningResult('document.body ? document.body.innerText.substring(0,500) : ""') as String;
              if (title.contains('Gangguan') || bodySnippet.contains('Terjadi Gangguan Pada Server') || bodySnippet.contains('500')) {
                if (mounted) {
                  setState(() {
                    _lastErrorDetails = 'Nuxt error.vue detected - Server 500 - Title: $title';
                    _hasError = true;
                  });
                }
              }
            } catch (_) {}

            final uri = Uri.tryParse(url);
            if (uri != null && _isLoginWebPage(uri)) {
              Future.delayed(const Duration(seconds: 2), () {
                if (!mounted) return;
                _webViewController?.currentUrl().then((current) {
                  final curUri = current != null ? Uri.tryParse(current.toString()) : null;
                  if (curUri != null && _isLoginWebPage(curUri)) {
                    _handleSessionExpired();
                  }
                });
              });
            }

            if (mounted) {
              setState(() {
                _isLoading = false;
                _lastLoadedUrl = url;
              });
            }
          },
          onWebResourceError: (WebResourceError error) {
            if (error.errorCode == -999 ||
                error.description.contains('net::ERR_CACHE_MISS') ||
                error.description.contains('Frame load interrupted') ||
                error.description.contains('cache') ||
                error.description.contains('ERR_UNKNOWN_URL_SCHEME')) {
              return;
            }
            CrashService.logWebViewError(
              url: error.url?.toString() ?? targetUrl.toString(),
              errorCode: error.errorCode,
              description: error.description,
              failingUrl: error.url?.toString(),
            );
            if (mounted) {
              setState(() {
                _hasError = true;
                _isLoading = false;
                _lastErrorDetails = 'Code: ${error.errorCode}\\nDesc: ${error.description}\\nURL: ${error.url}';
              });
            }
          },
        ),
      )
      ..loadRequest(targetUrl);

    if (mounted) {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _isInitializing = false;
      });
    }
  }

  void _reload() {
    try {
      _webViewController?.clearCache();
      _webViewController?.clearLocalStorage();
    } catch (_) {}
    _loadedToken = null;
    _webViewController = null;
    setState(() {
      _isLoading = true;
      _hasError = false;
      _lastErrorDetails = '';
    });
    _tryInitWebView();
  }

  Future<void> _hardReloadClearAll() async {
    try {
      if (_webViewController != null) {
        await _webViewController!.clearCache();
        await _webViewController!.clearLocalStorage();
        final cm = WebViewCookieManager();
        final domain = Uri.parse(AppConfig.webBaseUrl).host;
        await cm.clearCookies();
        final auth = ref.read(authProvider);
        final token = auth.accessToken;
        if (token != null && token.isNotEmpty) {
          await cm.setCookie(WebViewCookie(name: 'auth_token', value: token, domain: domain, path: '/'));
        }
      }
    } catch (_) {}
    _reload();
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keluar Aplikasi', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Apakah Anda yakin ingin keluar dari akun Merchant Anda?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal', style: TextStyle(color: AppColors.textMuted))),
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

    if (token != null && token.isNotEmpty && _loadedToken != null && _loadedToken != token) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _tryInitWebView();
      });
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final controller = _webViewController;
        if (controller != null && await controller.canGoBack()) {
          await controller.goBack();
        } else {
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
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.storefront_rounded, color: AppColors.primary, size: 16),
              ),
              const SizedBox(width: 10),
              const Text('Mitra Merchant', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textMain)),
            ],
          ),
          actions: [
            IconButton(icon: const Icon(Icons.refresh_rounded, color: AppColors.primary), tooltip: 'Muat Ulang', onPressed: _reload, focusNode: FocusNode(skipTraversal: true)),
            IconButton(icon: const Icon(Icons.logout_rounded, color: AppColors.error), tooltip: 'Keluar', onPressed: _handleLogout, focusNode: FocusNode(skipTraversal: true)),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: AppColors.border.withValues(alpha: 0.5)),
          ),
        ),
        body: Stack(
          children: [
            if (!_hasError && _webViewController != null) WebViewWidget(controller: _webViewController!)
            else if (_hasError)
              SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), shape: BoxShape.circle),
                        child: const Icon(Icons.error_outline_rounded, size: 48, color: Colors.orange),
                      ),
                      const SizedBox(height: 16),
                      const Text('Gagal Memuat Portal Merchant', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textMain)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Detail Error:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            SelectableText(
                              'URL: $_lastLoadedUrl\n\n${_lastErrorDetails.isEmpty ? "Tidak ada detail" : _lastErrorDetails}\n\nEnv: ${AppConfig.env}\nWeb: ${AppConfig.webBaseUrl}',
                              style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _reload,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Coba Lagi'),
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _hardReloadClearAll,
                              icon: const Icon(Icons.cleaning_services_rounded),
                              label: const Text('Hard Reset', style: TextStyle(fontSize: 12)),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final url = Uri.parse('${AppConfig.webBaseUrl}/merchant/login');
                          if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
                        },
                        icon: const Icon(Icons.open_in_browser_rounded, size: 16),
                        label: const Text('Buka di Browser', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ),
            if (_isLoading && !_hasError)
              const Positioned(
                top: 0, left: 0, right: 0,
                child: LinearProgressIndicator(minHeight: 3, valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary)),
              ),
          ],
        ),
      ),
    );
  }
}
