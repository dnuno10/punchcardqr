import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../ui/core/error_view.dart';
import '../../../ui/core/public_card_frame.dart';
import '../../../ui/core/punch_row.dart';

/// /j/:slug — a customer scans the business's Join QR and gets a card with one tap. No account.
class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key, required this.slug});
  final String slug;

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  late Future<Map<String, dynamic>> _program = callRpcMap(
    'get_public_program',
    {'p_slug': widget.slug},
  );
  final _email = TextEditingController();
  bool _joining = false;
  bool _marketingConsent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    setState(() {
      _joining = true;
      _error = null;
    });
    try {
      final res = await callRpcMap('join_program_client', {
        'p_program_slug': widget.slug,
        'p_marketing_consent': _marketingConsent,
        'p_email': _marketingConsent ? _email.text.trim() : null,
      });
      if (mounted) context.go('/c/${res['token']}?new=1');
    } on AppException catch (e) {
      setState(() {
        _error = e.message;
        _joining = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.neutral0,
    body: FutureBuilder(
      future: _program,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          final msg = snap.error is AppException
              ? (snap.error as AppException).message
              : 'Could not load this program.';
          return ErrorView(
            msg,
            onRetry: () => setState(() {
              _program = callRpcMap('get_public_program', {
                'p_slug': widget.slug,
              });
            }),
          );
        }
        final d = snap.data!;
        final p = d['program'] as Map, b = d['business'] as Map;
        final reward = d['reward'] as Map?;
        final bg = parseHex(p['background_color'], Colors.white);
        final fg = parseHex(p['text_color'], Colors.black87);
        final accent = parseHex(p['primary_color'], AppTheme.seed);
        final punchIcon = p['punch_icon_type'] as String?;
        final coverImage = p['cover_image_url'] as String?;
        final bonus = p['signup_bonus'] as int;
        final total = p['punches_required'] as int;

        return PublicCardFrame(
          background: bg,
          accent: accent,
          coverImageUrl: coverImage,
          child: Column(children: [
            Text(b['name'], textAlign: TextAlign.center,
                style: TextStyle(color: fg.withValues(alpha: 0.7), fontSize: 13, letterSpacing: 1, fontWeight: FontWeight.w600)),
            const SizedBox(height: AppSpacing.xs),
            Text(p['name'], textAlign: TextAlign.center,
                style: TextStyle(color: fg, fontSize: 26, fontWeight: FontWeight.w700)),
            if (reward != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text('Get ${reward['name']} after $total ${p['punch_term']}s',
                  textAlign: TextAlign.center, style: TextStyle(color: fg.withValues(alpha: 0.75), fontSize: 13.5)),
            ],
            const SizedBox(height: AppSpacing.xl),
            PunchRow(total: total, filled: bonus, color: accent, iconType: punchIcon),
            if (bonus > 0) ...[
              const SizedBox(height: AppSpacing.lg),
              Text('Join today and start with $bonus ${p['punch_term']}${bonus > 1 ? 's' : ''}!',
                  textAlign: TextAlign.center, style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 13.5)),
            ],
            const SizedBox(height: AppSpacing.xl),
            InkWell(
              onTap: () => setState(() => _marketingConsent = !_marketingConsent),
              child: Row(children: [
                Checkbox(
                  value: _marketingConsent,
                  activeColor: accent,
                  onChanged: (v) => setState(() => _marketingConsent = v ?? false),
                ),
                Expanded(
                  child: Text('Send me occasional offers and rewards by email',
                      style: TextStyle(color: fg.withValues(alpha: 0.7), fontSize: 12.5)),
                ),
              ]),
            ),
            if (_marketingConsent) ...[
              const SizedBox(height: AppSpacing.xs),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email address', isDense: true),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.error)),
              ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: accent, minimumSize: const Size.fromHeight(52)),
              onPressed: _joining ? null : _join,
              child: _joining
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Get my card'),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('No app. No account.', textAlign: TextAlign.center,
                style: TextStyle(color: fg.withValues(alpha: 0.5), fontSize: 12)),
            if ((p['terms'] as String?)?.isNotEmpty ?? false) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(p['terms'], textAlign: TextAlign.center, style: TextStyle(color: fg.withValues(alpha: 0.5), fontSize: 11.5)),
            ],
          ]),
        );
      },
    ),
  );
}
