import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme.dart';
import '../../../data/models/warning.dart';
import '../../../l10n/gen/app_localizations.dart';

/// docs/06_MOBILE_SPEC.md §Home behaviour — "Banner: shown when `banner != null`; tap scrolls
/// to pinned warnings; Share button."
///
/// The arrival animation is mandatory per docs/06 §Packages (the pinned-warning arrival), so the
/// banner slides and fades in even on a cold load; B2 replays it on `warning_issued` over the
/// WebSocket.
class WarningBanner extends StatelessWidget {
  const WarningBanner({
    super.key,
    required this.banner,
    this.onTap,
    this.onShare,
  });

  final HomeBanner banner;
  final VoidCallback? onTap;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final theme = Theme.of(context);
    final color = _parseHex(banner.colorHex) ?? AppTheme.warningSeverityColor(banner.severity);

    return Semantics(
      liveRegion: true,
      label: '${banner.severity} warning. ${banner.title}',
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    banner.title,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
                if (onShare != null)
                  IconButton(
                    onPressed: onShare,
                    tooltip: l.share,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.share_outlined, color: Colors.white, size: 18),
                  ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 260.ms)
        .slideY(begin: -0.35, end: 0, duration: 320.ms, curve: Curves.easeOutCubic);
  }

  static Color? _parseHex(String? hex) {
    if (hex == null) return null;
    final cleaned = hex.replaceFirst('#', '');
    if (cleaned.length != 6) return null;
    final value = int.tryParse(cleaned, radix: 16);
    return value == null ? null : Color(0xFF000000 | value);
  }
}
