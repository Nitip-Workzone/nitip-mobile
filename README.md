# 📱 Nitip Mobile — Flutter App

Aplikasi mobile **Nitip** untuk Runner, dibangun dengan **Flutter** dan mengikuti prinsip **Clean Architecture** dengan pattern **BLoC/Riverpod**.

Platform jastip (titip beli & titip kirim) yang menghubungkan Penitip dengan Runner terdekat secara real-time.

---

## 📦 Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter 3.x + Dart |
| State Management | Riverpod |
| Navigation | GoRouter |
| HTTP Client | Dio |
| Local Storage | Flutter Secure Storage |
| Push Notification | Firebase Cloud Messaging (FCM) |
| Location | Geolocator + Geocoding |
| Biometric | Local Auth |
| Screen Security | Screen Protector |
| Image | Cached Network Image + Image Picker |

---

## 🏗️ Architecture

Mengikuti **Clean Architecture** dengan 3 layer utama:

```
lib/
├── core/
│   ├── config/app_config.dart        # Environment configuration
│   ├── theme/                        # App theme & colors
│   └── utils/                        # Utility functions
├── data/
│   ├── network/api_client.dart       # Dio HTTP client with interceptors
│   └── repositories/                 # Repository implementations
├── domain/
│   ├── models/                       # Data models (User, Order, Trip, etc.)
│   └── repositories/                 # Repository interfaces (abstract)
├── presentation/
│   ├── pages/
│   │   ├── auth/                     # Login, Register, PIN setup/change
│   │   ├── dashboard/                # Main dashboard with tabs
│   │   │   └── tabs/                 # Home, Trips, Wallet, Profile
│   │   ├── orders/                   # Order flow (create, detail, QR scanner)
│   │   ├── wallet/                   # Wallet, top-up, withdrawal
│   │   └── kyc/                      # KYC verification
│   ├── providers/                    # Riverpod state providers
│   └── widgets/                      # Reusable UI components
│       ├── common/                   # Shared widgets
│       └── wallet/                   # Wallet-specific widgets
├── firebase_options.dart             # Firebase configuration
└── main.dart                         # App entry point
```

---

## ⚡ Quick Start

```bash
# 1. Clone & setup
git clone git@github.com:Nitip-Workzone/nitip-mobile.git
cd nitip-mobile

# 2. Install dependencies
flutter pub get

# 3. Setup Firebase (requires google-services.json for Android)
# Place google-services.json in android/app/

# 4. Configure API endpoint
# Edit lib/core/config/app_config.dart

# 5. Run the app
flutter run
```

### Prerequisites
- Flutter SDK >= 3.x
- Dart SDK >= 3.x
- Android Studio / Xcode (for emulator/device)
- Firebase project configured

---

## 🔑 Key Features

### Authentication
- Email & password login with device binding
- JWT token rotation with auto-refresh
- Biometric authentication (FaceID / Fingerprint)
- PIN-based transaction security
- Screenshot protection on sensitive screens

### Dashboard
- **Home Tab** — Active orders, nearby runners, quick actions
- **Trips Tab** — My trips, create new trip
- **Wallet Tab** — Balance, top-up QRIS, withdrawal, transactions
- **Profile Tab** — Edit profile, security settings, KYC

### Order Flow
- **Titip Beli** — Request items to be purchased by runner
- **Titip Kirim** — Request package delivery
- QR code scanning for order completion
- Photo proof of delivery
- Real-time order status tracking

### Wallet
- Balance display & transaction history
- Top-up via QRIS (mock integration available)
- Withdrawal to bank accounts
- PIN-protected transactions

### Security & Privacy
- PIN setup / change with backend verification
- PIN lockout after 5 failed attempts
- Device session management
- Privacy policy & data protection info

### Real-time
- WebSocket chat with counterpart
- Push notifications (order updates, chat, system)
- Location-based runner matching

### KYC
- Identity verification with photo upload
- Status tracking (pending / approved / rejected)

---

## 🔧 Configuration

### API Endpoint

Edit `lib/core/config/app_config.dart`:

```dart
class AppConfig {
  static const String baseUrl = 'http://10.0.2.2:3000/api/v1'; // Android emulator
  // static const String baseUrl = 'http://localhost:3000/api/v1'; // iOS simulator
}
```

### Firebase

1. Create Firebase project
2. Add Android app → download `google-services.json` → place in `android/app/`
3. Add iOS app → download `GoogleService-Info.plist` → place in `ios/Runner/`
4. Run `flutterfire configure` to generate `firebase_options.dart`

---

## 📂 Key Packages

```yaml
dependencies:
  flutter_riverpod: ^2.x       # State management
  go_router: ^14.x             # Declarative routing
  dio: ^5.x                    # HTTP client
  flutter_secure_storage: ^9.x # Secure local storage
  firebase_messaging: ^15.x    # Push notifications
  geolocator: ^13.x            # GPS location
  local_auth: ^2.x             # Biometric auth
  screen_protector: ^1.x       # Screenshot prevention
  cached_network_image: ^3.x   # Image caching
  device_info_plus: ^10.x      # Device information
```

---

## 🏃 Running

```bash
# Development
flutter run

# Build APK
flutter build apk --release

# Build iOS
flutter build ios --release

# Run tests
flutter test

# Analyze code
flutter analyze
```

---

## 📄 License

Proprietary — © 2026 Nitip Workzone. All rights reserved.