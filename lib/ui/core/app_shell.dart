import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import 'app_logo.dart';

/// Owner navigation: rail on wide screens, bottom bar on phones.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});
  final Widget child;

  static const _items = [
    (path: '/dashboard', icon: Icons.dashboard_outlined, selectedIcon: Icons.dashboard, label: 'Dashboard'),
    (path: '/scan', icon: Icons.qr_code_scanner_outlined, selectedIcon: Icons.qr_code_scanner, label: 'Scan'),
    (path: '/customers', icon: Icons.people_outline, selectedIcon: Icons.people, label: 'Customers'),
    (path: '/qr', icon: Icons.qr_code_2_outlined, selectedIcon: Icons.qr_code_2, label: 'QR'),
    (path: '/promotions', icon: Icons.campaign_outlined, selectedIcon: Icons.campaign, label: 'Promotions'),
    (path: '/analytics', icon: Icons.insights_outlined, selectedIcon: Icons.insights, label: 'Analytics'),
    (path: '/billing', icon: Icons.credit_card_outlined, selectedIcon: Icons.credit_card, label: 'Billing'),
    (path: '/settings', icon: Icons.settings_outlined, selectedIcon: Icons.settings, label: 'Settings'),
  ];

  // Bottom bar keeps only the five most-used destinations to avoid crowding phones.
  // Billing stays reachable from Settings on mobile instead of taking a sixth slot.
  static const _mobileIndexes = [0, 1, 2, 3, 7];

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final index = _items.indexWhere((i) => location.startsWith(i.path)).clamp(0, _items.length - 1);
    void go(int i) => context.go(_items[i].path);
    final wide = MediaQuery.sizeOf(context).width >= 800;

    if (wide) {
      return Scaffold(
        body: Row(children: [
          NavigationRail(
            selectedIndex: index,
            onDestinationSelected: go,
            labelType: NavigationRailLabelType.all,
            leading: const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: AppLogo(height: 28, iconOnly: true),
            ),
            destinations: [
              for (final i in _items)
                NavigationRailDestination(
                  icon: Icon(i.icon),
                  selectedIcon: Icon(i.selectedIcon),
                  label: Text(i.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1, color: AppColors.neutral200),
          Expanded(child: child),
        ]),
      );
    }
    final mobileSelected = _mobileIndexes.indexOf(index).clamp(0, _mobileIndexes.length - 1);
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: mobileSelected,
        onDestinationSelected: (i) => go(_mobileIndexes[i]),
        destinations: [
          for (final i in _mobileIndexes)
            NavigationDestination(icon: Icon(_items[i].icon), selectedIcon: Icon(_items[i].selectedIcon), label: _items[i].label),
        ],
      ),
    );
  }
}
