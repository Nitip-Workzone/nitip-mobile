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

# WebView
-keep class com.pichillilorenzo.flutter_inappwebview.** { *; }
-keep class io.flutter.plugins.webviewflutter.** { *; }
-keep class com.example.webview_flutter_wkwebview.** { *; }

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