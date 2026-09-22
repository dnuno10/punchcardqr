import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart' as csv_lib;
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../ui/core/app_card.dart';
import '../../../ui/core/section_header.dart';
import '../../../ui/core/stat_card.dart';
import '../../billing/presentation/billing_screen.dart';
import '../../business/data/owner_repository.dart';
import '../../customers/presentation/customers_screen.dart';
import '../../dashboard/presentation/dashboard_screen.dart';

/// Retention, top customers, and CSV export — derived from memberships + the dashboard stats RPC.
class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});
  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  DateTimeRange _range = DateTimeRange(start: DateTime.now().subtract(const Duration(days: 30)), end: DateTime.now());
  bool _exporting = false;

  Future<void> _download(String name, List<List<dynamic>> rows) async {
    final body = csv_lib.csv.encode(rows);
    await FileSaver.instance.saveFile(
      name: name, bytes: Uint8List.fromList(utf8.encode(body)), fileExtension: 'csv', mimeType: MimeType.csv);
  }

  Future<void> _exportCustomers(String businessId) async {
    setState(() => _exporting = true);
    try {
      final client = ref.read(supabaseProvider);
      final rows = <Map<String, dynamic>>[];
      var from = 0;
      const page = 1000;
      while (true) {
        final batch = await client.from('loyalty_memberships')
            .select('current_punches, lifetime_punches, lifetime_rewards, status, joined_at, last_activity_at, '
                'customers(customer_number, first_name, last_name, email, phone)')
            .eq('business_id', businessId).order('joined_at').range(from, from + page - 1);
        rows.addAll(batch.cast<Map<String, dynamic>>());
        if (batch.length < page) break;
        from += page;
      }
      await _download('customers', [
        ['Customer #', 'First name', 'Last name', 'Email', 'Phone', 'Current punches', 'Lifetime punches', 'Lifetime rewards', 'Status', 'Joined', 'Last activity'],
        for (final m in rows) [
          (m['customers'] as Map)['customer_number'],
          (m['customers'] as Map)['first_name'] ?? '',
          (m['customers'] as Map)['last_name'] ?? '',
          (m['customers'] as Map)['email'] ?? '',
          (m['customers'] as Map)['phone'] ?? '',
          m['current_punches'], m['lifetime_punches'], m['lifetime_rewards'], m['status'],
          m['joined_at'], m['last_activity_at'] ?? '',
        ],
      ]);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _exportActivity(String businessId) async {
    setState(() => _exporting = true);
    try {
      final client = ref.read(supabaseProvider);
      final rows = <Map<String, dynamic>>[];
      var from = 0;
      const page = 1000;
      final startIso = _range.start.toUtc().toIso8601String();
      final endIso = _range.end.add(const Duration(days: 1)).toUtc().toIso8601String();
      while (true) {
        final batch = await client.from('loyalty_events')
            .select('event_type, quantity, balance_after, created_at, loyalty_memberships(customers(customer_number, first_name, last_name))')
            .eq('business_id', businessId).gte('created_at', startIso).lt('created_at', endIso)
            .order('created_at').range(from, from + page - 1);
        rows.addAll(batch.cast<Map<String, dynamic>>());
        if (batch.length < page) break;
        from += page;
      }
      await _download('activity', [
        ['Date', 'Event', 'Quantity', 'Balance after', 'Customer #', 'Customer name'],
        for (final e in rows) [
          e['created_at'],
          e['event_type'],
          e['quantity'],
          e['balance_after'],
          ((e['loyalty_memberships'] as Map?)?['customers'] as Map?)?['customer_number'] ?? '',
          [((e['loyalty_memberships'] as Map?)?['customers'] as Map?)?['first_name'], ((e['loyalty_memberships'] as Map?)?['customers'] as Map?)?['last_name']]
              .where((v) => v != null).join(' '),
        ],
      ]);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(dashboardStatsProvider).value;
    final members = ref.watch(membershipsProvider).value;
    final business = ref.watch(ownerContextProvider).value?.business;
    final billing = ref.watch(billingProvider).value;
    final canExport = billing?['limits']?['allow_csv_export'] == true;
    if (stats == null || members == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    int idleDays(Map m) => m['last_activity_at'] == null
        ? 9999 : DateTime.now().difference(DateTime.parse(m['last_activity_at'])).inDays;
    final total = members.length;
    final repeat = members.where((m) => (m['lifetime_punches'] as int) >= 2).length;
    final top = ([...members]..sort((a, b) => (b['lifetime_punches'] as int).compareTo(a['lifetime_punches'] as int))).take(10);
    final wide = MediaQuery.sizeOf(context).width > 700;

    return Scaffold(
      backgroundColor: AppColors.neutral0,
      appBar: AppBar(title: const Text('Analytics')),
      body: ListView(padding: const EdgeInsets.all(AppSpacing.xl), children: [
        const SectionHeader(title: 'Customers', subtitle: 'Retention over the last 30 days'),
        GridView.count(
          crossAxisCount: wide ? 4 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: AppSpacing.md,
          mainAxisSpacing: AppSpacing.md,
          childAspectRatio: wide ? 1.5 : 1.3,
          children: [
            StatCard(label: 'Total customers', value: '$total', icon: Icons.people_outline, accent: AppColors.blue),
            StatCard(label: 'New (30d)', value: '${stats['new_customers']}', icon: Icons.person_add_alt_outlined, accent: AppColors.green),
            StatCard(label: 'Active (30d)', value: '${stats['active_customers']}', icon: Icons.bolt_outlined, accent: AppColors.navy),
            StatCard(
              label: 'Repeat rate',
              value: total == 0 ? '—' : '${(repeat * 100 / total).toStringAsFixed(0)}%',
              icon: Icons.repeat,
              accent: AppColors.warning,
            ),
            StatCard(label: 'Inactive 30d+', value: '${members.where((m) => idleDays(m) > 30).length}', icon: Icons.snooze_outlined, accent: AppColors.neutral500),
            StatCard(label: 'Inactive 60d+', value: '${members.where((m) => idleDays(m) > 60).length}', icon: Icons.hourglass_bottom, accent: AppColors.neutral500),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SectionHeader(title: 'Rewards', subtitle: 'Last 30 days'),
            _Row('Earned', stats['rewards_earned']),
            _Row('Redeemed', stats['rewards_redeemed']),
            _Row('Unredeemed (all time)', stats['unredeemed_rewards']),
          ]),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SectionHeader(title: 'Top customers', subtitle: 'By lifetime punches'),
            for (final m in top) _Row(customerLabel(m['customers'] as Map), m['lifetime_punches']),
          ]),
        ),
        const SizedBox(height: AppSpacing.xl),
        const SectionHeader(title: 'Export data', subtitle: 'Download CSV files for your own reporting or spreadsheets'),
        if (!canExport)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(color: AppColors.blueSurface, borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
            child: const Row(children: [
              Icon(Icons.workspace_premium_outlined, size: 18, color: AppColors.blueDark),
              SizedBox(width: AppSpacing.sm),
              Expanded(child: Text('CSV export is part of the Starter and Pro plans.', style: TextStyle(color: AppColors.blueDark, fontWeight: FontWeight.w600))),
            ]),
          )
        else
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('All customers', style: TextStyle(fontWeight: FontWeight.w600)),
                    Text('Full customer list with punches and contact info', style: Theme.of(context).textTheme.bodySmall),
                  ]),
                ),
                OutlinedButton.icon(
                  onPressed: _exporting || business == null ? null : () => _exportCustomers(business['id']),
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text('CSV'),
                ),
              ]),
              const Divider(height: AppSpacing.xxl, color: AppColors.neutral200),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Activity', style: TextStyle(fontWeight: FontWeight.w600)),
                TextButton.icon(
                  onPressed: () async {
                    final picked = await showDateRangePicker(
                      context: context, firstDate: DateTime.now().subtract(const Duration(days: 730)),
                      lastDate: DateTime.now(), initialDateRange: _range,
                    );
                    if (picked != null) setState(() => _range = picked);
                  },
                  icon: const Icon(Icons.calendar_today_outlined, size: 15),
                  label: Text('${DateFormat.MMMd().format(_range.start)} – ${DateFormat.MMMd().format(_range.end)}'),
                ),
              ]),
              Text('Punches, redemptions and signups in the selected range', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _exporting || business == null ? null : () => _exportActivity(business['id']),
                  icon: _exporting
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.download, size: 18),
                  label: const Text('Export activity CSV'),
                ),
              ),
            ]),
          ),
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label;
  final Object? value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
          Text('$value', style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
      );
}
