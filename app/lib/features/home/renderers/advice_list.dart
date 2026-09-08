import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../../../core/icons.dart';
import '../../../data/models/card.dart';
import '../../../data/models/json.dart';
import 'parts.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../l10n/labels.dart';

/// docs/06_MOBILE_SPEC.md §Renderers — `advice_list`:
/// "icon + title + detail rows (packing grouped per place)".
///
/// Four card types share it and each names its rows differently (docs/02 cards 11
/// `health_advisory.items[]`, 20 `travel_alerts.alerts[]`, 21 `packing_suggestions.places[].items[]`,
/// 27 `planting_guidance.crops[]`), so [AdviceGroup.parse] flattens all four into groups of
/// icon/title/detail rows. Packing is the reason groups exist at all: its rows only make sense
/// under the place they belong to.
class AdviceListRenderer extends StatelessWidget {
  const AdviceListRenderer({super.key, required this.card, this.expanded = false});

  final HomeCard card;

  /// The detail page lists every row and every tip instead of the first few.
  final bool expanded;

  /// Rows shown on the card before "+N more".
  static const int _cardRows = 3;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final theme = Theme.of(context);
    final groups = AdviceGroup.parse(card, l);
    final tips = asStringList(card.data['tips']);
    final total = groups.fold<int>(0, (sum, g) => sum + g.items.length);

    // A group with a heading but no rows is still worth drawing: docs/02 card 21 emits one
    // entry per saved place, and "Panaji — nothing special to pack" is the useful answer.
    final headings = groups.where((g) => g.heading != null).length;
    if (total == 0 && tips.isEmpty && headings == 0) {
      return RendererEmpty(message: l.nothingToFlag);
    }

    var budget = expanded ? total : _cardRows;
    final rendered = <Widget>[];
    for (final group in groups) {
      final take = budget <= 0 ? const <AdviceItem>[] : group.items.take(budget).toList();
      if (group.heading != null) {
        rendered.add(Padding(
          padding: EdgeInsets.only(top: rendered.isEmpty ? 0 : 10, bottom: 6),
          child: Row(
            children: [
              Text(group.heading!,
                  style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
              if (group.subheading != null) ...[
                const SizedBox(width: 6),
                Text(group.subheading!,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ],
          ),
        ));
      }
      if (group.items.isEmpty) {
        rendered.add(Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(group.emptyMessage ?? l.nothingToAdd,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ));
        continue;
      }
      for (final item in take) {
        rendered.add(AdviceRow(item: item, expanded: expanded));
      }
      budget -= take.length;
    }

    final hidden = expanded ? 0 : total - _cardRows;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...rendered,
        if (hidden > 0)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(l.moreItems(hidden),
                style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary)),
          ),
        if (tips.isNotEmpty) ...[
          const SizedBox(height: 8),
          AdviceBullets(lines: tips, max: expanded ? 8 : 2),
        ],
      ],
    );
  }
}

/// One icon + title + detail row.
class AdviceRow extends StatelessWidget {
  const AdviceRow({super.key, required this.item, this.expanded = false});

