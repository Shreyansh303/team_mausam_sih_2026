import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../../../core/icons.dart';
import '../../../data/models/card.dart';
import '../../../data/models/json.dart';
import 'parts.dart';

/// docs/06_MOBILE_SPEC.md §Renderers — `alert`:
/// "severity tile with level, peak time, advice bullets".
///
/// Four card types share it — docs/02 cards 15 `heat_alert`, 23 `rain_alert`, 26 `frost_alert`
/// and 30 `storm_fog_alert` — and only two of them ever appear in `docs/fixtures/` (the frost
/// and heatwave gates need `?scenario=frost` / `?scenario=heatwave`). [AlertSpec.of] therefore
/// reads each card strictly from the keys docs/02 publishes and treats every one of them as
/// optional, so a card that arrives from a live backend with a thinner payload still draws.
class AlertRenderer extends StatelessWidget {
  const AlertRenderer({super.key, required this.card, this.expanded = false});

  final HomeCard card;

  /// The detail page shows every advice line and every stat.
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spec = AlertSpec.of(card);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AlertTile(spec: spec),
        if (spec.stats.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 20,
            runSpacing: 8,
            children: [
              for (final s in (expanded ? spec.stats : spec.stats.take(4)))
                StatCell(label: s.label, value: s.value),
            ],
          ),
        ],
        if (spec.detail != null) ...[
          const SizedBox(height: 10),
          Text(spec.detail!,
              maxLines: expanded ? 10 : 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall),
        ],
        if (spec.advice.isNotEmpty) ...[
          const SizedBox(height: 10),
          AdviceBullets(lines: spec.advice, max: expanded ? 8 : 3, color: spec.color),
        ],
      ],
    );
  }
}

/// The coloured severity tile at the top of an alert card.
class AlertTile extends StatelessWidget {
  const AlertTile({super.key, required this.spec});

  final AlertSpec spec;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: spec.color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: spec.color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: spec.color, shape: BoxShape.circle),
            child: Icon(spec.icon, size: 20, color: Colors.white),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  spec.level,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(color: spec.color, fontWeight: FontWeight.w700),
                ),
                if (spec.when != null)
                  Text(
                    spec.when!,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          // docs/02 — `warning: true` means an IMD/admin warning of this hazard is in force,
          // which is a stronger claim than the app's own threshold and is labelled as such.
          if (spec.officialWarning)
            Pill(
              label: 'Warning in force',
              color: spec.color,
              icon: Icons.campaign_outlined,
              dense: true,
            ),
        ],
      ),
    );
  }
}

/// One alert card normalised to a level, a time phrase, stats and advice.
class AlertSpec {
  const AlertSpec({
    required this.level,
    required this.color,
    required this.icon,
    this.when,
    this.detail,
    this.officialWarning = false,
    this.stats = const <KeyValue>[],
    this.advice = const <String>[],
  });

  final String level;
  final Color color;
  final IconData icon;
  final String? when;
  final String? detail;
  final bool officialWarning;
  final List<KeyValue> stats;
  final List<String> advice;

  static const Color _green = Color(0xFF2E7D32);
  static const Color _yellow = Color(0xFFF5C518);
  static const Color _orange = Color(0xFFF28C28);
  static const Color _red = Color(0xFFD32F2F);
  static const Color _purple = Color(0xFF7B1FA2);
  static const Color _blue = Color(0xFF1565C0);

  /// docs/02 — every alert card's own ladder, lowest first.
  static Color levelColor(String? level) {
    switch (level?.toLowerCase()) {
      case 'none':
        return _green;
      case 'light':
      case 'low':
      case 'caution':
      case 'watch':
        return _yellow;
      case 'moderate':
      case 'extreme_caution':
      case 'warning':
        return _orange;
      case 'heavy':
      case 'high':
      case 'danger':
      case 'severe':
        return _red;
      case 'very_heavy':
      case 'extreme_danger':
        return _purple;
      default:
        return _blue;
    }
  }

