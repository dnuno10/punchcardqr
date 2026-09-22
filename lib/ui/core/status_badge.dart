import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

enum StatusTone { success, warning, error, neutral, info }

/// Small pill used to communicate program/customer/subscription status.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, this.tone = StatusTone.neutral, this.icon});

  final String label;
  final StatusTone tone;
  final IconData? icon;

  (Color, Color) get _colors => switch (tone) {
        StatusTone.success => (AppColors.greenSurface, AppColors.green),
        StatusTone.warning => (AppColors.warningSurface, AppColors.warning),
        StatusTone.error => (AppColors.errorSurface, AppColors.error),
        StatusTone.info => (AppColors.blueSurface, AppColors.blueDark),
        StatusTone.neutral => (AppColors.neutral100, AppColors.neutral600),
      };

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 12, color: fg), const SizedBox(width: 4)],
        Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg)),
      ]),
    );
  }
}
