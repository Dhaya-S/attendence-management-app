import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Central design system — Premium SaaS aesthetic
class AppTheme {
  AppTheme._();

  // ─── Colors (Purple/Indigo primary — matching mockups) ────────────────
  static const Color primary = Color(0xFF5B67F5);
  static const Color primaryLight = Color(0xFF8B93FF);
  static const Color primaryDark = Color(0xFF3D4AE5);
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

  static const Color presenceToday = Color(0xFF5B67F5);
  static const Color lateArrival = Color(0xFFF59E0B);
  static const Color leaveStatus = Color(0xFFEF4444);
  static const Color absentStatus = Color(0xFF6B7280);

  // ─── Border Radius (Rounded UI: 16–24) ────────────────────────────────
  static const double radiusXL = 24.0;
  static const double radiusLG = 20.0;
  static const double radiusMD = 16.0;
  static const double radiusSM = 12.0;
  static const double radiusXS = 8.0;

  // Aliases for backward compat
  static const double radiusCard = 20.0;
  static const double radiusButton = 16.0;
  static const double radiusInput = 14.0;
  static const double radiusSmall = 8.0;

  static BorderRadius get cardRadius => BorderRadius.circular(radiusCard);
  static BorderRadius get buttonRadius => BorderRadius.circular(radiusButton);
  static BorderRadius get inputRadius => BorderRadius.circular(radiusInput);
  static BorderRadius get smallRadius => BorderRadius.circular(radiusSmall);
  static BorderRadius get xlRadius => BorderRadius.circular(radiusXL);

  // ─── Padding ──────────────────────────────────────────────────────────
  static const double paddingScreen = 20;
  static const double paddingCard = 16;
  static const double paddingCardLarge = 20;

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
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  // ─── Gradients ────────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ─── Shadows ──────────────────────────────────────────────────────────
  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get mediumShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];

  // ─── Typography (Premium SaaS) ────────────────────────────────────────
  static TextStyle get h1 => GoogleFonts.outfit(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        color: textPrimary,
      );

  static TextStyle get h2 => GoogleFonts.outfit(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: textPrimary,
      );

  static TextStyle get h3 => GoogleFonts.outfit(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      );

  static TextStyle get bodyLarge => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: textSecondary,
      );

  static TextStyle get bodyMedium => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: textSecondary,
      );

  static TextStyle get bodySmall => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: textMuted,
      );

  static TextStyle get label => GoogleFonts.outfit(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: textMuted,
        letterSpacing: 0.5,
      );
}
