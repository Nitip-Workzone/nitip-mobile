# ====================
# Nitip - Proguard Rules for Release (Obfuscated + Shrink)
# ====================

# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class com.codecoffy.nitip_flutter_mobile.** { *; }

# Flutter Local Notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class io.flutter.plugins.flutterlocalnotifications.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-keep class * extends com.google.firebase.messaging.RemoteMessage { *; }
-keep class com.google.firebase.messaging.** { *; }
-keep class com.google.firebase.messaging.FirebaseMessagingService { *; }

# Geolocator & Location
-keep class com.baseflow.geolocator.** { *; }
-keep class com.baseflow.geocoding.** { *; }

# WebView — CRITICAL for merchant WebView in build-apk-wa (was causing 500 if R8 stripped channel)
# webview_flutter native side needs these kept, otherwise addJavaScriptChannel NitipLogout stops working
-keep class com.pichillilorenzo.flutter_inappwebview.** { *; }
-keep class io.flutter.plugins.webviewflutter.** { *; }
-keep class com.example.webview_flutter_wkwebview.** { *; }
-keep class androidx.webkit.** { *; }
-keep class android.webkit.** { *; }
-keep class android.webkit.WebView { *; }
-keep class android.webkit.WebViewClient { *; }
-keep class android.webkit.WebChromeClient { *; }
-keep class android.webkit.JavascriptInterface { *; }
-keepclassmembers class * {
  @android.webkit.JavascriptInterface <methods>;
}
# WebView Flutter plugin internal (flutter_inappwebview + webview_flutter_android)
-keep class com.itznotabug.flutter.usage_stats.** { *; }
-keep class io.flutter.plugins.webviewflutter.** { *; }
-keep class io.flutter.plugins.webviewflutter.WebViewFlutterPlugin { *; }
-keep class io.flutter.plugins.imagepicker.** { *; }
-keep class android.webkit.WebView { *; }
# Keep cookie manager for auth_token injection BEFORE loadRequest (fix 500)
-keep class android.webkit.CookieManager { *; }

# Device Info, URL Launcher, Local Auth, etc
-keep class com.example.device_info_plus.** { *; }
-keep class io.flutter.plugins.deviceinfo.** { *; }
-keep class io.flutter.plugins.urllauncher.** { *; }
-keep class io.flutter.plugins.localauth.** { *; }
-keep class com.example.screen_protector.** { *; }

# QR & Mobile Scanner
-keep class com.julienvignali.mobile_scanner.** { *; }
-keep class dev.steenbakker.mobile_scanner.** { *; }

# Image Picker
-keep class io.flutter.plugins.imagepicker.** { *; }

# Crypto / Path Provider
-keep class io.flutter.plugins.pathprovider.** { *; }

# ---- Do not obfuscate Flutter wrapper ----
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }

# ---- Keep parcelable / serializable for Firebase ----
-keepclassmembers class * implements android.os.Parcelable {
  public static final android.os.Parcelable$Creator *;
}

# ---- Keep native method names (JNI) ----
-keepclasseswithmembernames class * {
    native <methods>;
}

# ---- Ignore warnings ----
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**
-dontwarn io.flutter.**
-dontwarn android.**
-dontwarn androidx.**

# ---- Optimizations (safe) ----
-optimizations !code/simplification/arithmetic,!field/*,!class/merging/*
-allowaccessmodification
-keepattributes *Annotation*, InnerClasses, EnclosingMethod, Signature