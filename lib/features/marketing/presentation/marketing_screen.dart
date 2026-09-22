import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../ui/core/app_card.dart';
import '../../../ui/core/error_view.dart';
import '../../../ui/core/section_header.dart';
import '../../billing/presentation/billing_screen.dart';
import '../data/marketing_repository.dart';

class MarketingScreen extends ConsumerStatefulWidget {
  const MarketingScreen({super.key});
  @override
  ConsumerState<MarketingScreen> createState() => _MarketingScreenState();
}

class _MarketingScreenState extends ConsumerState<MarketingScreen> {
  bool _birthdayEnabled = false;
  int _birthdayBonus = 1;
  bool _reactivationEnabled = false;
  int _reactivationDays = 60;
  final _message = TextEditingController();
  bool _loaded = false, _busy = false;
  String? _msg;

  void _load(MarketingSettings s) {
    if (_loaded) return;
    _loaded = true;
    _birthdayEnabled = s.birthdayEnabled;
    _birthdayBonus = s.birthdayBonusPunches;
    _reactivationEnabled = s.reactivationEnabled;
    _reactivationDays = s.reactivationDays;
    _message.text = s.reactivationMessage ?? 'We miss you! Come back for your next reward.';
  }

  Future<void> _save() async {
    setState(() { _busy = true; _msg = null; });
    try {
      await ref.read(marketingRepositoryProvider).update(MarketingSettings(
        birthdayEnabled: _birthdayEnabled,
        birthdayBonusPunches: _birthdayBonus,
        reactivationEnabled: _reactivationEnabled,
        reactivationDays: _reactivationDays,
        reactivationMessage: _message.text.trim(),
      ));
      ref.invalidate(marketingSettingsProvider);
      setState(() => _msg = 'Saved.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = ref.watch(billingProvider).value?['plan'] as String?;
    final settings = ref.watch(marketingSettingsProvider);
    final consented = ref.watch(marketingConsentCountProvider).value;

    if (plan != null && plan != 'pro') {
      return Scaffold(
        backgroundColor: AppColors.neutral0,
        appBar: AppBar(title: const Text('Marketing')),
        body: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(color: AppColors.blueSurface, borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
            child: const Row(children: [
              Icon(Icons.workspace_premium_outlined, size: 18, color: AppColors.blueDark),
              SizedBox(width: AppSpacing.sm),
              Expanded(child: Text('Automated birthday rewards and re-engagement emails are part of the Pro plan.',
                  style: TextStyle(color: AppColors.blueDark, fontWeight: FontWeight.w600))),
            ]),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.neutral0,
      appBar: AppBar(title: const Text('Marketing')),
      body: settings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ErrorView('Could not load marketing settings.', onRetry: () => ref.invalidate(marketingSettingsProvider)),
        data: (s) {
          _load(s);
          return ListView(padding: const EdgeInsets.all(AppSpacing.xl), children: [
            AppCard(
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(color: AppColors.greenSurface, borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
                  child: const Icon(Icons.mark_email_read_outlined, color: AppColors.green, size: 20),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${consented ?? '—'}', style: Theme.of(context).textTheme.headlineSmall),
                    Text('customers opted in to receive email offers', style: Theme.of(context).textTheme.bodySmall),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: AppSpacing.xxl),
            const SectionHeader(title: 'Birthday rewards', subtitle: 'Automatically add bonus punches on a customer\'s birthday'),
            AppCard(
              child: Column(children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Enable birthday rewards'),
                  value: _birthdayEnabled,
                  onChanged: (v) => setState(() => _birthdayEnabled = v),
                ),
                if (_birthdayEnabled) ...[
                  const Divider(height: 1, color: AppColors.neutral200),
                  const SizedBox(height: AppSpacing.md),
                  Text('Bonus punches: $_birthdayBonus', style: Theme.of(context).textTheme.bodyMedium),
                  Slider(value: _birthdayBonus.toDouble(), min: 1, max: 5, divisions: 4, label: '$_birthdayBonus',
                      onChanged: (v) => setState(() => _birthdayBonus = v.round())),
                ],
              ]),
            ),
            const SizedBox(height: AppSpacing.xxl),
            const SectionHeader(title: 'Re-engagement', subtitle: 'Email customers who haven\'t visited in a while'),
            AppCard(
              child: Column(children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Enable re-engagement emails'),
                  value: _reactivationEnabled,
                  onChanged: (v) => setState(() => _reactivationEnabled = v),
                ),
                if (_reactivationEnabled) ...[
                  const Divider(height: 1, color: AppColors.neutral200),
                  const SizedBox(height: AppSpacing.md),
                  Text('Trigger after $_reactivationDays days of inactivity', style: Theme.of(context).textTheme.bodyMedium),
                  Slider(value: _reactivationDays.toDouble(), min: 14, max: 180, divisions: 166 ~/ 7, label: '$_reactivationDays',
                      onChanged: (v) => setState(() => _reactivationDays = v.round())),
                  const SizedBox(height: AppSpacing.md),
                  TextField(controller: _message, maxLines: 3, decoration: const InputDecoration(labelText: 'Message')),
                ],
              ]),
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(children: [
              FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Saving…' : 'Save changes')),
              if (_msg != null) ...[
                const SizedBox(width: AppSpacing.md),
                Text(_msg!, style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w600)),
              ],
            ]),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Campaigns run once a day. Customers must opt in at signup (or later) to receive these emails.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ]);
        },
      ),
    );
  }
}
