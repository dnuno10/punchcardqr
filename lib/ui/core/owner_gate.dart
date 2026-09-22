import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/business/data/owner_repository.dart';
import 'error_view.dart';

/// Sends owners who have not finished onboarding to /onboarding; otherwise shows [child].
class OwnerGate extends ConsumerWidget {
  const OwnerGate({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctx = ref.watch(ownerContextProvider);
    return ctx.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: ErrorView('Could not load your business.', onRetry: () => ref.invalidate(ownerContextProvider))),
      data: (c) {
        if (c == null || c.program == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) { if (context.mounted) context.go('/onboarding'); });
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return child;
      },
    );
  }
}
