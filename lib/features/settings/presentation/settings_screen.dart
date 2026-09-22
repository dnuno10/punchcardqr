import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../ui/core/app_card.dart';
import '../../../ui/core/section_header.dart';
import '../../business/data/business_templates.dart';
import '../../business/data/owner_repository.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _name = TextEditingController(), _website = TextEditingController(), _phone = TextEditingController(),
      _instagram = TextEditingController(), _tz = TextEditingController();
  String _category = 'other';
  bool _loaded = false;
  String? _msg;

  Future<void> _save(String id) async {
    await ref.read(supabaseProvider).from('businesses').update({
      'name': _name.text.trim(), 'website': _website.text.trim(), 'phone': _phone.text.trim(),
      'instagram': _instagram.text.trim(), 'timezone': _tz.text.trim(), 'category': _category,
    }).eq('id', id);
    ref.invalidate(ownerContextProvider);
    setState(() => _msg = 'Saved.');
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(ownerContextProvider).value;
    if (c == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (!_loaded) {
      _loaded = true;
      _name.text = c.business['name']; _website.text = c.business['website'] ?? '';
      _phone.text = c.business['phone'] ?? ''; _instagram.text = c.business['instagram'] ?? '';
      _tz.text = c.business['timezone'];
      _category = (c.business['category'] as String?) ?? 'other';
    }
    final paused = c.program?['status'] == 'paused';
    return Scaffold(
      backgroundColor: AppColors.neutral0,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(padding: const EdgeInsets.all(AppSpacing.xl), children: [
        const SectionHeader(title: 'Business', subtitle: 'Public details customers may see'),
        AppCard(
          child: Column(children: [
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Industry'),
              items: [
                for (final t in businessTemplates)
                  DropdownMenuItem(value: t.category, child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(t.icon, size: 16, color: AppColors.neutral500),
                    const SizedBox(width: AppSpacing.sm),
                    Text(t.label),
                  ])),
              ],
              onChanged: (v) => setState(() => _category = v!),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(controller: _website, decoration: const InputDecoration(labelText: 'Website')),
            const SizedBox(height: AppSpacing.md),
            TextField(controller: _instagram, decoration: const InputDecoration(labelText: 'Instagram')),
            const SizedBox(height: AppSpacing.md),
            TextField(controller: _phone, decoration: const InputDecoration(labelText: 'Phone')),
            const SizedBox(height: AppSpacing.md),
            TextField(controller: _tz, decoration: const InputDecoration(
                labelText: 'Timezone (IANA, e.g. America/Mexico_City)', helperText: 'Used for promotion schedules and daily charts.')),
            const SizedBox(height: AppSpacing.lg),
            Row(children: [
              FilledButton(onPressed: () => _save(c.business['id']), child: const Text('Save')),
              if (_msg != null) ...[
                const SizedBox(width: AppSpacing.md),
                Text(_msg!, style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w600)),
              ],
            ]),
          ]),
        ),
        const SizedBox(height: AppSpacing.xl),
        const SectionHeader(title: 'Program'),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            ListTile(leading: const Icon(Icons.tune), title: const Text('Program & card design'), trailing: const Icon(Icons.chevron_right), onTap: () => context.go('/program')),
            const Divider(height: 1, color: AppColors.neutral200),
            ListTile(leading: const Icon(Icons.storefront_outlined), title: const Text('Locations'), trailing: const Icon(Icons.chevron_right), onTap: () => context.go('/locations')),
            const Divider(height: 1, color: AppColors.neutral200),
            ListTile(leading: const Icon(Icons.campaign_outlined), title: const Text('Promotions'), trailing: const Icon(Icons.chevron_right), onTap: () => context.go('/promotions')),
            const Divider(height: 1, color: AppColors.neutral200),
            ListTile(leading: const Icon(Icons.mark_email_read_outlined), title: const Text('Marketing'), trailing: const Icon(Icons.chevron_right), onTap: () => context.go('/marketing')),
            const Divider(height: 1, color: AppColors.neutral200),
            ListTile(leading: const Icon(Icons.insights), title: const Text('Analytics'), trailing: const Icon(Icons.chevron_right), onTap: () => context.go('/analytics')),
            const Divider(height: 1, color: AppColors.neutral200),
            ListTile(leading: const Icon(Icons.credit_card), title: const Text('Billing'), trailing: const Icon(Icons.chevron_right), onTap: () => context.go('/billing')),
            const Divider(height: 1, color: AppColors.neutral200),
            SwitchListTile(
              title: const Text('Pause program'), subtitle: const Text('Customers cannot join and punches are blocked while paused.'),
              value: paused,
              onChanged: c.program == null ? null : (v) async {
                await ref.read(supabaseProvider).from('loyalty_programs').update({'status': v ? 'paused' : 'active'}).eq('id', c.program!['id']);
                ref.invalidate(ownerContextProvider);
              },
            ),
          ]),
        ),
        const SizedBox(height: AppSpacing.xl),
        OutlinedButton.icon(onPressed: () => ref.read(supabaseProvider).auth.signOut(),
            icon: const Icon(Icons.logout), label: const Text('Sign out')),
      ]),
    );
  }
}
