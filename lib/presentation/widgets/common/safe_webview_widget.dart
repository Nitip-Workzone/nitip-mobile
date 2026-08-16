import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

class SafeWebViewWidget extends StatelessWidget {
  final WebViewController controller;
  final Set<Factory<OneSequenceGestureRecognizer>> gestureRecognizers;

  const SafeWebViewWidget({
    super.key, 
    required this.controller,
    this.gestureRecognizers = const <Factory<OneSequenceGestureRecognizer>>{},
  });

  @override
  Widget build(BuildContext context) {
    return WebViewWidget.fromPlatformCreationParams(
      key: key ?? ValueKey(controller),
      params: controller.platform is AndroidWebViewController
          ? AndroidWebViewWidgetCreationParams(
              controller: controller.platform,
              displayWithHybridComposition: true,
              gestureRecognizers: gestureRecognizers,
            )
          : PlatformWebViewWidgetCreationParams(
              controller: controller.platform,
              gestureRecognizers: gestureRecognizers,
            ),
    );
  }
}

