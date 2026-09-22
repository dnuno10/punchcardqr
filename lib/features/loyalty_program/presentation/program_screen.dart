import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../ui/core/punch_row.dart';
import '../../../ui/core/section_header.dart';
import '../../business/data/owner_repository.dart';
import 'card_preview.dart';

const _punchIconOptions = [
  'circle', 'star', 'heart', 'coffee', 'dumbbell', 'paw', 'scissors', 'car', 'leaf', 'gift', 'diamond', 'bolt',
];

/// Edit the loyalty program, its reward and its design with a live preview.
class ProgramScreen extends ConsumerStatefulWidget {
  const ProgramScreen({super.key});
  @override
  ConsumerState<ProgramScreen> createState() => _ProgramScreenState();
}

class _ProgramScreenState extends ConsumerState<ProgramScreen> {
  final _name = TextEditingController(), _desc = TextEditingController(), _terms = TextEditingController();
  final _reward = TextEditingController(), _rewardDesc = TextEditingController();
  final _primary = TextEditingController(), _bg = TextEditingController(), _text = TextEditingController();
  final _punchColor = TextEditingController();
  int _punches = 9, _bonus = 0, _expiry = 0;
  String _term = 'punch';
  String _punchIcon = 'circle';
  bool _loaded = false, _busy = false;
  String? _msg;

  static const _expiryOptions = [0, 7, 14, 30, 60, 90];

  void _load(OwnerContext c) {
    if (_loaded) return;
    _loaded = true;
    final p = c.program!, r = c.reward;
    _name.text = p['name']; _desc.text = p['description'] ?? ''; _terms.text = p['terms'] ?? '';
    _punches = p['punches_required']; _bonus = p['signup_bonus']; _term = p['punch_term'];
    _primary.text = p['primary_color']; _bg.text = p['background_color']; _text.text = p['text_color'];
    _punchColor.text = (p['punch_color'] as String?) ?? p['primary_color'];
    _punchIcon = (p['punch_icon_type'] as String?) ?? 'circle';
    _reward.text = r?['name'] ?? ''; _rewardDesc.text = r?['description'] ?? '';
    _expiry = _expiryOptions.contains(r?['expiration_days']) ? r!['expiration_days'] : 0;
    for (final c in [_name, _reward, _primary, _bg, _text, _punchColor]) { c.addListener(() => setState(() {})); }
  }

