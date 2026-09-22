import 'package:flutter/material.dart';

/// Brand tokens derived from the PunchCardQR mark: navy frame, medium-blue
/// scan corners, and green punch checkmarks.
class AppColors {
  AppColors._();

  // Brand
  static const navy = Color(0xFF16233F);
  static const navyDark = Color(0xFF0D1626);
  static const blue = Color(0xFF2F6FED);
  static const blueDark = Color(0xFF1E52C4);
  static const blueLight = Color(0xFF5B93F5);
  static const blueSurface = Color(0xFFEEF3FE);
  static const green = Color(0xFF2E9E4F);
  static const greenSurface = Color(0xFFE7F6EA);

  // Semantic
  static const success = green;
  static const warning = Color(0xFFB5740A);
  static const warningSurface = Color(0xFFFCF1DC);
  static const error = Color(0xFFCC3340);
  static const errorSurface = Color(0xFFFBEBEC);

  // Neutral / slate scale
  static const neutral0 = Color(0xFFFFFFFF);
  static const neutral50 = Color(0xFFF7F8FA);
  static const neutral100 = Color(0xFFEEF0F4);
  static const neutral200 = Color(0xFFE1E4EA);
  static const neutral300 = Color(0xFFC8CDD6);
  static const neutral400 = Color(0xFF9AA2AF);
  static const neutral500 = Color(0xFF6C7688);
  static const neutral600 = Color(0xFF4C5567);
  static const neutral700 = Color(0xFF343B4A);
  static const neutral800 = Color(0xFF232838);
  static const neutral900 = Color(0xFF141824);
}
