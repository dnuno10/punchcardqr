import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

class AppTheme {
  /// Kept for the per-program custom color fields (still seeded from the
  /// brand blue rather than the old brown default).
  static const seed = AppColors.blue;

  static const _colorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.blue,
    onPrimary: AppColors.neutral0,
    primaryContainer: AppColors.blueSurface,
    onPrimaryContainer: AppColors.blueDark,
    secondary: AppColors.navy,
    onSecondary: AppColors.neutral0,
    secondaryContainer: AppColors.neutral100,
    onSecondaryContainer: AppColors.navy,
    tertiary: AppColors.green,
    onTertiary: AppColors.neutral0,
    tertiaryContainer: AppColors.greenSurface,
    onTertiaryContainer: AppColors.green,
    error: AppColors.error,
    onError: AppColors.neutral0,
    errorContainer: AppColors.errorSurface,
    onErrorContainer: AppColors.error,
    surface: AppColors.neutral0,
    onSurface: AppColors.navy,
    surfaceContainerLowest: AppColors.neutral0,
    surfaceContainerLow: AppColors.neutral50,
    surfaceContainer: AppColors.neutral50,
    surfaceContainerHigh: AppColors.neutral100,
    surfaceContainerHighest: AppColors.neutral100,
    onSurfaceVariant: AppColors.neutral500,
    outline: AppColors.neutral300,
    outlineVariant: AppColors.neutral200,
    shadow: AppColors.navy,
    scrim: AppColors.navy,
    inverseSurface: AppColors.navy,
    onInverseSurface: AppColors.neutral0,
    inversePrimary: AppColors.blueLight,
  );

  static ThemeData get light {
    final textTheme = AppTypography.textTheme(AppColors.navy);
    return ThemeData(
      useMaterial3: true,
      colorScheme: _colorScheme,
      scaffoldBackgroundColor: AppColors.neutral0,
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
      dividerTheme: const DividerThemeData(color: AppColors.neutral200, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.neutral0,
        foregroundColor: AppColors.navy,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: const IconThemeData(color: AppColors.navy),
      ),
      cardTheme: CardThemeData(
        color: AppColors.neutral0,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          side: const BorderSide(color: AppColors.neutral200),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.neutral100,
        selectedColor: AppColors.blueSurface,
        disabledColor: AppColors.neutral100,
        labelStyle: textTheme.labelLarge!.copyWith(color: AppColors.navy),
        secondaryLabelStyle: textTheme.labelLarge!.copyWith(color: AppColors.blueDark),
        side: const BorderSide(color: AppColors.neutral200),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.neutral50,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: const BorderSide(color: AppColors.neutral300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: const BorderSide(color: AppColors.neutral300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: const BorderSide(color: AppColors.blue, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        labelStyle: const TextStyle(color: AppColors.neutral500),
        floatingLabelStyle: const TextStyle(color: AppColors.blue),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.blue,
          foregroundColor: AppColors.neutral0,
          minimumSize: const Size.fromHeight(48),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.navy,
          side: const BorderSide(color: AppColors.neutral300),
          minimumSize: const Size.fromHeight(48),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.blue,
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: AppColors.navy),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.blue,
        foregroundColor: AppColors.neutral0,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AppColors.neutral0,
        indicatorColor: AppColors.blueSurface,
        selectedIconTheme: const IconThemeData(color: AppColors.blue),
        unselectedIconTheme: const IconThemeData(color: AppColors.neutral500),
        selectedLabelTextStyle: textTheme.labelMedium!.copyWith(color: AppColors.blue),
        unselectedLabelTextStyle: textTheme.labelMedium!.copyWith(color: AppColors.neutral500),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.neutral0,
        indicatorColor: AppColors.blueSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              color: states.contains(WidgetState.selected) ? AppColors.blue : AppColors.neutral500,
            )),
        labelTextStyle: WidgetStateProperty.resolveWith((states) => textTheme.labelSmall!.copyWith(
              color: states.contains(WidgetState.selected) ? AppColors.blue : AppColors.neutral500,
              fontWeight: FontWeight.w600,
            )),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.neutral500,
        textColor: AppColors.navy,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.neutral0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusLg)),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.navy,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: AppColors.neutral0),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.blue,
        thumbColor: AppColors.blue,
        inactiveTrackColor: AppColors.neutral200,
        overlayColor: AppColors.blueSurface,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? AppColors.blue : AppColors.neutral0,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? AppColors.blueSurface : AppColors.neutral200,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.blue),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.blue,
        unselectedLabelColor: AppColors.neutral500,
        indicatorColor: AppColors.blue,
        labelStyle: textTheme.labelLarge,
      ),
    );
  }
}

/// Parses `#RRGGBB` coming from the program design settings.
Color parseHex(String? hex, Color fallback) {
  if (hex == null) return fallback;
  final v = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
  return v == null ? fallback : Color(0xFF000000 | v);
}
