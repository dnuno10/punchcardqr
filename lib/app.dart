import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class PunchCardApp extends ConsumerWidget {
  const PunchCardApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
        title: 'PunchCardQR',
        theme: AppTheme.light,
        routerConfig: ref.watch(routerProvider),
        debugShowCheckedModeBanner: false,
      );
}
