import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../ui/core/empty_state.dart';
import '../../../ui/core/error_view.dart';
import '../../../ui/core/status_badge.dart';

/// Memberships joined with their customer row. RLS scopes this to the owner's business.
final membershipsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final rows = await ref.watch(supabaseProvider).from('loyalty_memberships')
      .select('id, current_punches, lifetime_punches, lifetime_rewards, status, joined_at, last_activity_at, '
          'customers(customer_number, first_name, last_name, email, phone)')
      .order('last_activity_at', ascending: false, nullsFirst: false).limit(500);
  return rows.cast<Map<String, dynamic>>();
});

enum _Filter { all, active, inactive30, inactive60, top }

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});
  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  String _query = '';
  _Filter _filter = _Filter.all;

  bool _matches(Map<String, dynamic> m) {
    final c = m['customers'] as Map;
    final q = _query.toLowerCase();
    if (q.isNotEmpty) {
      final hay = '${c['first_name'] ?? ''} ${c['last_name'] ?? ''} ${c['email'] ?? ''} ${c['phone'] ?? ''} ${c['customer_number']}'.toLowerCase();
      if (!hay.contains(q)) return false;
    }
    final last = m['last_activity_at'] == null ? null : DateTime.parse(m['last_activity_at']);
    final idle = last == null ? 9999 : DateTime.now().difference(last).inDays;
    return switch (_filter) {
      _Filter.all || _Filter.top => true,
      _Filter.active => idle <= 30,
      _Filter.inactive30 => idle > 30,
      _Filter.inactive60 => idle > 60,
    };
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(membershipsProvider);
    return Scaffold(
      backgroundColor: AppColors.neutral0,
      appBar: AppBar(title: const Text('Customers')),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ErrorView('Could not load customers.', onRetry: () => ref.invalidate(membershipsProvider)),
        data: (all) {
          var rows = all.where(_matches).toList();
          if (_filter == _Filter.top) {
            rows.sort((a, b) => (b['lifetime_punches'] as int).compareTo(a['lifetime_punches'] as int));
          }
          return Column(children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: TextField(
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search name, email, phone or #'),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(children: [
                for (final (f, label) in [
                  (_Filter.all, 'All'), (_Filter.active, 'Active'), (_Filter.inactive30, 'Inactive 30d'),
                  (_Filter.inactive60, 'Inactive 60d'), (_Filter.top, 'Top customers'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: ChoiceChip(label: Text(label), selected: _filter == f, onSelected: (_) => setState(() => _filter = f)),
                  ),
              ]),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: rows.isEmpty
                  ? const EmptyState(icon: Icons.people_outline, title: 'No customers found', message: 'Try a different search or filter.')
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                      itemCount: rows.length,
                      separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.neutral200),
                      itemBuilder: (_, i) {
                        final m = rows[i];
                        final c = m['customers'] as Map;
                        return ListTile(
                          tileColor: Colors.white,
                          leading: CircleAvatar(
                            backgroundColor: AppColors.blueSurface,
                            child: Text(
                              customerLabel(c).isNotEmpty ? customerLabel(c)[0].toUpperCase() : '?',
                              style: const TextStyle(color: AppColors.blueDark, fontWeight: FontWeight.w700),
                            ),
                          ),
                          title: Text(customerLabel(c), style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Row(children: [
                            Text('${m['lifetime_punches']} visits · ${m['lifetime_rewards']} rewards'),
                            if (m['status'] != 'active') ...[
                              const SizedBox(width: AppSpacing.sm),
                              StatusBadge(label: m['status'], tone: StatusTone.warning),
                            ],
                          ]),
                          trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Text('${m['current_punches']} punches', style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text(m['last_activity_at'] == null ? 'No visits' : timeAgo(m['last_activity_at']),
                                style: Theme.of(context).textTheme.bodySmall),
                          ]),
                          onTap: () => context.go('/customers/${m['id']}'),
                        );
                      },
                    ),
            ),
          ]);
        },
      ),
    );
  }
}
