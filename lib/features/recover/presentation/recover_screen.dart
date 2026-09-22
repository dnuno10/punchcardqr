import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../ui/core/app_logo.dart';
import '../../../ui/core/error_view.dart';

/// /recover — ask for an emailed link. Answers the same way whether or not the email has cards.
class RecoverScreen extends StatefulWidget {
  const RecoverScreen({super.key});
  @override
  State<RecoverScreen> createState() => _RecoverScreenState();
}

class _RecoverScreenState extends State<RecoverScreen> {
  final _email = TextEditingController();
  bool _busy = false, _sent = false;
  String? _error;

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await callRpcMap('request_card_recovery_client', {
        'p_email': _email.text.trim(),
      });
      setState(() => _sent = true);
    } on AppException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AppColors.neutral0,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const AppLogo(height: 44),
              const SizedBox(height: AppSpacing.xxl),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.xxl),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  border: Border.all(color: AppColors.neutral200),
                ),
                child: _sent
                    ? Column(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          decoration: const BoxDecoration(color: AppColors.greenSurface, shape: BoxShape.circle),
                          child: const Icon(Icons.mark_email_read_outlined, size: 28, color: AppColors.green),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text('Check your email', style: textTheme.headlineSmall, textAlign: TextAlign.center),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'If we have a card for that email, a link is on its way. It expires in 30 minutes.',
                          style: textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.blueSurface,
                            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                          ),
                          child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Icon(Icons.mark_email_unread_outlined, size: 18, color: AppColors.blueDark),
                            SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                'Don\'t see it? Check your spam or junk folder — recovery links sometimes land there.',
                                style: TextStyle(color: AppColors.blueDark, fontSize: 12.5, height: 1.4),
                              ),
                            ),
                          ]),
                        ),
                      ])
                    : Column(mainAxisSize: MainAxisSize.min, children: [
                        Text('Recover your card', style: textTheme.headlineSmall, textAlign: TextAlign.center),
                        const SizedBox(height: AppSpacing.sm),
                        Text('Enter the email you gave the business.', style: textTheme.bodyMedium, textAlign: TextAlign.center),
                        const SizedBox(height: AppSpacing.xl),
                        TextField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline)),
                        ),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.md),
                            child: Text(_error!, style: const TextStyle(color: AppColors.error)),
                          ),
                        const SizedBox(height: AppSpacing.xl),
                        FilledButton(
                          onPressed: _busy ? null : _send,
                          child: _busy
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Email me my card'),
                        ),
                      ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// /recover/:token — one-time link from the email. Rotates the card secrets and opens the new card.
class ClaimRecoveryScreen extends StatefulWidget {
  const ClaimRecoveryScreen({super.key, required this.token});
  final String token;
  @override
  State<ClaimRecoveryScreen> createState() => _ClaimRecoveryScreenState();
}

class _ClaimRecoveryScreenState extends State<ClaimRecoveryScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    _claim();
  }

  Future<void> _claim() async {
    try {
      final res = await callRpcMap('claim_recovery_client', {
        'p_recovery_token': widget.token,
      });
      if (mounted) context.go('/c/${res['token']}');
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.neutral0,
    body: _error != null
        ? ErrorView(_error!)
        : const Center(child: CircularProgressIndicator()),
  );
}
