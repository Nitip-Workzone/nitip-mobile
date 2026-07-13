# Flutter Local Notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class io.flutter.plugins.flutterlocalnotifications.** { *; }

# Keep notification-related classes
-keep class * extends com.google.firebase.messaging.RemoteMessage { *; }