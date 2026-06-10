class AppConfig {
  /// Base URL untuk API Backend.
  /// Diambil dari --dart-define-from-file=env.json atau --dart-define=BASE_URL=...
  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'http://localhost:8000/api/v1/',
  );

  /// API Key untuk autentikasi client (dapat dari `make register-client`)
  static const String apiKey = String.fromEnvironment(
    'API_KEY',
    defaultValue: '',
  );

  /// API Secret untuk HMAC signature (dapat dari `make register-client`)
  static const String apiSecret = String.fromEnvironment(
    'API_SECRET',
    defaultValue: '',
  );

  /// Cek apakah API credentials sudah dikonfigurasi
  static bool get hasApiCredentials => apiKey.isNotEmpty && apiSecret.isNotEmpty;

  static String get webBaseUrl {
    try {
      final uri = Uri.parse(baseUrl);
      // Map API host to web host (port 3000)
      return '${uri.scheme}://${uri.host}:3000';
    } catch (_) {
      return 'http://localhost:3000';
    }
  }

  static String get wsBaseUrl => baseUrl.replaceAll('http://', 'ws://').replaceAll('https://', 'wss://');

  /// URL untuk Self-Hosted Nominatim (port 8081)
  static const String nominatimUrl = String.fromEnvironment(
    'NOMINATIM_URL',
    defaultValue: 'http://10.0.2.2:8081', // Nominatim port
  );

  /// URL untuk Self-Hosted Tile Server (TileServer-GL port 8080)
  static const String tileServerUrl = String.fromEnvironment(
    'TILE_SERVER_URL',
    defaultValue: 'http://10.0.2.2:8082/styles/positron/{z}/{x}/{y}.png',
  );

  /// URL untuk Self-Hosted Routing (OSRM port 5000)
  static const String routingUrl = String.fromEnvironment(
    'ROUTING_URL',
    defaultValue: 'http://10.0.2.2:5000',
  );

  /// Environment name (dev, staging, prod)
  static const String env = String.fromEnvironment(
    'ENV',
    defaultValue: 'dev',
  );

  static bool get isDev => env == 'dev';

  /// Toggle untuk validasi KYC di sisi klien
  static bool isKycRequired = false;
}
