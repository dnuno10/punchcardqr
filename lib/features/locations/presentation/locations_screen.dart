import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../ui/core/empty_state.dart';
import '../../../ui/core/error_view.dart';
import '../../../ui/core/status_badge.dart';
import '../../billing/presentation/billing_screen.dart';
import '../../business/data/owner_repository.dart';
import '../data/locations_repository.dart';

class LocationsScreen extends ConsumerWidget {
  const LocationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locations = ref.watch(locationsProvider);
    final maxLocations = ref.watch(billingProvider).value?['limits']?['max_locations'] as int?;
    final atLimit = maxLocations != null && (locations.value?.length ?? 0) >= maxLocations;

    return Scaffold(
      backgroundColor: AppColors.neutral0,
      appBar: AppBar(title: const Text('Locations')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: atLimit ? () => context.go('/billing') : () => _editDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add location'),
      ),
      body: locations.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ErrorView('Could not load locations.', onRetry: () => ref.invalidate(locationsProvider)),
        data: (rows) => Column(children: [
          if (maxLocations != null)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: atLimit ? AppColors.warningSurface : AppColors.blueSurface,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Row(children: [
                  Icon(atLimit ? Icons.error_outline : Icons.info_outline, size: 18,
                      color: atLimit ? AppColors.warning : AppColors.blueDark),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      atLimit
                          ? 'You\'ve reached your plan\'s limit of $maxLocations location${maxLocations > 1 ? 's' : ''}. Upgrade to add more.'
                          : '${rows.length} of $maxLocations locations used on your plan.',
                      style: TextStyle(color: atLimit ? AppColors.warning : AppColors.blueDark, fontSize: 13),
                    ),
                  ),
                  if (atLimit) TextButton(onPressed: () => context.go('/billing'), child: const Text('Upgrade')),
                ]),
              ),
            ),
          Expanded(
            child: rows.isEmpty
                ? const EmptyState(
                    icon: Icons.storefront_outlined,
                    title: 'No locations yet',
                    message: 'Add your first location so the Scan screen can attribute punches to it.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    itemCount: rows.length,
                    separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.neutral200),
                    itemBuilder: (_, i) {
                      final l = rows[i];
                      final active = l['is_active'] == true;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: active ? AppColors.blueSurface : AppColors.neutral100,
                          child: Icon(Icons.storefront, size: 18, color: active ? AppColors.blueDark : AppColors.neutral400),
                        ),
                        title: Text(l['name'], style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text([l['address'], l['city'], l['country']].where((v) => (v as String?)?.isNotEmpty ?? false).join(', ').ifEmpty('No address on file')),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          if (!active) const Padding(padding: EdgeInsets.only(right: AppSpacing.sm), child: StatusBadge(label: 'Inactive', tone: StatusTone.neutral)),
                          IconButton(icon: const Icon(Icons.edit_outlined, size: 20), onPressed: () => _editDialog(context, ref, location: l)),
                          Switch(value: active, onChanged: (v) => ref.read(locationsRepositoryProvider).setActive(l['id'], v).then((_) => ref.invalidate(locationsProvider))),
                        ]),
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }

  Future<void> _editDialog(BuildContext context, WidgetRef ref, {Map<String, dynamic>? location}) async {
    final ctx = ref.read(ownerContextProvider).value;
    if (ctx == null) return;
    final name = TextEditingController(text: location?['name'] ?? '');
    final address = TextEditingController(text: location?['address'] ?? '');
    final city = TextEditingController(text: location?['city'] ?? '');
    final country = TextEditingController(text: location?['country'] ?? '');
    String? error;

    final saved = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(builder: (c, setState) => AlertDialog(
        title: Text(location == null ? 'Add location' : 'Edit location'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Name (e.g. Downtown)')),
          const SizedBox(height: AppSpacing.md),
          TextField(controller: address, decoration: const InputDecoration(labelText: 'Address')),
          const SizedBox(height: AppSpacing.md),
          Row(children: [
            Expanded(child: TextField(controller: city, decoration: const InputDecoration(labelText: 'City'))),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: TextField(controller: country, decoration: const InputDecoration(labelText: 'Country'))),
          ]),
          if (error != null) Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Text(error!, style: const TextStyle(color: AppColors.error)),
          ),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (name.text.trim().isEmpty) return;
              try {
                final repo = ref.read(locationsRepositoryProvider);
                if (location == null) {
                  await repo.create(businessId: ctx.business['id'], name: name.text.trim(),
                      address: address.text.trim(), city: city.text.trim(), country: country.text.trim());
                } else {
                  await repo.update(location['id'], name: name.text.trim(),
                      address: address.text.trim(), city: city.text.trim(), country: country.text.trim());
                }
                if (c.mounted) Navigator.pop(c, true);
              } on PostgrestException catch (e) {
                setState(() => error = e.message.contains('location_limit_reached')
                    ? 'You\'ve reached your plan\'s location limit.' : e.message);
              }
            },
            child: const Text('Save'),
          ),
        ],
      )),
    );
    if (saved == true) ref.invalidate(locationsProvider);
  }
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}
