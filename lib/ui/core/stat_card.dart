import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// KPI tile for dashboards: icon, big value, label and an optional trend delta.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.accent = AppColors.blue,
    this.delta,
    this.deltaIsPositive = true,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accent;
  final String? delta;
  final bool deltaIsPositive;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Icon(icon, color: accent, size: 20),
                ),
                if (delta != null)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(
                      deltaIsPositive ? Icons.trending_up : Icons.trending_down,
                      size: 14,
                      color: deltaIsPositive ? AppColors.green : AppColors.error,
                    ),
                    const SizedBox(width: 2),
                    Text(delta!,
                        style: textTheme.labelSmall?.copyWith(
                          color: deltaIsPositive ? AppColors.green : AppColors.error,
                        )),
                  ]),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(value, style: textTheme.headlineSmall),
            const SizedBox(height: 2),
            Text(label, style: textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
