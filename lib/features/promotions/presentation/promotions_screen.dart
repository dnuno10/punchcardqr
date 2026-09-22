import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../ui/core/app_card.dart';
import '../../../ui/core/empty_state.dart';
import '../../billing/presentation/billing_screen.dart';
import '../../business/data/owner_repository.dart';

final promotionsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final rows = await ref.watch(supabaseProvider).from('promotions').select().order('starts_at', ascending: false);
  return rows.cast<Map<String, dynamic>>();
});

/// Pro-only: double-punch days and bonus punches. Enforced server-side in award_punch; the UI gate is convenience.
class PromotionsScreen extends ConsumerWidget {
  const PromotionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(billingProvider).value?['plan'];
    final promos = ref.watch(promotionsProvider);
    return Scaffold(
      backgroundColor: AppColors.neutral0,
      appBar: AppBar(title: const Text('Promotions')),
      floatingActionButton: plan == 'pro'
          ? FloatingActionButton.extended(onPressed: () => _create(context, ref), icon: const Icon(Icons.add), label: const Text('New promotion'))
          : null,
      body: Column(children: [
        if (plan != null && plan != 'pro')
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(AppSpacing.md),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(color: AppColors.blueSurface, borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
            child: const Row(children: [
              Icon(Icons.workspace_premium_outlined, size: 18, color: AppColors.blueDark),
              SizedBox(width: AppSpacing.sm),
              Expanded(child: Text('Promotions are part of the Pro plan.', style: TextStyle(color: AppColors.blueDark, fontWeight: FontWeight.w600))),
            ]),
          ),
        Expanded(
          child: promos.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => const Center(child: Text('Could not load promotions.')),
            data: (rows) => rows.isEmpty
                ? const EmptyState(icon: Icons.campaign_outlined, title: 'No promotions yet', message: 'Create one to boost visits on slow days.')
                : ListView(padding: const EdgeInsets.all(AppSpacing.md), children: [
                    for (final p in rows)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: AppCard(
                          padding: EdgeInsets.zero,
                          child: SwitchListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
                            title: Text(p['name'], style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text('${p['promotion_type'] == 'multiplier' ? '${p['multiplier']}x punches' : '+${p['bonus_quantity']} bonus'}'
                                ' · ${fmtDay(p['starts_at'])} – ${fmtDay(p['ends_at'])}'),
                            value: p['is_active'],
                            onChanged: plan == 'pro'
                                ? (v) async {
                                    await ref.read(supabaseProvider).from('promotions').update({'is_active': v}).eq('id', p['id']);
                                    ref.invalidate(promotionsProvider);
                                  }
                                : null,
                          ),
                        ),
                      ),
                  ]),
          ),
        ),
      ]),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final ctx = ref.read(ownerContextProvider).value!;
    final name = TextEditingController(text: 'Double Punch Day');
    var multiplier = 2;
    final days = <int>{2}; // Tuesday
    var range = DateTimeRange(start: DateTime.now(), end: DateTime.now().add(const Duration(days: 30)));
    const dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(builder: (c, set) => AlertDialog(
        title: const Text('New promotion'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<int>(
            initialValue: multiplier, decoration: const InputDecoration(labelText: 'Punches per visit'),
            items: [for (final m in [2, 3]) DropdownMenuItem(value: m, child: Text('${m}x'))],
            onChanged: (v) => set(() => multiplier = v!),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(spacing: AppSpacing.xs, children: [
            for (var i = 0; i < 7; i++)
              FilterChip(label: Text(dayNames[i]), selected: days.contains(i),
                  onSelected: (s) => set(() => s ? days.add(i) : days.remove(i))),
          ]),
          TextButton(
            onPressed: () async {
              final r = await showDateRangePicker(context: c, firstDate: DateTime.now().subtract(const Duration(days: 1)),
                  lastDate: DateTime.now().add(const Duration(days: 730)), initialDateRange: range);
              if (r != null) set(() => range = r);
            },
            child: Text('${fmtDay(range.start.toIso8601String())} – ${fmtDay(range.end.toIso8601String())}'),
          ),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Create')),
        ],
      )),
    );
    if (ok != true) return;
    try {
      await ref.read(supabaseProvider).from('promotions').insert({
        'business_id': ctx.business['id'], 'program_id': ctx.program!['id'],
        'name': name.text.trim(), 'promotion_type': 'multiplier', 'multiplier': multiplier,
        'starts_at': range.start.toUtc().toIso8601String(),
        'ends_at': range.end.add(const Duration(days: 1)).toUtc().toIso8601String(),
        'days_of_week': days.isEmpty ? null : days.toList(),
      });
      ref.invalidate(promotionsProvider);
    } on PostgrestException catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}
