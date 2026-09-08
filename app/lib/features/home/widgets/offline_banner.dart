import 'package:flutter/material.dart';

/// docs/06_MOBILE_SPEC.md §Home behaviour:
///  * "Offline: connectivity banner; all actions that need network are disabled".
///  * "Errors keep cache and show a small banner with retry."
///
/// Both cases are the same strip with a different icon/colour, so they share one widget.
class StatusStrip extends StatelessWidget {
  const StatusStrip({
    super.key,
    required this.message,
    required this.icon,
    this.onRetry,
    this.retryLabel,
    this.tone = StatusTone.neutral,
  });

  final String message;
  final IconData icon;
  final VoidCallback? onRetry;
  final String? retryLabel;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (Color bg, Color fg) = switch (tone) {
      StatusTone.neutral => (
          theme.colorScheme.surfaceContainerHighest,
          theme.colorScheme.onSurfaceVariant
        ),
      StatusTone.warning => (
          theme.colorScheme.errorContainer,
          theme.colorScheme.onErrorContainer
        ),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: theme.textTheme.bodySmall?.copyWith(color: fg)),
          ),
          if (onRetry != null && retryLabel != null)
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: fg,
                // 48 dp target (docs/07 §B2 accessibility).
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: Text(retryLabel!),
            ),
        ],
      ),
    );
  }
}

enum StatusTone { neutral, warning }
