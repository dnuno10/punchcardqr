import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/analytics/presentation/analytics_screen.dart';
import '../../features/billing/presentation/billing_screen.dart';
import '../../features/customers/presentation/customer_detail_screen.dart';
import '../../features/customers/presentation/customers_screen.dart';
import '../../features/loyalty_program/presentation/program_screen.dart';
import '../../features/locations/presentation/locations_screen.dart';
import '../../features/marketing/presentation/marketing_screen.dart';
import '../../features/promotions/presentation/promotions_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/auth/presentation/auth_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/public_card/presentation/card_screen.dart';
import '../../features/public_join/presentation/join_screen.dart';
import '../../features/recover/presentation/recover_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/qr_center/presentation/qr_center_screen.dart';
import '../../features/scanner/presentation/scan_screen.dart';
import '../../ui/core/app_shell.dart';
import '../../ui/core/owner_gate.dart';

/// Routes that work without an owner session (the customer side).
bool _isPublic(String path) =>
    path.startsWith('/j/') || path.startsWith('/c/') || path.startsWith('/recover');

bool _isAuthPage(String path) => path == '/login' || path == '/signup';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = Supabase.instance.client.auth;
  final refresh = _Refresh(auth.onAuthStateChange);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/dashboard',
    refreshListenable: refresh,
    redirect: (context, state) {
      final path = state.uri.path;
      final signedIn = auth.currentSession != null;
      if (_isPublic(path)) return null;
      if (!signedIn && !_isAuthPage(path)) return '/login';
      if (signedIn && _isAuthPage(path)) return '/dashboard';
      return null;
    },
    routes: [
      // Public — customers
      GoRoute(path: '/j/:slug', builder: (_, s) => JoinScreen(slug: s.pathParameters['slug']!)),
      GoRoute(
        path: '/c/:token',
        builder: (_, s) => CardScreen(token: s.pathParameters['token']!, justJoined: s.uri.queryParameters['new'] == '1'),
      ),
      GoRoute(path: '/recover', builder: (_, _) => const RecoverScreen()),
      GoRoute(path: '/recover/:token', builder: (_, s) => ClaimRecoveryScreen(token: s.pathParameters['token']!)),

      // Owner auth — passwordless (email + 8-digit code); same screen creates the account
      // on first sign-in, so /signup just points here too for any old links/bookmarks.
      GoRoute(path: '/login', builder: (_, _) => const AuthScreen()),
      GoRoute(path: '/signup', redirect: (_, _) => '/login'),
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),

      // Owner app
      ShellRoute(
        builder: (_, _, child) => OwnerGate(child: AppShell(child: child)),
        routes: [
          GoRoute(path: '/dashboard', builder: (_, _) => const DashboardScreen()),
          GoRoute(path: '/program', builder: (_, _) => const ProgramScreen()),
          GoRoute(path: '/program/design', redirect: (_, _) => '/program'),
          GoRoute(path: '/qr', builder: (_, _) => const QrCenterScreen()),
          GoRoute(path: '/scan', builder: (_, _) => const ScanScreen()),
          GoRoute(path: '/customers', builder: (_, _) => const CustomersScreen()),
          GoRoute(path: '/customers/:customerId', builder: (_, s) => CustomerDetailScreen(membershipId: s.pathParameters['customerId']!)),
          GoRoute(path: '/rewards', redirect: (_, _) => '/program'),
          GoRoute(path: '/locations', builder: (_, _) => const LocationsScreen()),
          GoRoute(path: '/marketing', builder: (_, _) => const MarketingScreen()),
          GoRoute(path: '/promotions', builder: (_, _) => const PromotionsScreen()),
          GoRoute(path: '/analytics', builder: (_, _) => const AnalyticsScreen()),
          GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
          GoRoute(path: '/billing', builder: (_, _) => const BillingScreen()),
        ],
      ),
    ],
  );
});

class _Refresh extends ChangeNotifier {
  _Refresh(Stream<dynamic> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }
  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
