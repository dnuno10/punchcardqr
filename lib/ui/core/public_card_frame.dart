import 'package:flutter/material.dart';

/// Shared "physical card" chrome for the customer-facing pages (join + card):
/// a page background, a centered rounded card, and an optional cover banner
/// (business photo, or a gradient fallback built from the brand color).
class PublicCardFrame extends StatelessWidget {
  const PublicCardFrame({
    super.key,
    required this.background,
    required this.accent,
    required this.child,
    this.coverImageUrl,
  });

  final Color background;
  final Color accent;
  final String? coverImageUrl;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final hasCover = coverImageUrl != null && coverImageUrl!.isNotEmpty;
    return ColoredBox(
      color: background,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    SizedBox(
                      height: 120,
                      width: double.infinity,
                      child: hasCover
                          ? Image.network(
                              coverImageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => _gradientBanner(accent),
                            )
                          : _gradientBanner(accent),
                    ),
                    Padding(padding: const EdgeInsets.fromLTRB(24, 24, 24, 28), child: child),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _gradientBanner(Color accent) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [accent, Color.lerp(accent, Colors.black, 0.35)!],
          ),
        ),
      );
}
