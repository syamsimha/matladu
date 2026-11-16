import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_strings.dart';
import '../constants/app_typography.dart';

/// The official Matladu AI dual speech-bubble logo:
/// Left / foreground Cyan-Blue bubble with 5 vertical white soundwave bars,
/// overlapping with a Right / background Purple-Violet bubble.
class MatladuLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final bool showTagline;

  const MatladuLogo({
    super.key,
    this.size = 80.0,
    this.showText = false,
    this.showTagline = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Widget logoIcon = SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _MatladuLogoPainter(),
      ),
    );

    if (!showText) return logoIcon;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        logoIcon,
        const SizedBox(height: 16),
        Text(
          AppStrings.appName,
          style: AppTypography.displayLarge.copyWith(
            color: isDark ? AppDarkColors.textPrimary : AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (showTagline) ...[
          const SizedBox(height: 6),
          Text(
            AppStrings.tagline,
            style: AppTypography.tagline.copyWith(
              color: isDark ? AppDarkColors.textSecondary : AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

class _MatladuLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // 1. Draw Purple Background Bubble (Right, slightly behind)
    final Paint purplePaint = Paint()
      ..shader = AppColors.purpleBubbleGradient.createShader(
        Rect.fromLTWH(w * 0.45, h * 0.15, w * 0.52, h * 0.65),
      )
      ..style = PaintingStyle.fill;

    final Path purplePath = Path();
    final Rect purpleRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.45, h * 0.12, w * 0.50, h * 0.60),
      Radius.circular(w * 0.22),
    ).outerRect;

    // Rounded body
    purplePath.addRRect(
      RRect.fromRectAndRadius(purpleRect, Radius.circular(w * 0.22)),
    );
    // Bubble pointer down-right
    purplePath.moveTo(w * 0.70, h * 0.65);
    purplePath.lineTo(w * 0.88, h * 0.80);
    purplePath.lineTo(w * 0.80, h * 0.55);
    purplePath.close();

    canvas.drawPath(purplePath, purplePaint);

    // 2. Draw Cyan-Blue Foreground Bubble (Left)
    final Paint bluePaint = Paint()
      ..shader = AppColors.logoBubbleGradient.createShader(
        Rect.fromLTWH(0, h * 0.05, w * 0.72, h * 0.72),
      )
      ..style = PaintingStyle.fill;

    // Shadow behind blue bubble
    final Path blueShadowPath = Path();
    final Rect blueRect = Rect.fromLTWH(w * 0.04, h * 0.05, w * 0.66, h * 0.62);
    blueShadowPath.addRRect(
      RRect.fromRectAndRadius(blueRect, Radius.circular(w * 0.24)),
    );
    blueShadowPath.moveTo(w * 0.25, h * 0.62);
    blueShadowPath.lineTo(w * 0.12, h * 0.82);
    blueShadowPath.lineTo(w * 0.38, h * 0.64);
    blueShadowPath.close();

    canvas.drawShadow(blueShadowPath, Colors.black.withValues(alpha: 0.18), 6, true);
    canvas.drawPath(blueShadowPath, bluePaint);

    // 3. Draw 5 White Soundwave Bars inside the Blue Bubble
    final Paint wavePaint = Paint()
      ..color = Colors.white
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final double barWidth = w * 0.042;
    wavePaint.strokeWidth = barWidth;

    final double startX = w * 0.20;
    final double spacing = w * 0.082;
    final double centerY = h * 0.36;

    // Wave bar heights relative to bubble height
    final List<double> barHeights = [
      h * 0.14, // Bar 1
      h * 0.26, // Bar 2
      h * 0.34, // Bar 3 (Tallest center)
      h * 0.24, // Bar 4
      h * 0.13, // Bar 5
    ];

    for (int i = 0; i < 5; i++) {
      final double x = startX + (i * spacing);
      final double halfH = barHeights[i] / 2;
      canvas.drawLine(
        Offset(x, centerY - halfH),
        Offset(x, centerY + halfH),
        wavePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