  final AdviceItem item;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(item.icon, size: 16, color: item.color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall),
                    ),
                    if (item.badge != null) ...[
                      const SizedBox(width: 6),
                      Pill(label: item.badge!, color: item.color, dense: true),
                    ],
                  ],
                ),
                if (item.detail != null && item.detail!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      item.detail!,
                      maxLines: expanded ? 6 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                if (item.tags.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final t in item.tags)
                          Pill(label: Fmt.humanize(t), color: item.color, dense: true),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One row of an advice list.
class AdviceItem {
  const AdviceItem({
    required this.title,
    required this.icon,
    required this.color,
    this.detail,
    this.badge,
    this.tags = const <String>[],
  });

  final String title;
  final IconData icon;
  final Color color;
  final String? detail;
  final String? badge;
  final List<String> tags;
}

/// Rows under an optional heading — one heading per saved place for packing suggestions.
class AdviceGroup {
  const AdviceGroup({
    required this.items,
    this.heading,
    this.subheading,
    this.emptyMessage,
  });

  final List<AdviceItem> items;
  final String? heading;
  final String? subheading;
  final String? emptyMessage;

  static const Color _info = Color(0xFF1565C0);
  static const Color _advisory = Color(0xFFF28C28);
  static const Color _warning = Color(0xFFD32F2F);
  static const Color _ok = Color(0xFF2E7D32);

  /// docs/02 card 11 `level` and card 20 `risk` share one ladder.
  static Color levelColor(String? level) {
    switch (level?.toLowerCase()) {
      case 'warning':
      case 'high':
        return _warning;
      case 'advisory':
      case 'medium':
        return _advisory;
      case 'low':
        return _ok;
      default:
        return _info;
    }
  }

  /// docs/02 card 27 — crop stage → glyph.
  static IconData stageIcon(String? stage) {
    switch (stage) {
      case 'sow':
        return Icons.eco_outlined;
      case 'grow':
        return Icons.grass;
      case 'irrigate':
        return Icons.water_drop_outlined;
      case 'harvest':
        return Icons.agriculture_outlined;
      case 'protect':
        return Icons.shield_outlined;
      default:
        return Icons.spa_outlined;
    }
  }

  static String? _firstOf(List<String> values) => values.isEmpty ? null : values.first;

  static List<Map<String, dynamic>> _rows(Object? raw) => raw is List
      ? raw.map(asMapOrNull).whereType<Map<String, dynamic>>().toList()
      : const <Map<String, dynamic>>[];

  static List<AdviceGroup> parse(HomeCard card, L l) {
    final d = card.data;

    switch (card.type) {
      case 'packing_suggestions':
        // docs/06 §Renderers — "packing grouped per place".
        return <AdviceGroup>[
          for (final place in _rows(d['places']))
            AdviceGroup(
              heading: asStringOrNull(place['place_name']) ?? l.placeFallback,
              subheading: asNum(place['days']) == null
                  ? null
                  : l.nextDays(asInt(place['days']) ?? 0),
              emptyMessage: l.nothingToPack,
              items: <AdviceItem>[
                for (final item in _rows(place['items']))
                  AdviceItem(
                    title: asStringOrNull(item['item']) ?? l.itemFallback,
                    icon: AppIcons.byName(asStringOrNull(item['icon']),
                        fallback: Icons.luggage_outlined),
                    color: _info,
                    detail: asStringOrNull(item['reason']),
                  ),
              ],
            ),
        ];

      case 'travel_alerts':
        return <AdviceGroup>[
          AdviceGroup(
            items: <AdviceItem>[
              for (final alert in _rows(d['alerts']))
                AdviceItem(
                  title: asStringOrNull(alert['place_name']) ?? l.savedPlaceFallback,
                  icon: AppIcons.hazard(_firstOf(asStringList(alert['hazards']))),
                  color: levelColor(asStringOrNull(alert['risk'])),
                  detail: asStringOrNull(alert['detail']),
                  badge: l.riskWithLevel(levelLabel(l, asStringOrNull(alert['risk']) ?? 'low')),
                  tags: asStringList(alert['hazards']),
                ),
            ],
          ),
        ];

      case 'planting_guidance':
        final season = asStringOrNull(d['season']);
        final zone = asStringOrNull(d['zone']);
        return <AdviceGroup>[
          AdviceGroup(
            heading: season == null ? null : l.seasonWithName(seasonLabel(l, season)),
            subheading: zone == null ? null : l.zoneWithName(Fmt.humanize(zone)),
            items: <AdviceItem>[
              for (final crop in _rows(d['crops']))
                AdviceItem(
                  title: asStringOrNull(crop['name']) ?? l.cropFallback,
                  icon: stageIcon(asStringOrNull(crop['stage'])),
                  color: _ok,
                  detail: asStringOrNull(crop['action']),
                  badge: Fmt.humanize(asStringOrNull(crop['stage'])),
                ),
            ],
          ),
        ];

      default:
        // health_advisory and any future card that publishes plain `items[]`.
        return <AdviceGroup>[
          AdviceGroup(
            items: <AdviceItem>[
              for (final item in _rows(d['items']))
                AdviceItem(
                  title: asStringOrNull(item['title']) ?? '',
                  icon: AppIcons.byName(asStringOrNull(item['icon']),
                      fallback: Icons.info_outline),
                  color: levelColor(asStringOrNull(item['level'])),
                  detail: asStringOrNull(item['detail']),
                ),
            ],
          ),
        ];
    }
  }
}
