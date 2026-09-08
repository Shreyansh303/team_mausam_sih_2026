import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../../../data/repositories/home_repo.dart';
import '../../../l10n/gen/app_localizations.dart';

/// docs/06_MOBILE_SPEC.md §Home behaviour — "shows freshness chip 'Updated 12 min ago'".
///
/// It also says *where* the payload came from, because during a demo the difference between a
/// live backend, a cached copy and the bundled sample is exactly what a judge will ask about.
class FreshnessChip extends StatelessWidget {
  const FreshnessChip({
    super.key,
    required this.result,
    this.onRefresh,
    this.live = false,
    this.nowOverride,
  });

  final HomeResult result;
  final VoidCallback? onRefresh;

  /// `true` while `/ws/alerts` is connected — the green dot a judge can point at.
  final bool live;

  /// The demo clock, when one is set (the demo sheet's own, or an admin `now_override`
  /// frame off `/ws/alerts`). Ages are measured against it, because the payload's
  /// `freshness` block is stamped with the demo clock too — without this the chip reads
  /// "Updated 16 h ago" the moment a judge sets the clock to 07:30.
  final String? nowOverride;

  String _label(L l) {
    final reference = Fmt.instant(nowOverride);
    final minutes = Fmt.minutesSince(result.home.newestFreshness, now: reference) ??
        _minutesSinceStored(reference);
    if (minutes == null) return l.loading;
    if (minutes < 1) return l.updatedJustNow;
    if (minutes < 60) return l.updatedMinutesAgo(minutes);
    return l.updatedHoursAgo(minutes ~/ 60);
  }

  int? _minutesSinceStored(DateTime? reference) {
    final storedAt = result.storedAt;
    if (storedAt == null) return null;
    final m = (reference ?? DateTime.now().toUtc())
        .difference(storedAt.toUtc())
        .inMinutes;
    return m < 0 ? 0 : m;
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final theme = Theme.of(context);

    final (IconData icon, String suffix) = switch (result.source) {
      HomeSource.network => (Icons.cloud_done_outlined, ''),
      HomeSource.cache => (Icons.save_outlined, ' · ${l.cachedSuffix}'),
      HomeSource.fixture => (Icons.science_outlined, ' · ${l.sampleDataBadge}'),
    };

    return Row(
      children: [
        if (live) ...[
          Semantics(
            label: l.liveUpdates,
            child: Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: Color(0xFF2E7D32),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 5),
        ],
        Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            '${_label(l)}$suffix',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        if (onRefresh != null) ...[
          const SizedBox(width: 4),
          InkWell(
            onTap: onRefresh,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.refresh,
                  size: 14, color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ],
    );
  }
}
