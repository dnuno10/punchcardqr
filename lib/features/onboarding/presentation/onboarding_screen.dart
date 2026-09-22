import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../ui/core/app_logo.dart';
import '../../business/data/business_templates.dart';
import '../../business/data/owner_repository.dart';
import '../../loyalty_program/presentation/card_preview.dart';

/// Business → industry template → program details, with a live preview.
/// Ends by launching the program.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _business = TextEditingController();
  final _program = TextEditingController(text: 'Rewards Card');
  final _reward = TextEditingController(text: 'Free coffee');
  int _punches = 9;
  int _bonus = 0;
  int _templateIndex = 0;
  String _term = 'stamp';
  int _step = 0;
  bool _busy = false;
  bool _rewardTouched = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final c in [_business, _program, _reward]) {
      c.addListener(() => setState(() {}));
    }
    _reward.addListener(() => _rewardTouched = true);
  }

  @override
  void dispose() {
    for (final c in [_business, _program, _reward]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _stepValid => switch (_step) {
        0 => _business.text.trim().isNotEmpty,
        1 => true,
        2 => _program.text.trim().isNotEmpty && _reward.text.trim().isNotEmpty,
        _ => true,
      };

  void _pickTemplate(int i) {
    setState(() {
      _templateIndex = i;
      _term = businessTemplates[i].defaultPunchTerm;
      if (!_rewardTouched || _reward.text.trim().isEmpty) {
        _reward.text = businessTemplates[i].defaultReward;
      }
    });
  }

  Future<void> _launch() async {
    setState(() { _busy = true; _error = null; });
    final t = businessTemplates[_templateIndex];
    try {
      await ref.read(ownerRepositoryProvider).createBusinessWithProgram(NewProgramInput(
        businessName: _business.text.trim(),
        programName: _program.text.trim(),
        punchesRequired: _punches,
        rewardName: _reward.text.trim(),
        punchTerm: _term,
        signupBonus: _bonus,
        primaryColor: t.primaryColor,
        backgroundColor: t.backgroundColor,
        textColor: t.textColor,
        punchColor: t.punchColor,
        punchIconType: t.punchIconType,
        category: t.category,
      ));
      ref.invalidate(ownerContextProvider);
      if (mounted) context.go('/qr');
    } on PostgrestException catch (e) {
      setState(() { _error = e.message; _busy = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = businessTemplates[_templateIndex];
    final preview = CardPreview(
      businessName: _business.text.trim(),
      programName: _program.text.trim(),
      total: _punches,
      filled: (_punches / 3).floor(),
      primary: parseHex(t.primaryColor, AppTheme.seed),
      background: parseHex(t.backgroundColor, Colors.white),
      text: parseHex(t.textColor, Colors.black),
      punchTerm: _term,
      rewardName: _reward.text.trim(),
      punchIconType: t.punchIconType,
    );
    final wide = MediaQuery.sizeOf(context).width >= 900;

    final steps = [
      Step(
        title: const Text('Your business'),
        subtitle: const Text('Tell us the basics'),
        isActive: _step >= 0,
        content: TextField(
          controller: _business,
          decoration: const InputDecoration(labelText: 'Business name', hintText: 'e.g. Blue Bear Coffee'),
        ),
      ),
      Step(
        title: const Text('Industry template'),
        subtitle: const Text('Pick a starting point — you can fine-tune it later'),
        isActive: _step >= 1,
        content: _TemplateGrid(selected: _templateIndex, onSelect: _pickTemplate),
      ),
      Step(
        title: const Text('Loyalty program'),
        subtitle: const Text('How customers earn a reward'),
        isActive: _step >= 2,
        content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: AppSpacing.sm),
          TextField(controller: _program, decoration: const InputDecoration(labelText: 'Program name')),
          const SizedBox(height: AppSpacing.lg),
          TextField(controller: _reward, decoration: const InputDecoration(labelText: 'Reward')),
          const SizedBox(height: AppSpacing.lg),
          Text('${t.defaultPunchTerm[0].toUpperCase()}${t.defaultPunchTerm.substring(1)}es needed: $_punches',
              style: Theme.of(context).textTheme.bodyMedium),
          Slider(value: _punches.toDouble(), min: 3, max: 20, divisions: 17, label: '$_punches',
              onChanged: (v) => setState(() => _punches = v.round())),
          DropdownButtonFormField<String>(
            initialValue: _term,
            decoration: const InputDecoration(labelText: 'Call them'),
            items: [
              for (final term in ['punch', 'stamp', 'star', 'visit', 'point', 'purchase', 'wash'])
                DropdownMenuItem(value: term, child: Text(term)),
            ],
            onChanged: (v) => setState(() => _term = v!),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Signup bonus: $_bonus (Starter plan and up)', style: Theme.of(context).textTheme.bodyMedium),
          Slider(value: _bonus.toDouble(), min: 0, max: 5, divisions: 5, label: '$_bonus',
              onChanged: (v) => setState(() => _bonus = v.round())),
        ]),
      ),
    ];

    final form = Stepper(
      currentStep: _step,
      steps: steps,
      onStepTapped: (i) => setState(() => _step = i.clamp(0, _step)),
      controlsBuilder: (context, d) => Padding(
        padding: const EdgeInsets.only(top: AppSpacing.lg),
        child: Row(children: [
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(140, 48)),
            onPressed: !_stepValid || _busy ? null : (_step == 2 ? _launch : () => setState(() => _step++)),
            child: _busy
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(_step == 2 ? 'Launch card' : 'Continue'),
          ),
          if (_step > 0) ...[
            const SizedBox(width: AppSpacing.sm),
            TextButton(onPressed: () => setState(() => _step--), child: const Text('Back')),
          ],
          if (_error != null) Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: AppSpacing.sm),
              child: Text(_error!, style: const TextStyle(color: AppColors.error)),
            ),
          ),
        ]),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Row(mainAxisSize: MainAxisSize.min, children: const [
          AppLogo(height: 22, iconOnly: true),
          SizedBox(width: AppSpacing.sm),
          Text('Set up your loyalty card'),
        ]),
        actions: [TextButton(onPressed: Supabase.instance.client.auth.signOut, child: const Text('Sign out'))],
      ),
      backgroundColor: AppColors.neutral0,
      body: wide
          ? Row(children: [
              Expanded(flex: 3, child: form),
              Container(width: 1, color: AppColors.neutral200),
              Expanded(flex: 2, child: Center(child: preview)),
            ])
          : ListView(children: [
              form,
              Padding(padding: const EdgeInsets.all(AppSpacing.xl), child: Center(child: preview)),
            ]),
    );
  }
}

class _TemplateGrid extends StatelessWidget {
  const _TemplateGrid({required this.selected, required this.onSelect});
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: businessTemplates.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 168,
        mainAxisExtent: 92,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.sm,
      ),
      itemBuilder: (context, i) {
        final t = businessTemplates[i];
        final isSelected = i == selected;
        final color = parseHex(t.primaryColor, AppColors.blue);
        return InkWell(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          onTap: () => onSelect(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: isSelected ? color.withValues(alpha: 0.08) : Colors.white,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: isSelected ? color : AppColors.neutral200, width: isSelected ? 1.5 : 1),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              CircleAvatar(radius: 16, backgroundColor: color, child: Icon(t.icon, size: 16, color: Colors.white)),
              const SizedBox(height: AppSpacing.xs),
              Text(
                t.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: isSelected ? AppColors.navy : AppColors.neutral600,
                    ),
              ),
            ]),
          ),
        );
      },
    );
  }
}
