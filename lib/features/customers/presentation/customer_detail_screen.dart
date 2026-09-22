import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../ui/core/error_view.dart';
import '../../../ui/core/section_header.dart';
import '../../../ui/core/stat_card.dart';
import '../../../ui/core/status_badge.dart';
import 'customers_screen.dart';

final _detailProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, id) async {
  final client = ref.watch(supabaseProvider);
  final m = await client.from('loyalty_memberships')
      .select('*, customers(*)').eq('id', id).single();
  final events = await client.from('loyalty_events').select('event_type, quantity, balance_after, created_at')
      .eq('membership_id', id).order('created_at', ascending: false).limit(100);
  final rewards = await client.from('earned_rewards').select('status').eq('membership_id', id);
  return {
    'membership': m,
    'events': events,
    'available': rewards.where((r) => r['status'] == 'available').length,
    'redeemed': rewards.where((r) => r['status'] == 'redeemed').length,
  };
});

class CustomerDetailScreen extends ConsumerWidget {
  const CustomerDetailScreen({super.key, required this.membershipId});
  final String membershipId;

  static String _eventLabel(Map e) => switch (e['event_type']) {
        'punch_added' => '+${e['quantity']} punch',
        'signup_bonus' => '+${e['quantity']} welcome bonus',
        'manual_adjustment' => '+${e['quantity']} manual adjustment',
        'punch_reversed' => '${e['quantity']} punch undone',
        'reward_earned' => 'Reward unlocked',
        'reward_redeemed' => 'Reward redeemed',
        'membership_created' => 'Joined',
        final t => '$t',
      };

  static IconData _eventIcon(Map e) => switch (e['event_type']) {
        'punch_added' || 'manual_adjustment' || 'signup_bonus' => Icons.add_circle_outline,
        'punch_reversed' => Icons.undo,
        'reward_earned' || 'reward_redeemed' => Icons.redeem_outlined,
        'membership_created' => Icons.person_add_alt_outlined,
        _ => Icons.circle_outlined,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(_detailProvider(membershipId));
    return Scaffold(
      backgroundColor: AppColors.neutral0,
      appBar: AppBar(leading: BackButton(onPressed: () => context.go('/customers')), title: const Text('Customer')),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ErrorView('Could not load this customer.', onRetry: () => ref.invalidate(_detailProvider(membershipId))),
        data: (d) {
          final m = d['membership'] as Map<String, dynamic>;
          final c = m['customers'] as Map;
          final active = m['status'] == 'active';
          final events = (d['events'] as List).cast<Map>();
          return ListView(padding: const EdgeInsets.all(AppSpacing.xl), children: [
            Row(children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.blueSurface,
                child: Text(
                  customerLabel(c).isNotEmpty ? customerLabel(c)[0].toUpperCase() : '?',
                  style: const TextStyle(color: AppColors.blueDark, fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(customerLabel(c), style: Theme.of(context).textTheme.headlineSmall),
                  Row(children: [
                    Text('Joined ${fmtDay(m['joined_at'])}', style: Theme.of(context).textTheme.bodySmall),
                    if (!active) ...[
                      const SizedBox(width: AppSpacing.sm),
                      StatusBadge(label: m['status'], tone: StatusTone.warning),
                    ],
                  ]),
                ]),
              ),
            ]),
            const SizedBox(height: AppSpacing.xl),
            GridView.count(
              crossAxisCount: MediaQuery.sizeOf(context).width > 600 ? 4 : 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: AppSpacing.md,
              mainAxisSpacing: AppSpacing.md,
              childAspectRatio: 1.4,
              children: [
                StatCard(label: 'Current punches', value: '${m['current_punches']}', icon: Icons.confirmation_number_outlined, accent: AppColors.blue),
                StatCard(label: 'Lifetime punches', value: '${m['lifetime_punches']}', icon: Icons.timeline, accent: AppColors.navy),
                StatCard(label: 'Rewards available', value: '${d['available']}', icon: Icons.redeem_outlined, accent: AppColors.green),
                StatCard(label: 'Rewards redeemed', value: '${d['redeemed']}', icon: Icons.check_circle_outline, accent: AppColors.warning),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            const SectionHeader(title: 'Contact'),
            Text([c['email'], c['phone'], c['birthday']].whereType<String>().join(' · ').ifEmpty('Anonymous — no contact info'),
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton.icon(
              icon: Icon(active ? Icons.block : Icons.check_circle_outline),
              label: Text(active ? 'Deactivate card' : 'Reactivate card'),
              onPressed: () async {
                await ref.read(supabaseProvider).from('loyalty_memberships')
                    .update({'status': active ? 'blocked' : 'active'}).eq('id', membershipId);
                ref.invalidate(_detailProvider(membershipId));
                ref.invalidate(membershipsProvider);
              },
            ),
            const SizedBox(height: AppSpacing.xl),
            const SectionHeader(title: 'Activity'),
            for (final e in events)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(_eventIcon(e), size: 20, color: AppColors.blue),
                title: Text(_eventLabel(e)),
                trailing: Text(fmtDate(e['created_at']), style: Theme.of(context).textTheme.bodySmall),
              ),
          ]);
        },
      ),
    );
  }
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}
