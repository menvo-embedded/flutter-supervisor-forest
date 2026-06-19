import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Light Mode Colors (Slate/Grayscale System with Forest Green Accent)
  static const Color primary       = Color(0xFF107C41); // Forest Green Accent
  static const Color primaryDark   = Color(0xFF0A5C30); // Darker Forest Green Accent
  static const Color primaryLight  = Color(0xFFE8F5EE); // Soft Forest Green background tint
  static const Color primaryMid    = Color(0xFF1A9E54);
  static const Color accent        = Color(0xFF107C41);
  static const Color amber         = Color(0xFFF59E0B);
  static const Color red           = Color(0xFFEF4444);
  static const Color blue          = Color(0xFF3B82F6);
  static const Color bg            = Color(0xFFF8FAFC); // Slate 50
  static const Color surface       = Color(0xFFFFFFFF);
  static const Color surfaceGrey   = Color(0xFFF1F5F9); // Slate 100
  static const Color textPrimary   = Color(0xFF0F172A); // Slate 900
  static const Color textSecondary = Color(0xFF64748B); // Slate 500
  static const Color textHint      = Color(0xFF94A3B8); // Slate 400
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color borderDefault = Color(0xFFE2E8F0); // Slate 200
  static const Color borderFocus   = Color(0xFF107C41);
  static const Color statusActive  = Color(0xFF107C41);
  static const Color statusDraft   = Color(0xFFF59E0B);
  static const Color statusLocked  = Color(0xFFEF4444);

  // Dark Mode Colors (Deep Slate System)
  static const Color bgDark            = Color(0xFF090D16); // Slate 950
  static const Color surfaceDark       = Color(0xFF0F172A); // Slate 900
  static const Color surfaceGreyDark   = Color(0xFF1E293B); // Slate 800
  static const Color textPrimaryDark   = Color(0xFFF1F5F9); // Slate 100
  static const Color textSecondaryDark = Color(0xFF94A3B8); // Slate 400
  static const Color textHintDark      = Color(0xFF64748B); // Slate 500
  static const Color borderDefaultDark = Color(0xFF1E293B); // Slate 800

  // Dynamic getters
  static Color getBg(bool isDark) => isDark ? bgDark : bg;
  static Color getSurface(bool isDark) => isDark ? surfaceDark : surface;
  static Color getSurfaceGrey(bool isDark) => isDark ? surfaceGreyDark : surfaceGrey;
  static Color getTextPrimary(bool isDark) => isDark ? textPrimaryDark : textPrimary;
  static Color getTextSecondary(bool isDark) => isDark ? textSecondaryDark : textSecondary;
  static Color getBorder(bool isDark) => isDark ? borderDefaultDark : borderDefault;

  static const LinearGradient forestGradient = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF107C41), Color(0xFF0A5C30)], // Original Forest Green Gradient
  );

  static const LinearGradient forestGradientDark = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF0C4625), Color(0xFF062C16)], // Original Dark Forest Green Gradient
  );
}

