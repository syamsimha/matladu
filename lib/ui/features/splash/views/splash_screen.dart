import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/responsive/responsive_layout.dart';
import '../../../../core/widgets/matladu_logo.dart';

/// Screen 1: Splash Screen
/// Matches the official reference design with dual speech-bubble logo,
/// typography, handwritten tagline, and glowing 3D digital globe.
/// Responsive and overflow-free across all screen heights and widths.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );

    _scaleAnimation = Tween<double>(begin: 0.90, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _controller.forward();

    // Auto-advance to Home Screen (6.0s so splash can be observed and captured)
    _navigationTimer = Timer(const Duration(milliseconds: 6000), () {
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.home);
      }
    });
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppDarkColors.background : AppColors.background,
      body: Stack(
        children: [
          // Background Gradient (Deep navy/slate in dark, sky blue in light)
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? const [
                        Color(0xFF070D18),
                        Color(0xFF0B1220),
                        Color(0xFF111C2E),
                      ]
                    : const [
                        Color(0xFFE8F2FF),
                        Color(0xFFF6FAFF),
                        Color(0xFFFFFFFF),
                      ],
              ),
            ),
          ),

          // Lower Half: 3D Digital Glowing Globe Artwork
          Positioned(
            bottom: -screenSize.width * 0.35,
            left: -screenSize.width * 0.15,
            right: -screenSize.width * 0.15,
            height: screenSize.height * 0.52,
            child: CustomPaint(
              painter: _GlobePainter(),
            ),
          ),

          // Main Hero Branding & Text (Responsive Column)
          SafeArea(
            child: ResponsiveContentWrapper(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
                      child: IntrinsicHeight(
                        child: Center(
                          child: FadeTransition(
                            opacity: _fadeAnimation,
                            child: ScaleTransition(
                              scale: _scaleAnimation,
                              child: Column(
                                children: [
                                  const Spacer(flex: 3),

                                  const SizedBox(height: 20),

                                  // Dual-Bubble Soundwave Logo
                                  MatladuLogo(size: context.isCompact ? 90 : 110),

                                  const SizedBox(height: 24),

                                  // "Matladu" Title
                                  Text(
                                    AppStrings.appName,
                                    style: AppTypography.displayLarge.copyWith(
                                      fontSize: context.isCompact ? 28 : 34,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.6,
                                      color: isDark ? AppDarkColors.textPrimary : AppColors.textPrimary,
                                    ),
                                  ),

                                  const SizedBox(height: 8),

                                  // "Speak • Translate • Connect" Tagline
                                  Text(
                                    AppStrings.tagline,
                                    style: AppTypography.tagline.copyWith(
                                      fontSize: 14,
                                      color: isDark ? AppDarkColors.textSecondary : AppColors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),

                                  const SizedBox(height: 28),

                                  // Handwritten / Italic Mission Subtitle
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 40),
                                    child: Text(
                                      AppStrings.splashSubtext,
                                      style: AppTypography.handwritten.copyWith(
                                        fontSize: 15,
                                        color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF334155),
                                        height: 1.35,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),

                                  const Spacer(flex: 4),

                                  const SizedBox(height: 24),

                                  // Initializing... indicator floating over top of the globe
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 34),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? const Color(0xFF17243A).withValues(alpha: 0.85)
                                            : Colors.white.withValues(alpha: 0.18),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: isDark
                                              ? const Color(0xFF4F8CFF).withValues(alpha: 0.5)
                                              : Colors.white.withValues(alpha: 0.35),
                                          width: 1.0,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: isDark
                                                ? const Color(0xFF000000).withValues(alpha: 0.4)
                                                : const Color(0xFF0284C7).withValues(alpha: 0.25),
                                            blurRadius: 10,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        AppStrings.initializing,
                                        style: TextStyle(
                                          color: isDark ? AppDarkColors.textPrimary : Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlobePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final Offset center = Offset(w / 2, h * 0.70);
    final double radius = w * 0.58;

    // Outer glow aura
    final Paint glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF0284C7).withValues(alpha: 0.55),
          const Color(0xFF0EA5E9).withValues(alpha: 0.20),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 1.25));
    canvas.drawCircle(center, radius * 1.25, glowPaint);

    // Deep digital blue globe body
    final Paint spherePaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(0, -0.2),
        colors: [
          Color(0xFF38BDF8),
          Color(0xFF0284C7),
          Color(0xFF0369A1),
          Color(0xFF0F172A),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, spherePaint);

    // Grid lines (Latitude & Longitude)
    final Paint gridPaint = Paint()
      ..color = const Color(0xFFE0F2FE).withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (int i = 1; i <= 4; i++) {
      final double latRadius = radius * (i / 4.5);
      canvas.drawOval(
        Rect.fromCenter(center: center, width: radius * 1.9, height: latRadius * 1.2),
        gridPaint,
      );
    }

    // Longitude arcs
    for (int i = 1; i <= 3; i++) {
      final double lonWidth = radius * (i / 2.8);
      canvas.drawOval(
        Rect.fromCenter(center: center, width: lonWidth, height: radius * 1.95),
        gridPaint,
      );
    }

    // Glowing network nodes and connection pins
    final Paint nodePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final Paint nodeGlow = Paint()
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.8)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final List<Offset> nodes = [
      Offset(center.dx - radius * 0.40, center.dy - radius * 0.35),
      Offset(center.dx - radius * 0.10, center.dy - radius * 0.55),
      Offset(center.dx + radius * 0.35, center.dy - radius * 0.40),
      Offset(center.dx + radius * 0.05, center.dy - radius * 0.20),
      Offset(center.dx - radius * 0.25, center.dy - radius * 0.10),
    ];

    for (final pt in nodes) {
      canvas.drawCircle(pt, 5, nodeGlow);
      canvas.drawCircle(pt, 2.5, nodePaint);

      // Draw pin marker
      final Path pin = Path();
      pin.moveTo(pt.dx, pt.dy);
      pin.lineTo(pt.dx - 4, pt.dy - 10);
      pin.arcToPoint(
        Offset(pt.dx + 4, pt.dy - 10),
        radius: const Radius.circular(4),
      );
      pin.close();
      canvas.drawPath(pin, Paint()..color = const Color(0xFF0284C7));
      canvas.drawCircle(Offset(pt.dx, pt.dy - 10), 2, nodePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
