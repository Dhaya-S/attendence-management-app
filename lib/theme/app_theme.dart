import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Central design system — Premium SaaS aesthetic
class AppTheme {
  AppTheme._();

  // ─── Colors (Purple/Indigo primary — matching mockups) ────────────────
  static const Color primary = Color(0xFF5C5CFF);
  static const Color primaryLight = Color(0xFF8B8BFF);
  static const Color primaryDark = Color(0xFF3A3AE5);
  static const Color primarySurface = Color(0xFFF0F1FF);

  static const Color surface = Color(0xFFF7F8FC);
  static const Color surfaceVariant = Color(0xFFF0F1FF);
  static const Color cardBackground = Colors.white;

  static const Color success = Color(0xFF22C55E);
  static const Color successLight = Color(0xFFDCFCE7);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color danger = Color(0xFFEF4444);
  static const Color dangerLight = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFFDBEAFE);

  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF4B5563);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color textHint = Color(0xFF9CA3AF);
  static const Color divider = Color(0xFFE5E7EB);
  static const Color badgeMuted = Color(0xFFF3F4F6);
  static const Color badgeMutedText = Color(0xFF4B5563);

  // New discovery for mockups
  static const Color accentBlue = Color(0xFFE0E7FF);
  static const Color accentOrange = Color(0xFFFFF7ED);
  static const Color accentGreen = Color(0xFFF0FDF4);
  static const Color accentRed = Color(0xFFFEF2F2);

  static const Color presenceToday = Color(0xFF5C5CFF);
  static const Color lateArrival = Color(0xFFF59E0B);
  static const Color leaveStatus = Color(0xFFEF4444);
  static const Color absentStatus = Color(0xFF6B7280);

  // ─── Border Radius (Clean, professional) ──────────────────────────────
  static const double radiusXL = 16.0;
  static const double radiusLG = 14.0;
  static const double radiusMD = 12.0;
  static const double radiusSM = 10.0;
  static const double radiusXS = 6.0;

  // Aliases for backward compat
  static const double radiusCard = 16.0;
  static const double radiusButton = 12.0;
  static const double radiusInput = 10.0;
  static const double radiusSmall = 6.0;

  static BorderRadius get cardRadius => BorderRadius.circular(radiusCard);
  static BorderRadius get buttonRadius => BorderRadius.circular(radiusButton);
  static BorderRadius get inputRadius => BorderRadius.circular(radiusInput);
  static BorderRadius get smallRadius => BorderRadius.circular(radiusSmall);
  static BorderRadius get xlRadius => BorderRadius.circular(radiusXL);

  // ─── Padding ──────────────────────────────────────────────────────────
  static const double paddingScreen = 16;
  static const double paddingCard = 14;
  static const double paddingCardLarge = 16;

  static const EdgeInsets screenPadding = EdgeInsets.all(paddingScreen);
  static const EdgeInsets cardPadding = EdgeInsets.all(paddingCard);
  static const EdgeInsets cardPaddingLarge = EdgeInsets.all(paddingCardLarge);

  // ─── Card style ───────────────────────────────────────────────────────
  static ShapeBorder get cardShape => RoundedRectangleBorder(
        borderRadius: cardRadius,
      );

  static BoxDecoration cardDecoration({
    Color? color,
    double elevation = 2,
  }) {
    return BoxDecoration(
      color: color ?? cardBackground,
      borderRadius: cardRadius,
      border: Border.all(color: divider.withOpacity(0.5), width: 1),
    );
  }

  // ─── Gradients ────────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ─── Shadows (disabled for clean flat look) ──────────────────────────
  static List<BoxShadow> get softShadow => [];
  static List<BoxShadow> get mediumShadow => [];

  // ─── Typography (Clean, mobile-optimized) ─────────────────────────────
  static TextStyle get h1 => GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        letterSpacing: -0.3,
      );

  static TextStyle get h2 => GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: textPrimary,
        letterSpacing: -0.2,
      );

  static TextStyle get h3 => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      );

  static TextStyle get bodyLarge => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: textSecondary,
      );

  static TextStyle get bodyMedium => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: textSecondary,
      );

  static TextStyle get bodySmall => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: textMuted,
      );

  static TextStyle get label => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: textMuted,
        letterSpacing: 0.3,
      );
}