  static AlertSpec of(HomeCard card) {
    final d = card.data;
    final advice = asStringList(d['advice']);
    final official = asBool(d['warning']);

    switch (card.type) {
      case 'heat_alert':
        final level = asStringOrNull(d['level']) ?? 'caution';
        final peak = asStringOrNull(d['peak_time']);
        return AlertSpec(
          level: Fmt.humanize(level),
          color: levelColor(level),
          icon: Icons.thermostat,
          when: peak == null ? null : 'Peaks around ${Fmt.time(peak)}',
          officialWarning: official,
          stats: <KeyValue>[
            if (asNum(d['feels_like_c']) != null)
              KeyValue('Feels like', Fmt.temp(asNum(d['feels_like_c']))),
            if (asNum(d['temp_c']) != null) KeyValue('Air temp', Fmt.temp(asNum(d['temp_c']))),
            if (asNum(d['heat_index_c']) != null)
              KeyValue('Heat index', Fmt.temp(asNum(d['heat_index_c']))),
          ],
          advice: advice,
        );

      case 'frost_alert':
        final risk = asStringOrNull(d['risk']) ?? 'none';
        final night = asStringOrNull(d['expected_night']);
        return AlertSpec(
          level: '${Fmt.humanize(risk)} frost risk',
          color: levelColor(risk),
          icon: Icons.ac_unit,
          when: night == null ? null : 'Expected ${Fmt.dayLong(night)} night',
          officialWarning: official,
          stats: <KeyValue>[
            if (asNum(d['tmin_c']) != null) KeyValue('Min temp', Fmt.temp(asNum(d['tmin_c']))),
            if (asNum(d['wind_kph']) != null) KeyValue('Wind', Fmt.kph(asNum(d['wind_kph']))),
            if (asNum(d['cloud_pct']) != null)
              KeyValue('Cloud', Fmt.pct(asNum(d['cloud_pct']))),
          ],
          advice: advice,
        );

      case 'rain_alert':
        final intensity = asStringOrNull(d['intensity']) ?? 'light';
        final start = asStringOrNull(d['next_rain_start']);
        final end = asStringOrNull(d['next_rain_end']);
        final peak = asStringOrNull(d['peak_time']);
        final when = <String>[
          if (start != null) 'From ${Fmt.time(start)}',
          if (end != null) 'until ${Fmt.time(end)}',
          if (peak != null) '· peak ${Fmt.time(peak)}',
        ].join(' ');
        return AlertSpec(
          level: '${Fmt.humanize(intensity)} rain',
          color: levelColor(intensity),
          icon: Icons.water_drop_outlined,
          when: when.isEmpty ? null : when,
          officialWarning: official,
          stats: <KeyValue>[
            if (asNum(d['peak_prob_pct']) != null)
              KeyValue('Peak chance', Fmt.pct(asNum(d['peak_prob_pct']))),
            if (asNum(d['expected_mm']) != null)
              KeyValue('Expected', Fmt.mm(asNum(d['expected_mm']))),
          ],
          advice: advice,
        );

      case 'storm_fog_alert':
        final level = asStringOrNull(d['level']) ?? 'watch';
        final hazard = asStringOrNull(d['hazard']);
        final window = asMapOrNull(d['window']);
        final start = asStringOrNull(window?['start']);
        final end = asStringOrNull(window?['end']);
        return AlertSpec(
          level: '${Fmt.humanize(hazard ?? 'hazard')} ${level.toLowerCase()}',
          color: levelColor(level),
          icon: AppIcons.hazard(hazard),
          when: start == null ? null : '${Fmt.time(start)} – ${Fmt.time(end)}',
          detail: asStringOrNull(d['detail']),
          officialWarning: official,
          advice: advice,
        );
    }

    // Unknown alert card: show whatever level-ish string it carries.
    final level =
        asStringOrNull(d['level']) ?? asStringOrNull(d['risk']) ?? asStringOrNull(d['intensity']);
    return AlertSpec(
      level: Fmt.humanize(level ?? 'Alert'),
      color: levelColor(level),
      icon: Icons.warning_amber_rounded,
      detail: asStringOrNull(d['detail']),
      officialWarning: official,
      advice: advice,
    );
  }
}
