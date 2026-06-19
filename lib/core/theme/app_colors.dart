import 'package:flutter/material.dart';
class AppColors {
  AppColors._();
  static const Color primary       = Color(0xFF107C41);
  static const Color primaryDark   = Color(0xFF0A5C30);
  static const Color primaryLight  = Color(0xFFE8F5EE);
  static const Color primaryMid    = Color(0xFF1A9E54);
  static const Color accent        = Color(0xFF34D399);
  static const Color amber         = Color(0xFFF59E0B);
  static const Color red           = Color(0xFFDC2626);
  static const Color blue          = Color(0xFF2563EB);
  static const Color bg            = Color(0xFFF4F7F5);
  static const Color surface       = Color(0xFFFFFFFF);
  static const Color surfaceGrey   = Color(0xFFF1F5F2);
  static const Color textPrimary   = Color(0xFF0F2418);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textHint      = Color(0xFF9CA3AF);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color borderDefault = Color(0xFFD1D5DB);
  static const Color borderFocus   = Color(0xFF107C41);
  static const Color statusActive  = Color(0xFF10B981);
  static const Color statusDraft   = Color(0xFFF59E0B);
  static const Color statusLocked  = Color(0xFFDC2626);
  static const LinearGradient forestGradient = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF107C41), Color(0xFF0A5C30)],
  );
}