  Future<void> _save(OwnerContext c) async {
    setState(() { _busy = true; _msg = null; });
    final client = ref.read(supabaseProvider);
    try {
      await client.from('loyalty_programs').update({
        'name': _name.text.trim(), 'description': _desc.text.trim(), 'terms': _terms.text.trim(),
        'punches_required': _punches, 'punch_term': _term, 'signup_bonus': _bonus,
        'primary_color': _primary.text.trim(), 'background_color': _bg.text.trim(), 'text_color': _text.text.trim(),
        'punch_color': _punchColor.text.trim(), 'punch_icon_type': _punchIcon,
      }).eq('id', c.program!['id']);
      final reward = {
        'name': _reward.text.trim(), 'description': _rewardDesc.text.trim(),
        'punch_threshold': _punches, 'expiration_days': _expiry == 0 ? null : _expiry,
      };
      if (c.reward != null) {
        await client.from('program_rewards').update(reward).eq('id', c.reward!['id']);
      } else {
        await client.from('program_rewards').insert({...reward, 'business_id': c.business['id'], 'program_id': c.program!['id']});
      }
      ref.invalidate(ownerContextProvider);
      setState(() => _msg = 'Saved.');
    } on PostgrestException catch (e) {
      setState(() => _msg = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(ownerContextProvider).value;
    if (c?.program == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    _load(c!);
    final wide = MediaQuery.sizeOf(context).width >= 900;

    final form = ListView(padding: const EdgeInsets.all(AppSpacing.xl), children: [
      const SectionHeader(title: 'Program details', subtitle: 'What customers see on their card'),
      TextField(controller: _name, decoration: const InputDecoration(labelText: 'Program name')),
      const SizedBox(height: AppSpacing.md),
      TextField(controller: _desc, decoration: const InputDecoration(labelText: 'Description')),
      const SizedBox(height: AppSpacing.xl),
      const SectionHeader(title: 'Reward'),
      TextField(controller: _reward, decoration: const InputDecoration(labelText: 'Reward name')),
      const SizedBox(height: AppSpacing.md),
      TextField(controller: _rewardDesc, decoration: const InputDecoration(labelText: 'Reward description')),
      const SizedBox(height: AppSpacing.md),
      DropdownButtonFormField<int>(
        initialValue: _expiry,
        decoration: const InputDecoration(labelText: 'Reward expires'),
        items: [for (final d in _expiryOptions) DropdownMenuItem(value: d, child: Text(d == 0 ? 'Never' : '$d days'))],
        onChanged: (v) => setState(() => _expiry = v!),
      ),
      const SizedBox(height: AppSpacing.xl),
      const SectionHeader(title: 'Punches'),
      Text('Punches required: $_punches (applies to new punches)', style: Theme.of(context).textTheme.bodyMedium),
      Slider(value: _punches.toDouble(), min: 3, max: 20, divisions: 17,
          onChanged: (v) => setState(() => _punches = v.round())),
      DropdownButtonFormField<String>(
        initialValue: _term,
        decoration: const InputDecoration(labelText: 'Terminology'),
        items: [for (final t in ['punch', 'stamp', 'star', 'visit', 'point', 'purchase', 'wash']) DropdownMenuItem(value: t, child: Text(t))],
        onChanged: (v) => setState(() => _term = v!),
      ),
      const SizedBox(height: AppSpacing.md),
      Text('Signup bonus: $_bonus (Starter plan and up)', style: Theme.of(context).textTheme.bodyMedium),
      Slider(value: _bonus.toDouble(), min: 0, max: 5, divisions: 5, onChanged: (v) => setState(() => _bonus = v.round())),
      const SizedBox(height: AppSpacing.xl),
      const SectionHeader(title: 'Design', subtitle: 'Colors and stamp icon shown to customers'),
      Row(children: [
        for (final (ctl, label) in [(_primary, 'Accent'), (_bg, 'Background'), (_text, 'Text')])
          Expanded(child: Padding(padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: TextField(controller: ctl, decoration: InputDecoration(labelText: '$label #hex')))),
      ]),
      const SizedBox(height: AppSpacing.md),
      TextField(controller: _punchColor, decoration: const InputDecoration(labelText: 'Punch icon color #hex')),
      const SizedBox(height: AppSpacing.md),
      Text('Stamp icon', style: Theme.of(context).textTheme.bodyMedium),
      const SizedBox(height: AppSpacing.sm),
      Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
        for (final option in _punchIconOptions)
          ChoiceChip(
            avatar: Icon(punchIconsFor(option).$1, size: 16),
            label: Text(option),
            selected: _punchIcon == option,
            onSelected: (_) => setState(() => _punchIcon = option),
          ),
      ]),
      const SizedBox(height: AppSpacing.xl),
      TextField(controller: _terms, maxLines: 3, decoration: const InputDecoration(labelText: 'Terms & conditions')),
      const SizedBox(height: AppSpacing.xl),
      FilledButton(onPressed: _busy ? null : () => _save(c), child: Text(_busy ? 'Saving…' : 'Save changes')),
      if (_msg != null) Padding(
        padding: const EdgeInsets.only(top: AppSpacing.sm),
        child: Text(_msg!, style: TextStyle(color: _msg == 'Saved.' ? AppColors.green : AppColors.error)),
      ),
    ]);

    final preview = CardPreview(
      businessName: c.business['name'], programName: _name.text, total: _punches, filled: (_punches / 3).floor(),
      primary: parseHex(_primary.text, AppTheme.seed), background: parseHex(_bg.text, Colors.white),
      text: parseHex(_text.text, Colors.black), punchTerm: _term, rewardName: _reward.text,
      punchIconType: _punchIcon,
    );

    return Scaffold(
      backgroundColor: AppColors.neutral0,
      appBar: AppBar(title: const Text('Program')),
      body: wide
          ? Row(children: [
              Expanded(flex: 3, child: form),
              Container(width: 1, color: AppColors.neutral200),
              Expanded(flex: 2, child: Center(child: preview)),
            ])
          : ListView(children: [
              SizedBox(height: 1100, child: form),
              Padding(padding: const EdgeInsets.all(AppSpacing.xl), child: Center(child: preview)),
            ]),
    );
  }
}
