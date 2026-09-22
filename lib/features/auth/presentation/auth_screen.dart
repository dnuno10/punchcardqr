import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../ui/core/app_logo.dart';

const _codeLength = 8;

/// Owner sign-in. Passwordless: email + an 8-digit code sent to that email.
/// Covers both sign-up and sign-in — Supabase creates the account on first use.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailForm = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _code = TextEditingController();
  bool _busy = false;
  bool _codeSent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (!_emailForm.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });
    try {
      await Supabase.instance.client.auth.signInWithOtp(
        email: _email.text.trim(),
        shouldCreateUser: true,
      );
      if (mounted) setState(() => _codeSent = true);
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyCode() async {
    if (_code.text.trim().length != _codeLength) {
      setState(() => _error = 'Enter the $_codeLength-digit code.');
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      await Supabase.instance.client.auth.verifyOTP(
        email: _email.text.trim(),
        token: _code.text.trim(),
        type: OtpType.email,
      );
      // The router redirects to /dashboard when the session appears.
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _editEmail() => setState(() { _codeSent = false; _code.clear(); _error = null; });

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
              const AppLogo(height: 88),
              const SizedBox(height: AppSpacing.xxl),
              Container(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  border: Border.all(color: AppColors.neutral200),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(
                    _codeSent ? 'Check your email' : 'Sign in to PunchCardQR',
                    style: textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _codeSent
                        ? 'We sent an 8-digit code to ${_email.text.trim()}'
                        : 'Enter your work email — we\'ll send you a secure sign-in code, no password needed.',
                    style: textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  if (!_codeSent) ...[
                    Form(
                      key: _emailForm,
                      child: TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(
                          labelText: 'Email address',
                          prefixIcon: Icon(Icons.mail_outline),
                        ),
                        validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                        onFieldSubmitted: (_) => _sendCode(),
                      ),
                    ),
                  ] else ...[
                    Text('8-DIGIT CODE', style: Theme.of(context).textTheme.labelSmall),
                    const SizedBox(height: AppSpacing.sm),
                    _PinCodeField(controller: _code, onCompleted: (_) => _verifyCode()),
                    const SizedBox(height: AppSpacing.md),
                    const _SpamNotice(),
                  ],
                  if (_error != null) Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.md),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.errorSurface,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      ),
                      child: Row(children: [
                        const Icon(Icons.error_outline, size: 18, color: AppColors.error),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13))),
                      ]),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  FilledButton(
                    onPressed: _busy ? null : (_codeSent ? _verifyCode : _sendCode),
                    child: _busy
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(_codeSent ? 'Verify & sign in' : 'Send code'),
                  ),
                  if (_codeSent) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      TextButton(onPressed: _busy ? null : _sendCode, child: const Text('Resend code')),
                      const Text('·', style: TextStyle(color: AppColors.neutral300)),
                      TextButton(onPressed: _busy ? null : _editEmail, child: const Text('Use a different email')),
                    ]),
                  ],
                ]),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Enterprise-grade loyalty infrastructure for restaurants, cafes, salons, gyms and retail.',
                style: textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _PinCodeField extends StatelessWidget {
  const _PinCodeField({required this.controller, required this.onCompleted});
  final TextEditingController controller;
  final ValueChanged<String> onCompleted;

  static const _separatorWidth = 6.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final boxSize = ((constraints.maxWidth - _separatorWidth * (_codeLength - 1)) / _codeLength).clamp(32.0, 44.0);
      final defaultTheme = PinTheme(
        width: boxSize,
        height: boxSize,
        textStyle: TextStyle(fontSize: boxSize * 0.42, fontWeight: FontWeight.w700, color: AppColors.navy),
        decoration: BoxDecoration(
          color: AppColors.neutral50,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          border: Border.all(color: AppColors.neutral300),
        ),
      );
      return Pinput(
        length: _codeLength,
        controller: controller,
        autofocus: true,
        defaultPinTheme: defaultTheme,
        focusedPinTheme: defaultTheme.copyDecorationWith(
          border: Border.all(color: AppColors.blue, width: 1.5),
          color: Colors.white,
        ),
        submittedPinTheme: defaultTheme.copyDecorationWith(
          border: Border.all(color: AppColors.blue),
          color: AppColors.blueSurface,
        ),
        separatorBuilder: (index) => const SizedBox(width: _separatorWidth),
        onCompleted: onCompleted,
      );
    });
  }
}

class _SpamNotice extends StatelessWidget {
  const _SpamNotice();

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.blueSurface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.mark_email_unread_outlined, size: 18, color: AppColors.blueDark),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Don\'t see it? Check your spam or junk folder — the code sometimes lands there.',
              style: TextStyle(color: AppColors.blueDark, fontSize: 12.5, height: 1.4),
            ),
          ),
        ]),
      );
}
