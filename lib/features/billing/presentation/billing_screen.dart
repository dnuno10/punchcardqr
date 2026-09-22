import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../ui/core/app_card.dart';
import '../../../ui/core/error_view.dart';
import '../../../ui/core/section_header.dart';
import '../../../ui/core/status_badge.dart';
import '../../business/data/owner_repository.dart';

final billingProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final ctx = await ref.watch(ownerContextProvider.future);
  final res = await ref.watch(supabaseProvider).rpc('billing_overview', params: {'p_business': ctx!.business['id']});
  return Map<String, dynamic>.from(res as Map);
});

/// Mirrors the seed values in supabase/migrations/0001_schema.sql (`plan_limits`).
/// Keep in sync if that table's defaults ever change.
class _PlanSpec {
  const _PlanSpec({
    required this.id,
    required this.name,
    required this.price,
    required this.tagline,
    required this.maxCustomers,
    required this.maxPunchesMonth,
    required this.maxLocations,
    required this.historyDays,
    required this.csvExport,
    required this.signupBonus,
    required this.promotions,
    required this.tiers,
  });

  final String id, name, price, tagline;
  final int maxCustomers, maxPunchesMonth, maxLocations;
  final int? historyDays;
  final bool csvExport, signupBonus, promotions, tiers;

  List<(String, bool)> get featureRows => [
        ('Up to ${_fmt(maxCustomers)} customers', true),
        ('${_fmt(maxPunchesMonth)} punches / month', true),
        ('$maxLocations location${maxLocations > 1 ? 's' : ''}', true),
        (historyDays == null ? 'Unlimited activity history' : '$historyDays-day activity history', true),
        ('CSV export', csvExport),
        ('Signup bonus punches', signupBonus),
        ('Promotions & double-punch days', promotions),
        ('Multiple reward tiers', tiers),
      ];

  static String _fmt(int n) => n >= 1000 ? '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)}k' : '$n';
}

const _plans = [
  _PlanSpec(
    id: 'free', name: 'Free', price: r'$0', tagline: 'Get a loyalty card live today',
    maxCustomers: 100, maxPunchesMonth: 200, maxLocations: 1, historyDays: 30,
    csvExport: false, signupBonus: false, promotions: false, tiers: false,
  ),
  _PlanSpec(
    id: 'starter', name: 'Starter', price: r'$9.99', tagline: 'For a single growing location',
    maxCustomers: 1000, maxPunchesMonth: 5000, maxLocations: 1, historyDays: 365,
    csvExport: true, signupBonus: true, promotions: false, tiers: false,
  ),
  _PlanSpec(
    id: 'pro', name: 'Pro', price: r'$19.99', tagline: 'For multi-location & marketing-led teams',
    maxCustomers: 10000, maxPunchesMonth: 25000, maxLocations: 5, historyDays: null,
    csvExport: true, signupBonus: true, promotions: true, tiers: true,
  ),
];

class BillingScreen extends ConsumerStatefulWidget {
  const BillingScreen({super.key});
  @override
  ConsumerState<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends ConsumerState<BillingScreen> {
  String? _error;
  String? _pendingPlan;

  /// Stripe hosts the payment page; the plan changes only when the webhook arrives.
  Future<void> _open(String fn, [Map<String, dynamic> body = const {}]) async {
    setState(() { _error = null; _pendingPlan = body['plan'] as String?; });
    try {
      final res = await callFunction(fn, body);
      await launchUrl(Uri.parse(res['url']), webOnlyWindowName: '_self');
    } on AppException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _pendingPlan = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(billingProvider);
    return Scaffold(
      backgroundColor: AppColors.neutral0,
      appBar: AppBar(title: const Text('Billing & plans')),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ErrorView('Could not load billing.', onRetry: () => ref.invalidate(billingProvider)),
        data: (d) {
          final plan = d['plan'] as String;
          final lim = d['limits'] as Map;
          final wide = MediaQuery.sizeOf(context).width >= 900;

          Widget meter(String label, int used, int max) {
            final ratio = max == 0 ? 0.0 : (used / max).clamp(0, 1).toDouble();
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(label, style: Theme.of(context).textTheme.bodyMedium),
                  Text('$used / $max', style: const TextStyle(fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: AppSpacing.xs),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 6,
                    backgroundColor: AppColors.neutral200,
                    color: ratio > 0.9 ? AppColors.error : AppColors.blue,
                  ),
                ),
              ]),
            );
          }

