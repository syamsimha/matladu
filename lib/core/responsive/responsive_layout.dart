import 'package:flutter/material.dart';

/// Screen size breakpoints matching Android and iOS device tiers:
/// - Compact phones (e.g. iPhone SE, Android 320-360dp)
/// - Standard phones (e.g. Pixel 7, iPhone 14, 375-414dp)
/// - Large phones / phablets (e.g. Pro Max, Ultra, 415-599dp)
/// - Tablets & iPads (600dp+)
class AppBreakpoints {
  AppBreakpoints._();

  static const double compactWidth = 360.0;
  static const double tabletWidth = 600.0;
  static const double largeTabletWidth = 900.0;

  static const double shortScreenHeight = 680.0;

  // Maximum content width on tablets so cards maintain the reference proportions
  static const double maxContentWidth = 560.0;
}

/// Extension on BuildContext providing reactive device metrics and responsive helpers.
extension ResponsiveContext on BuildContext {
  Size get screenSize => MediaQuery.sizeOf(this);
  double get screenWidth => screenSize.width;
  double get screenHeight => screenSize.height;

  bool get isCompact => screenWidth < AppBreakpoints.compactWidth || screenHeight < AppBreakpoints.shortScreenHeight;
  bool get isTablet => screenWidth >= AppBreakpoints.tabletWidth;
  bool get isLandscape => screenWidth > screenHeight;

  /// Returns value based on current device form factor
  T responsive<T>({
    required T standard,
    T? compact,
    T? tablet,
  }) {
    if (isTablet && tablet != null) return tablet;
    if (isCompact && compact != null) return compact;
    return standard;
  }

  /// Clamped text scaler to protect capsule pills and badges from extreme accessibility scales
  TextScaler get clampedTextScaler => MediaQuery.textScalerOf(this).clamp(
        minScaleFactor: 0.85,
        maxScaleFactor: 1.30,
      );
}

/// Responsive content container that centers content on tablets/iPads with a max-width constraint,
/// preventing cards and layouts from stretching excessively on large screens.
class ResponsiveContentWrapper extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  const ResponsiveContentWrapper({
    super.key,
    required this.child,
    this.maxWidth = AppBreakpoints.maxContentWidth,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = child;
    if (padding != null) {
      content = Padding(padding: padding!, child: content);
    }

    if (context.isTablet) {
      return Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: content,
        ),
      );
    }

    return content;
  }
}

