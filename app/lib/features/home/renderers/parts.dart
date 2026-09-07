// Small building blocks shared by the B2a renderers (gauge, timeline, alert, sea, tides…).
//
// They exist so every renderer draws a "stat" or a "pill" the same way — docs/06 §Renderers
// describes the same vocabulary (badges, pills, bullets) across several kinds.

import 'package:flutter/material.dart';

/// A label above a value, used for the secondary numbers under a chart or gauge.
class StatCell extends StatelessWidget {
  const StatCell({super.key, required this.label, required this.value, this.icon, this.color});

  final String label;
  final String value;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 3),
            ],
            Text(
              label,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 1),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(color: color),
        ),
      ],
    );
  }
}

/// A rounded, tinted label — sea state, verdict, severity level, "swim ok" and friends.
class Pill extends StatelessWidget {
  const Pill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.filled = false,
    this.dense = false,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final bool filled;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = filled ? Colors.white : color;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 7 : 10, vertical: dense ? 2 : 4),
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
        border: filled ? null : Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 11 : 13, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: (dense ? theme.textTheme.labelSmall : theme.textTheme.labelMedium)
                ?.copyWith(color: fg, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// A bulleted advice list — `advice[]` on the alert cards, `tips[]` on planting guidance.
class AdviceBullets extends StatelessWidget {
  const AdviceBullets({super.key, required this.lines, this.max = 4, this.color});

  final List<String> lines;
  final int max;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shown = lines.take(max).toList();
    if (shown.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in shown)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 5, right: 7),
                  child: Icon(Icons.circle,
                      size: 5, color: color ?? theme.colorScheme.onSurfaceVariant),
                ),
                Expanded(child: Text(line, style: theme.textTheme.bodySmall)),
              ],
            ),
          ),
      ],
    );
  }
}

/// "No … data." placeholder, so a renderer never shows an empty box on a thin payload.
class RendererEmpty extends StatelessWidget {
  const RendererEmpty({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      message,
      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
    );
  }
}
