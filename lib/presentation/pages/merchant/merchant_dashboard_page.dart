import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/config/app_config.dart';
import '../../../core/services/crash_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/merchant_refresh_provider.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryInitWebView());
  }

  void _tryInitWebView() async {
    final authState = ref.read(authProvider);
    final token = authState.accessToken;
    if (token == null || token.isEmpty) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
          _lastErrorDetails = 'Sesi tidak valid';
        });
      }
      _handleSessionExpired();
      return;
    }
    if (_loadedToken == token && _webViewController != null) return;
    if (_isInitializing) return;
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
    if (path == '/merchant/login' || path == '/merchant/login/' || path == '/login' || path == '/login/') return true;
    if (_loadedToken != null && path.contains('/merchant/login')) return true;
    return false;
  }

  Future<void> _initWebView(String token) async {
    final targetUrl = Uri.parse('${AppConfig.webBaseUrl}/merchant/menu');
    final newController = WebViewController(onPermissionRequest: (r) => r.grant());

    try {
      final cm = WebViewCookieManager();
      final domain = Uri.parse(AppConfig.webBaseUrl).host;
      await cm.setCookie(WebViewCookie(name: 'auth_token', value: token, domain: domain, path: '/'));
    } catch (_) {}

    _webViewController = newController;

    if (newController.platform is AndroidWebViewController) {
      final androidController = newController.platform as AndroidWebViewController;
      try {
        await AndroidWebViewController.enableDebugging(false);
      } catch (_) {}
      try {
        final dynamic ctrl = androidController;
        await ctrl.setForceDark(0);
      } catch (_) {}
      try {
        final dynamic ctrl2 = androidController;
        await ctrl2.setMixedContentMode(0);
      } catch (_) {}

      androidController.setOnShowFileSelector((params) async {
        try {
          final ImageSource? source = await showModalBottomSheet<ImageSource>(
            context: context,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            builder: (BuildContext context) => SafeArea(
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
            ),
          );
          if (source == null) return [];
          if (source == ImageSource.camera) {
            final perm = await Permission.camera.request();
            if (!perm.isGranted) return [];
          }
          final picker = ImagePicker();
          final XFile? img = await picker.pickImage(source: source, maxWidth: 1024, maxHeight: 1024, imageQuality: 85);
          if (img != null) return [Uri.file(img.path).toString()];
        } catch (_) {}
        return [];
      });
    }

    newController
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setUserAgent('Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36 NitipMerchant/1.0')
      ..setOnConsoleMessage((msg) {
        if (msg.message.contains('Gangguan') || msg.message.contains('500')) {
          CrashService.logError('WebView JS error: ${msg.message}', null, reason: 'webview_js_console', extras: {'url': targetUrl.toString()});
        }
      })
      ..addJavaScriptChannel('NitipLogout', onMessageReceived: (_) => _handleSessionExpired())
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (_) => NavigationDecision.navigate,
        onPageStarted: (url) {
          if (mounted) {
            setState(() {
              _isLoading = true;
              _hasError = false;
            });
          }
        },
        onPageFinished: (String url) async {
          const polyfillAt = "if(!Array.prototype.at){Array.prototype.at=function(n){var o=Object(this),l=o.length>>>0,k=Math.trunc(n)||0;if(k<0)k+=l;if(k<0||k>=l)return;return o[k]}}if(!String.prototype.at){String.prototype.at=function(n){var s=String(this),l=s.length,k=Math.trunc(n)||0;if(k<0)k+=l;if(k<0||k>=l)return '';return s[k]||''}}";
          try {
            await newController.runJavaScript(polyfillAt);
          } catch (_) {}

          const injectJs = """
            (function(){
              try{
                if('serviceWorker' in navigator){ navigator.serviceWorker.getRegistrations().then(function(rs){ for(var i=0;i<rs.length;i++){ try{rs[i].unregister();}catch(e){} } }); }
                if('caches' in window){ caches.keys().then(function(names){ for(var n of names){ try{caches.delete(n);}catch(e){} } }); }
                window.triggerNativeLogout=function(r){ try{ if(window.NitipLogout) window.NitipLogout.postMessage(r||'session_expired'); }catch(e){} };
                (function(){
                  if(window.__nitipFetchPatched) return;
                  window.__nitipFetchPatched=true;
                  var origFetch=window.fetch;
                  window.fetch=async function(){
                    var url=arguments[0];
                    var urlStr=typeof url==='string'?url:(url.url||String(url));
                    try{
                      var resp=await origFetch.apply(this,arguments);
                      if(resp.status===401 && urlStr.indexOf('/api/')!==-1){ window.triggerNativeLogout('api_401'); }
                      return resp;
                    }catch(err){ throw err; }
                  };
                })();
              }catch(e){}
            })();
          """;
          try {
            await newController.runJavaScript(injectJs);
          } catch (_) {}

          try {
            final String title = await newController.runJavaScriptReturningResult('document.title') as String;
            final String bodySnippet = await newController.runJavaScriptReturningResult('document.body ? document.body.innerText.substring(0,500) : ""') as String;
            if (title.contains('Gangguan') || bodySnippet.contains('Terjadi Gangguan Pada Server') || bodySnippet.contains('500')) {
              if (mounted) {
                setState(() {
                  _lastErrorDetails = 'Server mengalami gangguan. Silakan coba lagi.';
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
                if (curUri != null && _isLoginWebPage(curUri)) _handleSessionExpired();
              });
            });
          }
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        },
        onWebResourceError: (error) {
          if (error.errorCode == -999 ||
              error.description.contains('ERR_CACHE_MISS') ||
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
          if (error.isForMainFrame ?? true) {
            if (mounted) {
              setState(() {
                _hasError = true;
                _isLoading = false;
                _lastErrorDetails = 'Gagal memuat. Periksa koneksi internet Anda.';
              });
            }
          }
        },
      ))
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
        final cm = WebViewCookieManager();
        await cm.clearCookies();
        final auth = ref.read(authProvider);
        final token = auth.accessToken;
        if (token != null && token.isNotEmpty) {
          final domain = Uri.parse(AppConfig.webBaseUrl).host;
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
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white), child: const Text('Keluar')),
        ],
      ),
    );
    if (confirmed == true && mounted) await ref.read(authProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(merchantRefreshEventProvider, (prev, next) {
      if (next > 0 && _webViewController != null) {
        debugPrint('[WebView-Merchant] Auto-refresh triggered by FCM...');
        _webViewController!.reload();
      }
    });

    ref.listen(merchantTargetUrlProvider, (prev, next) {
      if (next != null && next.isNotEmpty && _webViewController != null) {
        debugPrint('[WebView-Merchant] Loading target URL: $next');
        _webViewController!.loadRequest(Uri.parse(next));
        ref.read(merchantTargetUrlProvider.notifier).state = null;
      }
    });

    final authState = ref.watch(authProvider);
    final token = authState.accessToken;
    if (token != null && token.isNotEmpty && _loadedToken != null && _loadedToken != token) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryInitWebView());
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
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
              Container(width: 28, height: 28, decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.storefront_rounded, color: AppColors.primary, size: 16)),
              const SizedBox(width: 10),
              const Text('Mitra Merchant', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textMain)),
            ],
          ),
          actions: [
            IconButton(icon: const Icon(Icons.refresh_rounded, color: AppColors.primary), tooltip: 'Muat Ulang', onPressed: _reload, focusNode: FocusNode(skipTraversal: true)),
            IconButton(icon: const Icon(Icons.logout_rounded, color: AppColors.error), tooltip: 'Keluar', onPressed: _handleLogout, focusNode: FocusNode(skipTraversal: true)),
          ],
          bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(height: 1, color: AppColors.border.withValues(alpha: 0.5))),
        ),
        body: Stack(
          children: [
            if (!_hasError && _webViewController != null) WebViewWidget(controller: _webViewController!)
            else if (_hasError)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), shape: BoxShape.circle), child: const Icon(Icons.error_outline_rounded, size: 48, color: Colors.orange)),
                      const SizedBox(height: 16),
                      const Text('Gagal Memuat Portal Merchant', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textMain)),
                      const SizedBox(height: 8),
                      Text(_lastErrorDetails, style: const TextStyle(fontSize: 13, color: AppColors.textMuted), textAlign: TextAlign.center),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(child: ElevatedButton.icon(onPressed: _reload, icon: const Icon(Icons.refresh), label: const Text('Coba Lagi'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white))),
                          const SizedBox(width: 12),
                          Expanded(child: OutlinedButton.icon(onPressed: _hardReloadClearAll, icon: const Icon(Icons.cleaning_services), label: const Text('Reset'))),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            if (_isLoading && !_hasError)
              const Positioned(top: 0, left: 0, right: 0, child: LinearProgressIndicator(minHeight: 3, valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary))),
          ],
        ),
      ),
    );
  }
}
