import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Enterprise SaaS type scale built on Inter, tuned for dashboards and forms.
class AppTypography {
  AppTypography._();

  static TextTheme textTheme(Color onSurface) {
    final base = GoogleFonts.interTextTheme();
    return base.copyWith(
      displaySmall: GoogleFonts.inter(
        fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: onSurface, height: 1.2),
      headlineMedium: GoogleFonts.inter(
        fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: onSurface, height: 1.25),
      headlineSmall: GoogleFonts.inter(
        fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.2, color: onSurface, height: 1.3),
      titleLarge: GoogleFonts.inter(
        fontSize: 18, fontWeight: FontWeight.w600, color: onSurface, height: 1.3),
      titleMedium: GoogleFonts.inter(
        fontSize: 16, fontWeight: FontWeight.w600, color: onSurface, height: 1.4),
      titleSmall: GoogleFonts.inter(
        fontSize: 14, fontWeight: FontWeight.w600, color: onSurface, height: 1.4),
      bodyLarge: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w400, color: onSurface, height: 1.5),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14, fontWeight: FontWeight.w400, color: onSurface, height: 1.5),
      bodySmall: GoogleFonts.inter(
        fontSize: 12.5, fontWeight: FontWeight.w400, color: AppColors.neutral500, height: 1.4),
      labelLarge: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.1),
      labelMedium: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.2),
      labelSmall: GoogleFonts.inter(
        fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.4, color: AppColors.neutral500),
    );
  }
}
