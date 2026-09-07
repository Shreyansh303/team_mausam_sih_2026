import 'package:flutter/material.dart';

import '../../../data/models/card.dart';

/// docs/06_MOBILE_SPEC.md §Card shell — "reason chips (up to 2, tappable → why sheet)".
///
/// The reason text is written by the engine (docs/03 §explainability), e.g.
/// "Because you follow Parent" / "An orange thunderstorm warning is active".
class ReasonChips extends StatelessWidget {
  const ReasonChips({
    super.key,
    required this.reasons,
    this.max = 2,
    this.onTap,
  });

  final List<Reason> reasons;
  final int max;
  final VoidCallback? onTap;

  static IconData iconFor(String code) {
    if (code.startsWith('persona:')) return Icons.person_outline;
    if (code.startsWith('urgency:')) return Icons.priority_high;
    if (code.startsWith('time:')) return Icons.schedule;
    if (code.startsWith('season:')) return Icons.calendar_month_outlined;
    if (code.startsWith('learn:')) return Icons.auto_awesome_outlined;
    if (code.startsWith('data:')) return Icons.insights_outlined;
    return Icons.info_outline;
  }

  @override
  Widget build(BuildContext context) {
    if (reasons.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final shown = reasons.take(max).toList();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final reason in shown)
          ActionChip(
            onPressed: onTap,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            avatar: Icon(iconFor(reason.code), size: 15),
            label: Text(reason.text, style: theme.textTheme.labelSmall),
            side: BorderSide(color: theme.colorScheme.outlineVariant),
            backgroundColor: Colors.transparent,
          ),
        if (reasons.length > shown.length)
          ActionChip(
            onPressed: onTap,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            label: Text('+${reasons.length - shown.length}', style: theme.textTheme.labelSmall),
            side: BorderSide(color: theme.colorScheme.outlineVariant),
            backgroundColor: Colors.transparent,
          ),
      ],
    );
  }
}
