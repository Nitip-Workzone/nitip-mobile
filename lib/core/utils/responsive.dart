import 'package:flutter/material.dart';

class Responsive extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const Responsive({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 600;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= 600 &&
      MediaQuery.of(context).size.width < 1100;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1100;

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    if (size.width >= 1100 && desktop != null) {
      return desktop!;
    } else if (size.width >= 600 && tablet != null) {
      return tablet!;
    } else {
      return mobile;
    }
  }
}

/// Helper to wrap content with a maximum width, centered.
/// Ideal for tablet support where you don't want the UI to stretch too wide.
class MaxWidthWrapper extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final Color? backgroundColor;

  const MaxWidthWrapper({
    super.key,
    required this.child,
    this.maxWidth = 600.0,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    
    // Determine the width that the child should "see"
    final constrainedWidth = screenWidth > maxWidth ? maxWidth : screenWidth;

    return Container(
      color: backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: MediaQuery(
            // We override the MediaQuery data so that widgets inside (like the Navbar)
            // see the constrained width instead of the full screen width.
            data: mediaQuery.copyWith(
              size: Size(constrainedWidth, mediaQuery.size.height),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

