import 'package:flutter/material.dart';

import '../../../ui/core/punch_row.dart';

/// Phone-shaped mock of the customer card. Used by onboarding and the design editor.
class CardPreview extends StatelessWidget {
  const CardPreview({
    super.key,
    required this.businessName,
    required this.programName,
    required this.total,
    required this.filled,
    required this.primary,
    required this.background,
    required this.text,
    required this.punchTerm,
    this.rewardName,
    this.punchIconType,
  });
  final String businessName, programName, punchTerm;
  final String? rewardName;
  final String? punchIconType;
  final int total, filled;
  final Color primary, background, text;

  @override
  Widget build(BuildContext context) => Container(
        width: 288,
        padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: text.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 18),
          Text(
            (businessName.isEmpty ? 'YOUR BUSINESS' : businessName).toUpperCase(),
            style: TextStyle(color: text.withValues(alpha: 0.6), letterSpacing: 1.4, fontSize: 11, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            programName.isEmpty ? 'Rewards Card' : programName,
            textAlign: TextAlign.center,
            style: TextStyle(color: text, fontSize: 21, fontWeight: FontWeight.w700, height: 1.2),
          ),
          const SizedBox(height: 20),
          PunchRow(total: total, filled: filled, color: primary, size: 22, iconType: punchIconType),
          const SizedBox(height: 14),
          Text('$filled / $total ${punchTerm}s', style: TextStyle(color: text, fontWeight: FontWeight.w600, fontSize: 13)),
          if (rewardName != null && rewardName!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Reward: $rewardName',
                style: TextStyle(color: text.withValues(alpha: 0.65), fontSize: 12), textAlign: TextAlign.center),
          ],
          const SizedBox(height: 20),
          Container(
            height: 88,
            width: 88,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: text.withValues(alpha: 0.08)),
            ),
            child: Icon(Icons.qr_code_2, size: 64, color: text.withValues(alpha: 0.85)),
          ),
        ]),
      );
}
