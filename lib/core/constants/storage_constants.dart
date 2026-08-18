// Storage & Asset URL resolver — enforces https://upload.nihtip.com/ final base
// Backend is single source of truth that now returns https://upload.nihtip.com/,
// but this helper is defense in depth for legacy DB myqcloud.com or localhost URLs.
// ignore_for_file: unintended_html_in_doc_comment

import '../config/app_config.dart';

const String defaultAssetBaseUrl = 'https://upload.nihtip.com/';

String _getAssetBase() {
  try {
    final base = AppConfig.resolvedAssetBaseUrl;
    if (base.isNotEmpty) {
      final trimmed = base.trim();
      if (trimmed.contains('myqcloud.com')) return defaultAssetBaseUrl;
      return trimmed.endsWith('/') ? trimmed : '$trimmed/';
    }
  } catch (_) {}
  return defaultAssetBaseUrl;
}

String _extractKey(String raw) {
  if (raw.isEmpty) return '';
  String u = raw.trim();

  if (u.startsWith('http://') || u.startsWith('https://')) {
    // Legacy myqcloud.com/...?sign
    if (u.contains('myqcloud.com/')) {
      final idx = u.indexOf('myqcloud.com/');
      u = u.substring(idx + 'myqcloud.com/'.length);
    } else if (u.contains('/uploads/')) {
      final idx = u.indexOf('/uploads/');
      u = u.substring(idx + '/uploads/'.length);
    } else if (u.contains('localhost:8000') || u.contains('nitip-core:8000') || u.contains('127.0.0.1:8000') || u.contains('10.0.2.2:8000')) {
      try {
        final uri = Uri.parse(u);
        u = uri.path;
        if (u.startsWith('/uploads/')) u = u.substring('/uploads/'.length);
        if (u.startsWith('/')) u = u.substring(1);
      } catch (_) {
        // fallback
        final slash = u.indexOf('/', u.indexOf('//') + 2);
        if (slash != -1) {
          u = u.substring(slash + 1);
          if (u.startsWith('uploads/')) u = u.substring('uploads/'.length);
        }
      }
    } else {
      // Already final CDN https://upload.nihtip.com/ — keep as is earlier check handles
      // For other external (firebase, qrserver) passthrough will be handled before calling extract
    }
    // strip query
    final qIdx = u.indexOf('?');
    if (qIdx != -1) u = u.substring(0, qIdx);
  }

  // remove leading slashes and uploads/ storage/
  u = u.replaceAll(RegExp(r'^/+'), '');
  if (u.startsWith('uploads/')) u = u.substring('uploads/'.length);
  if (u.startsWith('storage/')) u = u.substring('storage/'.length);
  final q = u.indexOf('?');
  if (q != -1) u = u.substring(0, q);
  return u.trim();
}

/// resolveImageUrl — always returns final base https://upload.nihtip.com/<key>?sign or original if already final
/// If input already https://upload.nihtip.com/... returns as-is (preserves ?sign)
/// If legacy myqcloud/localhost/relative -> prepends asset base
/// External firebase/qrserver/data:/blob: passthrough
String? resolveImageUrl(String? url) {
  if (url == null) return null;
  final raw = url.trim();
  if (raw.isEmpty) return null;

  // Already final CDN
  if (raw.startsWith('https://upload.nihtip.com/') || raw.startsWith(defaultAssetBaseUrl)) {
    return raw;
  }

  // External passthrough
  if (raw.startsWith('data:') || raw.startsWith('blob:')) return raw;
  if (raw.startsWith('http://') || raw.startsWith('https://')) {
    if (raw.contains('myqcloud.com') || raw.contains('localhost:8000') || raw.contains('nitip-core:8000') || raw.contains('127.0.0.1:8000') || raw.contains('10.0.2.2:8000')) {
      final key = _extractKey(raw);
      if (key.isEmpty) return null;
      final base = _getAssetBase();
      return '$base$key';
    }
    // api.nihtip.com/uploads/... rewrite to CDN
    if (raw.contains('api.nihtip.com') && raw.contains('/uploads/')) {
      final key = _extractKey(raw);
      if (key.isEmpty) return null;
      final base = _getAssetBase();
      return '$base$key';
    }
    // If already upload.nihtip.com handled above, other https external passthrough
    if (raw.contains('upload.nihtip.com')) return raw;
    if (raw.contains('firebasestorage') || raw.contains('googleapis') || raw.contains('qrserver') || raw.contains('cloudflare')) {
      return raw;
    }
    // default passthrough for unknown external absolute
    return raw;
  }

  // Relative
  final key = _extractKey(raw);
  if (key.isEmpty) return null;
  final base = _getAssetBase();
  return '$base$key';
}

String resolveImageUrlOrEmpty(String? url) {
  return resolveImageUrl(url) ?? '';
}
