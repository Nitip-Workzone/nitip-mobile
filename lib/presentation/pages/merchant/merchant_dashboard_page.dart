import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/config/app_config.dart';
import '../../../core/services/crash_service.dart';
import '../../../core/utils/webview_debug_logger.dart';
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
  bool _showDebugLog = false;
  String _lastErrorDetails = '';
  String _lastLoadedUrl = '';

  @override
  void initState() {
    super.initState();
    WebViewDebugLogger.clear();
    WebViewDebugLogger.log('Init MerchantDashboardPage');
    WebViewDebugLogger.log('WebBaseUrl: ${AppConfig.webBaseUrl}');
    WebViewDebugLogger.log('ApiBaseUrl: ${AppConfig.baseUrl}');
    WebViewDebugLogger.log('Env: ${AppConfig.env}');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryInitWebView();
    });
  }

  void _tryInitWebView() async {
    final authState = ref.read(authProvider);
    final token = authState.accessToken;

    WebViewDebugLogger.log('TryInitWebView token: ${token != null ? "${token.substring(0, 20)}..." : "null"}');
    WebViewDebugLogger.log('User: ${authState.user?.email} role: ${authState.user?.role}');

    if (token == null || token.isEmpty) {
      debugPrint('[MerchantWebView] No token available, triggering native logout');
      WebViewDebugLogger.log('ERROR: No token available');
      setState(() {
        _hasError = true;
        _isLoading = false;
        _lastErrorDetails = 'No token available in SecureStorage';
      });
      _handleSessionExpired();
      return;
    }

    if (_loadedToken == token && _webViewController != null) {
      WebViewDebugLogger.log('Same token and controller exists, skip reload');
      return;
    }

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

  Future<void> _initWebView(String token) async {
    // FLOW: Login native di Flutter (login_page.dart), jika merchant -> Dashboard langsung MerchantDashboardPage
    // WebView harus akses web.nihtip.com/merchant/* yang dilindungi middleware auth.global.ts
    // Middleware cek cookie auth_token BEFORE render, jadi harus set cookie BEFORE loadRequest
    // Fix: pakai WebViewCookieManager setCookie sebelum load + juga pakai ?token= bridge untuk backward compat dengan middleware tokenQuery
    // Kenapa prod 500? Karena sebelumnya hanya inject token via JS di onPageFinished (AFTER load), middleware sudah redirect ke login sebelum token ada
    final String safeToken = token.replaceAll("'", r"\'");
    // Gunakan bridge login?token= agar middleware set cookie + fetchProfile sebelum redirect ke /merchant/menu
    // Ini yang middleware auth.global.ts sudah support line 6-22 tokenQuery
    final targetUrl = Uri.parse('${AppConfig.webBaseUrl}/merchant/login')
        .replace(queryParameters: {'token': token});
    debugPrint('[MerchantWebView] Initializing via bridge $targetUrl with native merchant role (dashboard_page.dart merchant)');

    // Inisialisasi controller
    final newController = WebViewController(
      onPermissionRequest: (WebViewPermissionRequest request) {
        debugPrint('[MerchantWebView] Granting webview permission request');
        request.grant();
      },
    );

    // Clear cache untuk hindari PWA 500 cache di prod build
    try {
      await newController.clearCache();
      await newController.clearLocalStorage();
    } catch (_) {}

    // FIX 500: Set cookie BEFORE loadRequest agar middleware auth.global.ts langsung authenticated
    // Middleware cek tokenQuery dan auth_token cookie di awal, jika ada maka tidak redirect ke login
    try {
      final cookieManager = WebViewCookieManager();
      final domain = Uri.parse(AppConfig.webBaseUrl).host; // web.nihtip.com
      // Set auth_token cookie untuk domain web.nihtip.com (7 days same as web)
      await cookieManager.setCookie(
        WebViewCookie(
          name: 'auth_token',
          value: token,
          domain: domain,
          path: '/',
        ),
      );
      debugPrint('[MerchantWebView] Cookie auth_token set for $domain BEFORE load');
    } catch (e) {
      debugPrint('[MerchantWebView] Failed to set cookie before load: $e');
    }

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

    // Clear WebView cache untuk hindari PWA 500 cache di prod
    try {
      await newController.clearCache();
      await newController.clearLocalStorage();
    } catch (_) {}

    newController
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      // UserAgent custom untuk bypass Cloudflare Bot Fight Mode yang kadang block WebView default UA
      // Pakai Chrome desktop UA agar web.nihtip.com tidak anggap bot
      ..setUserAgent(
          'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36 NitipMerchant/1.0')
      ..setOnConsoleMessage((JavaScriptConsoleMessage msg) {
        debugPrint('[MerchantWebView][JS ${msg.level.name}] ${msg.message}');
        // Detect Nuxt error page via JS console
        if (msg.message.contains('Gangguan') || msg.message.contains('500') || msg.message.contains('Server')) {
          CrashService.logError(
            'WebView JS console error: ${msg.message}',
            null,
            reason: 'webview_js_console',
            extras: {'url': targetUrl.toString()},
          );
        }
      })
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
            if (uri != null && _isLoginWebPage(uri)) {
              // Native login sudah dilakukan di Flutter, jika web redirect ke login berarti session di web invalid
              // Kita akan coba re-inject token, jika masih fail baru logout
              debugPrint('[MerchantWebView] Blocked web login page navigation -> will try token re-inject: $uri');
              return NavigationDecision.navigate;
            }
            return NavigationDecision.navigate;
          },
          onUrlChange: (UrlChange change) {
            final urlStr = change.url ?? '';
            final uri = Uri.tryParse(urlStr);
            if (uri != null && _isLoginWebPage(uri) && _loadedToken != null) {
              debugPrint('[MerchantWebView] onUrlChange detected login web, will re-inject token if needed: $uri');
            }
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
            debugPrint('[MerchantWebView] Page finished: $url');

            // Inject token ke localStorage + cookie + sessionStorage untuk Nuxt auth
            // Nuxt auth store baca token dari cookie auth_token (lihat auth.ts setToken)
            final String injectJs = """
              (function() {
                try {
                  var token = '$safeToken';
                  console.log('[WebView Mobile] Injecting token, length=' + token.length + ' prefix=' + token.substring(0,20));
                  // 1. localStorage (jika web pakai)
                  localStorage.setItem('auth_token', token);
                  localStorage.setItem('token', token);
                  // 2. cookie (Nuxt auth.ts pakai document.cookie auth_token)
                  var maxAge = 60 * 60 * 24 * 7;
                  document.cookie = 'auth_token=' + token + '; path=/; max-age=' + maxAge + '; SameSite=Lax';
                  // 3. sessionStorage fallback
                  sessionStorage.setItem('auth_token', token);
                  console.log('[WebView Mobile] Token injected to localStorage + cookie + sessionStorage, cookies=' + document.cookie.substring(0,100));

                  // 4. Jika di halaman login dan token sudah diinject, redirect ke /merchant/orders
                  var path = window.location.pathname;
                  if (path === '/merchant/login' || path === '/login' || path.includes('/merchant/login')) {
                    if (token && token.length > 20) {
                      // FIX: merchant/orders pernah 500 karena (as number) di template. Sementara arahkan ke /merchant/menu yang stabil.
                      // Setelah /merchant/orders fixed, boleh balik ke /merchant/orders lagi.
                      console.log('[WebView Mobile] On login page but token present, redirecting to /merchant/menu (was /merchant/orders - fixed 2026-07-28)');
                      setTimeout(function() { window.location.href = '/merchant/menu'; }, 500);
                    }
                  }
                } catch (e) {
                  console.log('[WebView Mobile] Token inject error', e);
                }

                // Unregister SW + clear cache API (PWA 500 cleanup)
                if ('serviceWorker' in navigator) {
                  navigator.serviceWorker.getRegistrations().then(function(registrations) {
                    for (var reg of registrations) {
                      reg.unregister();
                      console.log('[WebView Mobile] SW unregistered:', reg.scope);
                    }
                  });
                }
                if ('caches' in window) {
                  caches.keys().then(function(names){
                    for (var n of names) {
                      console.log('[WebView Mobile] Deleting cache:', n);
                      caches.delete(n);
                    }
                  });
                }

                window.triggerNativeLogout = function(reason) {
                  try {
                    if (window.NitipLogout) {
                      window.NitipLogout.postMessage(reason || 'session_expired');
                    }
                  } catch (e) {
                    console.log('[WebView Mobile] triggerNativeLogout error', e);
                  }
                };

                // FULL FETCH/XHR INTERCEPTOR dengan payload + headers + response logging untuk debug 500
                (function() {
                  function safeStringify(obj, maxLen) {
                    try {
                      var s = JSON.stringify(obj);
                      if (s.length > maxLen) return s.substring(0, maxLen) + '... (truncated)';
                      return s;
                    } catch (e) {
                      return String(obj).substring(0, maxLen);
                    }
                  }

                  // Intercept fetch
                  var origFetch = window.fetch;
                  window.fetch = async function() {
                    var url = arguments[0];
                    var opts = arguments[1] || {};
                    var method = opts.method || 'GET';
                    var reqHeaders = opts.headers || {};
                    var body = opts.body || '';
                    var urlStr = typeof url === 'string' ? url : url.url || String(url);
                    
                    console.log('[FETCH REQ] ' + method + ' ' + urlStr);
                    console.log('[FETCH REQ HEADERS] ' + safeStringify(reqHeaders, 2000));
                    if (body) console.log('[FETCH REQ PAYLOAD] ' + safeStringify(body, 2000));

                    try {
                      var resp = await origFetch.apply(this, arguments);
                      var clone = resp.clone();
                      var respHeaders = {};
                      try {
                        clone.headers.forEach(function(v,k){ respHeaders[k]=v; });
                      } catch(e) {}
                      console.log('[FETCH RESP] ' + method + ' ' + urlStr + ' -> Status: ' + resp.status);
                      console.log('[FETCH RESP HEADERS] ' + safeStringify(respHeaders, 2000));
                      try {
                        var text = await clone.text();
                        console.log('[FETCH RESP BODY] ' + text.substring(0, 3000));
                        if (resp.status >= 400) {
                          console.log('[FETCH RESP ERROR BODY FULL] ' + text.substring(0, 5000));
                        }
                      } catch (e) {
                        console.log('[FETCH RESP BODY] (failed to read) ' + e);
                      }

                      if (resp.status === 401 && urlStr.includes('/api/')) {
                        console.log('[WebView Mobile] 401 detected on API, triggering native logout');
                        window.triggerNativeLogout('api_401');
                      }
                      if (resp.status === 500) {
                        console.log('[FETCH RESP 500 DETECTED] URL: ' + urlStr);
                      }

                      return resp;
                    } catch (err) {
                      console.log('[FETCH ERROR] ' + urlStr + ' -> ' + err);
                      throw err;
                    }
                  };

                  // Intercept XHR
                  var origOpen = XMLHttpRequest.prototype.open;
                  var origSend = XMLHttpRequest.prototype.send;
                  var origSetHeader = XMLHttpRequest.prototype.setRequestHeader;

                  XMLHttpRequest.prototype.open = function() {
                    this._method = arguments[0];
                    this._url = arguments[1];
                    this._reqHeaders = {};
                    return origOpen.apply(this, arguments);
                  };
                  XMLHttpRequest.prototype.setRequestHeader = function(k,v) {
                    this._reqHeaders[k] = v;
                    return origSetHeader.apply(this, arguments);
                  };
                  XMLHttpRequest.prototype.send = function(body) {
                    console.log('[XHR REQ] ' + this._method + ' ' + this._url);
                    console.log('[XHR REQ HEADERS] ' + safeStringify(this._reqHeaders, 2000));
                    if (body) console.log('[XHR REQ PAYLOAD] ' + safeStringify(body, 2000));

                    var self = this;
                    self.addEventListener('load', function() {
                      console.log('[XHR RESP] ' + self._method + ' ' + self._url + ' -> Status: ' + self.status);
                      try {
                        var allHeaders = self.getAllResponseHeaders();
                        console.log('[XHR RESP HEADERS] ' + allHeaders.substring(0, 2000));
                      } catch(e) {}
                      console.log('[XHR RESP BODY] ' + (self.responseText ? self.responseText.substring(0, 3000) : 'empty'));
                    });
                    self.addEventListener('error', function(){
                      console.log('[XHR ERROR] ' + self._method + ' ' + self._url + ' status=' + self.status);
                    });
                    return origSend.apply(this, arguments);
                  };
                })();
              })();
            """;
            try {
              await newController.runJavaScript(injectJs);
              WebViewDebugLogger.log('JS inject success for $url');
            } catch (e) {
              debugPrint('[MerchantWebView] Token JS injection failed: $e');
              WebViewDebugLogger.log('JS inject FAILED: $e');
              setState(() => _lastErrorDetails = 'JS inject failed: $e');
            }

            // Detect Nuxt error page via JS
            try {
              final String title = await newController.runJavaScriptReturningResult('document.title') as String;
              final String bodySnippet = await newController.runJavaScriptReturningResult('document.body ? document.body.innerText.substring(0,500) : ""') as String;
              WebViewDebugLogger.log('Page title: $title');
              WebViewDebugLogger.log('Body snippet: ${bodySnippet.substring(0, bodySnippet.length > 200 ? 200 : bodySnippet.length)}');
              if (title.contains('Gangguan') || bodySnippet.contains('Terjadi Gangguan Pada Server') || bodySnippet.contains('500')) {
                WebViewDebugLogger.log('DETECTED Nuxt error.vue 500 page!');
                setState(() {
                  _lastErrorDetails = 'Nuxt error.vue detected - Server 500 - Title: $title - Body: ${bodySnippet.substring(0, 200)}';
                  _hasError = true;
                });
              }
            } catch (e) {
              WebViewDebugLogger.log('Error checking page content: $e');
            }

            // Jika masih di login page setelah inject, biarkan JS redirect di atas bekerja
            final uri = Uri.tryParse(url);
            if (uri != null && _isLoginWebPage(uri)) {
              WebViewDebugLogger.log('Still on login after inject, waiting 2s for JS redirect: $url');
              Future.delayed(const Duration(seconds: 2), () {
                if (!mounted) return;
                _webViewController?.currentUrl().then((current) {
                  final curUri = current != null ? Uri.tryParse(current.toString()) : null;
                  if (curUri != null && _isLoginWebPage(curUri)) {
                    WebViewDebugLogger.log('Still on login after 2s, forcing logout');
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
            final msg = '[WebView Merchant Error] Code: ${error.errorCode}, Desc: ${error.description}, URL: ${error.url}';
            debugPrint(msg);
            WebViewDebugLogger.log('WebResourceError: Code=${error.errorCode} Desc=${error.description} URL=${error.url} isForMainFrame=${error.isForMainFrame} errorType=${error.errorType}');
            if (error.errorCode == -999 ||
                error.description.contains('net::ERR_CACHE_MISS') ||
                error.description.contains('Frame load interrupted') ||
                error.description.contains('cache') ||
                error.description.contains('ERR_UNKNOWN_URL_SCHEME')) {
              WebViewDebugLogger.log('Ignoring benign error: ${error.errorCode}');
              return;
            }
            CrashService.logWebViewError(
              url: error.url?.toString() ?? targetUrl.toString(),
              errorCode: error.errorCode,
              description: error.description,
              failingUrl: error.url?.toString(),
            );
            final is500 = error.errorCode == 500 ||
                error.description.contains('500') ||
                error.description.contains('Internal Server Error') ||
                error.description.contains('Gangguan');
            if (mounted) {
              setState(() {
                _hasError = true;
                _isLoading = false;
                _lastErrorDetails = 'Code: ${error.errorCode}\nDesc: ${error.description}\nURL: ${error.url}\nType: ${error.errorType}';
              });
            }
            if (is500) {
              WebViewDebugLogger.log('DETECTED 500 error - will show error UI');
            }
          },
        ),
      )
      ..loadRequest(targetUrl);

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
              icon: Icon(_showDebugLog ? Icons.bug_report_rounded : Icons.bug_report_outlined, color: _showDebugLog ? Colors.orange : AppColors.primary),
              tooltip: 'Debug Log (lihat di HP)',
              onPressed: () => setState(() => _showDebugLog = !_showDebugLog),
            ),
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
              SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.error_outline_rounded, size: 48, color: Colors.orange),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Gagal Memuat Portal Merchant',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textMain),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Detail Error (bisa copy & kirim):', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            SelectableText(
                              'URL: $_lastLoadedUrl\n\n${_lastErrorDetails.isEmpty ? "Tidak ada detail" : _lastErrorDetails}\n\nToken: ${_loadedToken != null ? "${_loadedToken!.substring(0, 20)}..." : "null"}\nEnv: ${AppConfig.env}\nWeb: ${AppConfig.webBaseUrl}\nAPI: ${AppConfig.baseUrl}',
                              style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _reload,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Coba Lagi'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final url = Uri.parse('${AppConfig.webBaseUrl}/merchant/login');
                                if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
                              },
                              icon: const Icon(Icons.open_in_browser_rounded, size: 16),
                              label: const Text('Buka Browser', style: TextStyle(fontSize: 12)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: 'URL: $_lastLoadedUrl\nError: $_lastErrorDetails\nEnv: ${AppConfig.env}\nWeb: ${AppConfig.webBaseUrl}'));
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Log disalin ke clipboard')));
                              },
                              icon: const Icon(Icons.copy_rounded, size: 16),
                              label: const Text('Copy Log', style: TextStyle(fontSize: 12)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      StreamBuilder<List<String>>(
                        stream: WebViewDebugLogger.stream,
                        initialData: WebViewDebugLogger.logs,
                        builder: (context, snapshot) {
                          final logs = snapshot.data ?? [];
                          return Container(
                            height: 250,
                            decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.all(8),
                            child: SingleChildScrollView(
                              child: SelectableText(
                                logs.join('\n'),
                                style: const TextStyle(color: Colors.greenAccent, fontSize: 9, fontFamily: 'monospace'),
                              ),
                            ),
                          );
                        },
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
            // Debug log overlay toggle
            if (_showDebugLog)
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  height: 300,
                  color: const Color(0xFF111827).withValues(alpha: 0.95),
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('DEBUG LOG (Live)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, color: Colors.white, size: 18),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: WebViewDebugLogger.allLogs));
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Logs copied')));
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.clear_rounded, color: Colors.white, size: 18),
                            onPressed: () => WebViewDebugLogger.clear(),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                            onPressed: () => setState(() => _showDebugLog = false),
                          ),
                        ],
                      ),
                      Expanded(
                        child: StreamBuilder<List<String>>(
                          stream: WebViewDebugLogger.stream,
                          initialData: WebViewDebugLogger.logs,
                          builder: (context, snap) {
                            final logs = snap.data ?? [];
                            return SingleChildScrollView(
                              child: SelectableText(
                                logs.join('\n'),
                                style: const TextStyle(color: Colors.greenAccent, fontSize: 10, fontFamily: 'monospace'),
                              ),
                            );
                          },
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
}
