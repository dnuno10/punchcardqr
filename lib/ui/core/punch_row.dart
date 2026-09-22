import 'package:flutter/material.dart';

/// Maps the `punch_icon_type` value stored on a loyalty program to a
/// concrete Material icon pair (filled / outlined) used for each stamp.
(IconData, IconData) punchIconsFor(String? type) => switch (type) {
      'star' => (Icons.star, Icons.star_border),
      'heart' => (Icons.favorite, Icons.favorite_border),
      'coffee' => (Icons.local_cafe, Icons.local_cafe_outlined),
      'dumbbell' => (Icons.fitness_center, Icons.fitness_center),
      'paw' => (Icons.pets, Icons.pets),
      'scissors' => (Icons.content_cut, Icons.content_cut),
      'car' => (Icons.local_car_wash, Icons.local_car_wash),
      'leaf' => (Icons.eco, Icons.eco_outlined),
      'gift' => (Icons.card_giftcard, Icons.card_giftcard),
      'diamond' => (Icons.diamond, Icons.diamond_outlined),
      'bolt' => (Icons.bolt, Icons.bolt),
      _ => (Icons.circle, Icons.circle_outlined),
    };

/// Row of filled / empty punch marks, shared by the join page, the card and the designer preview.
class PunchRow extends StatelessWidget {
  const PunchRow({
    super.key,
    required this.total,
    required this.filled,
    required this.color,
    this.size = 28,
    this.iconType,
  });

  final int total;
  final int filled;
  final Color color;
  final double size;
  final String? iconType;

  @override
  Widget build(BuildContext context) {
    final (filledIcon, outlineIcon) = punchIconsFor(iconType);
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < total; i++)
          Icon(
            i < filled ? filledIcon : outlineIcon,
            size: size,
            color: i < filled ? color : color.withValues(alpha: 0.32),
          ),
      ],
    );
  }
}
