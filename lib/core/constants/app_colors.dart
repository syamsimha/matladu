import 'package:flutter/material.dart';

/// App color palette matching the official Matladu AI 8-screen reference:
/// Light sky-blue & white aesthetic, vivid cobalt-blue (#1D61F2) primary branding,
/// purple-violet bubble accents, mint-green translation states, and soft card tints.
class AppColors {
  AppColors._();

  // Primary Branding (Cobalt / Royal Blue & Purple)
  static const Color primary = Color(0xFF1D61F2); // Vibrant cobalt blue from buttons & logo
  static const Color primaryDark = Color(0xFF1548B8);
  static const Color primaryLight = Color(0xFF3B82F6);
  static const Color logoBlue = Color(0xFF0EA5E9); // Cyan-blue left speech bubble
  static const Color logoPurple = Color(0xFFA855F7); // Violet-purple right speech bubble

  // Backgrounds & Surfaces
  static const Color background = Color(0xFFF6F9FD); // Soft sky-blue tinted light canvas
  static const Color surface = Color(0xFFFFFFFF); // Crisp white cards
  static const Color cardShadow = Color(0x0C1E293B); // Ultra-soft shadow (5% opacity)

  // Specific Card Tint Backgrounds from Reference
  static const Color cardLightBlue = Color(0xFFF0F6FF); // Original English speech card & info banners
  static const Color cardLightGreen = Color(0xFFF0FDF4); // Translated Telugu card & Auto Switch card
  static const Color cardLightYellow = Color(0xFFFEFCE8); // Lightning alert banner
  static const Color cardLightPurple = Color(0xFFF5F3FF); // Try saying card
  static const Color cardLightRed = Color(0xFFFEF2F2); // Reset settings button background

  // State & Badges
  static const Color statusGreen = Color(0xFF16A34A); // Online • Ready & Complete badges
  static const Color statusGreenBg = Color(0xFFDCFCE7); // Soft green pill background
  static const Color statusYellow = Color(0xFFEAB308); // Lightning bolt & VIP Crown
  static const Color crownGold = Color(0xFFF59E0B); // VIP Gold crown
  static const Color errorRed = Color(0xFFEF4444); // Red reset & delete actions

  // Borders & Dividers
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color borderSubtle = Color(0xFFEDF2F7);

  // Typography
  static const Color textPrimary = Color(0xFF0F172A); // Slate 900
  static const Color textSecondary = Color(0xFF475569); // Slate 600
  static const Color textMuted = Color(0xFF94A3B8); // Slate 400
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textGreenDark = Color(0xFF14532D); // Telugu text & complete text

  // Mic Concentric Ripple Rings
  static const Color micRipple1 = Color(0x3338BDF8); // Outer soft ring
  static const Color micRipple2 = Color(0x550EA5E9); // Middle ring
  static const Color micRipple3 = Color(0x882563EB); // Inner ring

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF2563EB),
      Color(0xFF1D4ED8),
    ],
  );

  static const LinearGradient logoBubbleGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF0284C7),
      Color(0xFF0EA5E9),
    ],
  );

  static const LinearGradient purpleBubbleGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF9333EA),
      Color(0xFFA855F7),
    ],
  );

  static const LinearGradient splashGlobeGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0x000284C7),
      Color(0x220284C7),
      Color(0x660369A1),
      Color(0xFF075985),
    ],
  );
}
