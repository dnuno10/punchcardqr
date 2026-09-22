import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../ui/core/app_card.dart';
import '../../../ui/core/empty_state.dart';
import '../../../ui/core/error_view.dart';
import '../../../ui/core/section_header.dart';
import '../../../ui/core/stat_card.dart';
import '../../billing/presentation/billing_screen.dart';
import '../../business/data/owner_repository.dart';

final dashboardStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final ctx = await ref.watch(ownerContextProvider.future);
  final res = await ref.watch(supabaseProvider).rpc('dashboard_stats', params: {'p_business': ctx!.business['id']});
  return Map<String, dynamic>.from(res as Map);
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctx = ref.watch(ownerContextProvider).value;
    final stats = ref.watch(dashboardStatsProvider);
    final plan = ref.watch(billingProvider).value?['plan'] as String?;
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good morning' : hour < 19 ? 'Good afternoon' : 'Good evening';

    return Scaffold(
      backgroundColor: AppColors.neutral0,
      appBar: AppBar(title: const Text('Dashboard'), actions: [
        IconButton(onPressed: () => ref.invalidate(dashboardStatsProvider), icon: const Icon(Icons.refresh)),
        const SizedBox(width: AppSpacing.sm),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/scan'),
        icon: const Icon(Icons.qr_code_scanner), label: const Text('Scan customer'),
      ),
      body: stats.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ErrorView('Could not load stats.', onRetry: () => ref.invalidate(dashboardStatsProvider)),
        data: (s) {
          final earned = s['rewards_earned'] as int, redeemed = s['rewards_redeemed'] as int;
          final days = (s['punches_by_day'] as List).cast<Map>();
          final recent = (s['recent_activity'] as List).cast<Map>();
          final wide = MediaQuery.sizeOf(context).width > 700;

          return ListView(padding: const EdgeInsets.all(AppSpacing.xl), children: [
            Text(greeting, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text('${ctx?.program?['name']} · ${ctx?.business['name']}',
                style: Theme.of(context).textTheme.bodyMedium),
            if (plan == 'free') ...[
              const SizedBox(height: AppSpacing.lg),
              _UpgradeBanner(onTap: () => context.go('/billing')),
            ],
            const SizedBox(height: AppSpacing.xl),
            GridView.count(
              crossAxisCount: wide ? 4 : 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: AppSpacing.md,
              mainAxisSpacing: AppSpacing.md,
              childAspectRatio: wide ? 1.5 : 1.3,
              children: [
                StatCard(label: 'Customers', value: '${s['customers']}', icon: Icons.people_outline, accent: AppColors.blue),
                StatCard(label: 'Punches (30d)', value: '${s['punches_30d']}', icon: Icons.confirmation_number_outlined, accent: AppColors.green),
                StatCard(label: 'Rewards redeemed', value: '${s['rewards_redeemed_total']}', icon: Icons.redeem_outlined, accent: AppColors.warning),
                StatCard(label: 'Active (30d)', value: '${s['active_customers']}', icon: Icons.bolt_outlined, accent: AppColors.navy),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SectionHeader(title: 'Punches per day', subtitle: 'Last 30 days'),
                SizedBox(
                  height: 180,
                  child: BarChart(BarChartData(
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    titlesData: const FlTitlesData(
                      topTitles: AxisTitles(), rightTitles: AxisTitles(), bottomTitles: AxisTitles(),
                      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28)),
                    ),
                    barGroups: [
                      for (var i = 0; i < days.length; i++)
                        BarChartGroupData(x: i, barRods: [
                          BarChartRodData(
                            toY: (days[i]['punches'] as num).toDouble(),
                            width: 6,
                            borderRadius: BorderRadius.circular(3),
                            color: AppColors.blue,
                          ),
                        ]),
                    ],
                  )),
                ),
              ]),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SectionHeader(title: 'Rewards', subtitle: 'Last 30 days'),
                Text(
                  '$earned earned · $redeemed redeemed'
                  '${earned > 0 ? ' · ${(redeemed * 100 / earned).toStringAsFixed(1)}% redemption' : ''}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ]),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SectionHeader(title: 'Recent activity'),
                if (recent.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                    child: EmptyState(
                      icon: Icons.qr_code_2,
                      title: 'Nothing yet',
                      message: 'Share your Join QR to get your first customer.',
                    ),
                  )
                else
                  for (final a in recent)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(switch (a['event_type']) {
                        'punch_added' => Icons.add_circle_outline,
                        'reward_redeemed' => Icons.redeem_outlined,
                        'punch_reversed' => Icons.undo,
                        _ => Icons.person_add_alt_outlined,
                      }, color: AppColors.blue, size: 20),
                      title: Text(switch (a['event_type']) {
                        'punch_added' => '+${a['quantity']} punch · ${a['name']}',
                        'reward_redeemed' => 'Reward redeemed · ${a['name']}',
                        'punch_reversed' => 'Punch undone · ${a['name']}',
                        _ => 'New customer · ${a['name']}',
                      }),
                      trailing: Text(timeAgo(a['created_at']), style: Theme.of(context).textTheme.bodySmall),
                    ),
              ]),
            ),
            const SizedBox(height: 72),
          ]);
        },
      ),
    );
  }
}

class _UpgradeBanner extends StatelessWidget {
  const _UpgradeBanner({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.navy,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
              child: const Icon(Icons.workspace_premium_outlined, color: Colors.white, size: 20),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Unlock promotions, CSV export & more', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                Text('You\'re on the Free plan — upgrade for higher limits and marketing tools.',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12.5)),
              ]),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Icon(Icons.arrow_forward, color: Colors.white, size: 18),
          ]),
        ),
      );
}