          return ListView(padding: const EdgeInsets.all(AppSpacing.xl), children: [
            Row(children: [
              Text('Current plan', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(width: AppSpacing.sm),
              StatusBadge(
                label: '${plan[0].toUpperCase()}${plan.substring(1)}',
                tone: plan == 'pro' ? StatusTone.success : (plan == 'free' ? StatusTone.neutral : StatusTone.info),
              ),
            ]),
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              child: Column(children: [
                meter('Customers', d['customers'], lim['max_customers']),
                meter('Punches this month', d['punches_this_month'], lim['max_punches_month']),
              ]),
            ),
            if (_error != null) Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(color: AppColors.errorSurface, borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
                child: Row(children: [
                  const Icon(Icons.error_outline, size: 18, color: AppColors.error),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13))),
                ]),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            const SectionHeader(title: 'Plans', subtitle: 'Upgrade or downgrade anytime — changes are prorated by Stripe'),
            wide
                ? IntrinsicHeight(
                    child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      for (final p in _plans) ...[
                        Expanded(child: _PlanCard(
                          spec: p, currentPlan: plan, busy: _pendingPlan == p.id,
                          onUpgrade: () => _open('create-checkout-session', {'plan': p.id}),
                          onManage: () => _open('create-customer-portal'),
                        )),
                        if (p.id != _plans.last.id) const SizedBox(width: AppSpacing.lg),
                      ],
                    ]),
                  )
                : Column(children: [
                    for (final p in _plans) ...[
                      _PlanCard(
                        spec: p, currentPlan: plan, busy: _pendingPlan == p.id,
                        onUpgrade: () => _open('create-checkout-session', {'plan': p.id}),
                        onManage: () => _open('create-customer-portal'),
                      ),
                      if (p.id != _plans.last.id) const SizedBox(height: AppSpacing.lg),
                    ],
                  ]),
            const SizedBox(height: AppSpacing.xl),
            if (plan != 'free')
              Center(
                child: TextButton.icon(
                  onPressed: () => _open('create-customer-portal'),
                  icon: const Icon(Icons.receipt_long_outlined, size: 18),
                  label: const Text('View invoices & payment method'),
                ),
              ),
          ]);
        },
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.spec,
    required this.currentPlan,
    required this.busy,
    required this.onUpgrade,
    required this.onManage,
  });

  final _PlanSpec spec;
  final String currentPlan;
  final bool busy;
  final VoidCallback onUpgrade, onManage;

  static const _order = ['free', 'starter', 'pro'];

  @override
  Widget build(BuildContext context) {
    final isCurrent = spec.id == currentPlan;
    final isUpgrade = _order.indexOf(spec.id) > _order.indexOf(currentPlan);
    final isPro = spec.id == 'pro';
    // A brand-new checkout session only works from Free. Anyone already subscribed
    // must change plans through the Stripe customer portal (Checkout would 409 —
    // see create-checkout-session's `already_subscribed` guard).
    final hasActiveSubscription = currentPlan != 'free';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: isCurrent ? AppColors.blue : AppColors.neutral200, width: isCurrent ? 1.5 : 1),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(spec.name, style: Theme.of(context).textTheme.titleLarge),
          if (isPro) const StatusBadge(label: 'Most popular', tone: StatusTone.info)
          else if (isCurrent) const StatusBadge(label: 'Current', tone: StatusTone.success),
        ]),
        const SizedBox(height: 4),
        Text(spec.tagline, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: AppSpacing.md),
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Text(spec.price, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.navy)),
          if (spec.id != 'free') Text('/mo', style: Theme.of(context).textTheme.bodySmall),
        ]),
        const SizedBox(height: AppSpacing.lg),
        for (final (label, included) in spec.featureRows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              Icon(included ? Icons.check_circle : Icons.remove_circle_outline, size: 16,
                  color: included ? AppColors.green : AppColors.neutral300),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(label, style: TextStyle(
                  fontSize: 13, color: included ? AppColors.navy : AppColors.neutral400))),
            ]),
          ),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          width: double.infinity,
          child: isCurrent
              ? OutlinedButton(onPressed: spec.id == 'free' ? null : onManage, child: const Text('Manage subscription'))
              : hasActiveSubscription
                  ? OutlinedButton(
                      onPressed: onManage,
                      child: Text(isUpgrade ? 'Switch to ${spec.name} via portal' : 'Downgrade to ${spec.name} via portal'),
                    )
                  : FilledButton(
                      onPressed: busy ? null : onUpgrade,
                      child: busy
                          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text('Upgrade to ${spec.name}'),
                    ),
        ),
      ]),
    );
  }
}
