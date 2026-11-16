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
  static const Color secondary = logoBlue;
  static const Color purpleAccent = logoPurple;

  // Backgrounds & Surfaces
  static const Color background = Color(0xFFF6F9FD); // Soft sky-blue tinted light canvas
  static const Color surface = Color(0xFFFFFFFF); // Crisp white cards
  static const Color surfaceVariant = cardLightBlue; // Soft blue surface variant
  static const Color cardShadow = Color(0x0C1E293B); // Ultra-soft shadow (5% opacity)

  // Specific Card Tint Backgrounds from Reference
  static const Color cardLightBlue = Color(0xFFF0F6FF); // Original English speech card & info banners
  static const Color cardLightGreen = Color(0xFFF0FDF4); // Translated Telugu card & Auto Switch card
  static const Color cardLightYellow = Color(0xFFFEFCE8); // Lightning alert banner
  static const Color cardLightPurple = Color(0xFFF5F3FF); // Try saying card
  static const Color cardLightRed = Color(0xFFFEF2F2); // Reset settings button background

  // State & Badges
  static const Color statusGreen = Color(0xFF16A34A); // Online • Ready & Complete badges
  static const Color onlineBadge = statusGreen;
  static const Color statusGreenBg = Color(0xFFDCFCE7); // Soft green pill background
  static const Color statusYellow = Color(0xFFEAB308); // Lightning bolt & VIP Crown
  static const Color crownGold = Color(0xFFF59E0B); // VIP Gold crown
  static const Color errorRed = Color(0xFFEF4444); // Red reset & delete actions

  // Borders & Dividers
  static const Color border = borderLight;
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

/// Rich, polished dark theme palette adhering to deep navy/slate specifications:
/// Background (#0B1220), Card surfaces (#111C2E), Secondary (#17243A),
/// Primary text (#F3F7FF), Secondary text (#A8B6CC), Vibrant blue accents (#4F8CFF),
/// Elegant violet accents (#A78BFA), and adapted mint/green tones.
class AppDarkColors {
  AppDarkColors._();

  // Backgrounds & Surfaces
  static const Color background = Color(0xFF0B1220); // Deep navy/slate
  static const Color surface = Color(0xFF111C2E); // Rich dark blue cards
  static const Color surfaceSecondary = Color(0xFF17243A); // Secondary container
  static const Color surfaceVariant = Color(0xFF1E2D44);
  static const Color cardShadow = Color(0x33000000); // 20% black shadow

  // Typography
  static const Color textPrimary = Color(0xFFF3F7FF); // Soft white
  static const Color textSecondary = Color(0xFFA8B6CC); // Muted blue-grey
  static const Color textMuted = Color(0xFF64748B); // Slate 500
  static const Color textWhite = Color(0xFFFFFFFF);

  // Accents & Buttons
  static const Color primary = Color(0xFF4F8CFF); // Vibrant blue
  static const Color primaryDark = Color(0xFF2563EB);
  static const Color primaryLight = Color(0xFF60A5FA);
  static const Color secondary = Color(0xFFA78BFA); // Elegant violet
  static const Color accentViolet = Color(0xFFA78BFA);
  static const Color purpleAccent = Color(0xFFA78BFA);

  // Card Tints in Dark Mode
  static const Color cardLightBlue = Color(0xFF132238); // Deep blue tint
  static const Color cardLightGreen = Color(0xFF0D281E); // Deep emerald navy tint
  static const Color cardLightYellow = Color(0xFF231F0A); // Deep amber tint
  static const Color cardLightPurple = Color(0xFF1F1635); // Deep violet tint
  static const Color cardLightRed = Color(0xFF2B1317); // Deep crimson tint

  // Status & Badges
  static const Color statusGreen = Color(0xFF34D399); // Adapted mint/green
  static const Color statusGreenBg = Color(0xFF062E1F); // Soft dark green container
  static const Color statusGreenBorder = Color(0xFF065F46);
  static const Color statusYellow = Color(0xFFFBBF24);
  static const Color errorRed = Color(0xFFF87171);

  // Borders & Dividers
  static const Color border = Color(0xFF223249);
  static const Color borderLight = Color(0xFF1E293B);
  static const Color borderSubtle = Color(0xFF17243A);
}
