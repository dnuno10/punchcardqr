import 'package:flutter/material.dart';

/// Brand mark. Use [iconOnly] in tight spaces (nav rails, app bars).
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.height = 40, this.iconOnly = false});

  final double height;
  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    if (iconOnly) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(height * 0.22),
        child: Image.asset('assets/favicon.png', height: height, width: height, fit: BoxFit.cover),
      );
    }
    return Image.asset('assets/logo.png', height: height, fit: BoxFit.contain);
  }
}
