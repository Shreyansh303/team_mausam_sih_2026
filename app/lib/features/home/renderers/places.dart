import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../../../core/icons.dart';
import '../../../core/theme.dart';
import '../../../data/models/card.dart';
import '../../../data/models/json.dart';
import 'parts.dart';

/// docs/06_MOBILE_SPEC.md §Renderers — `places`:
/// "horizontal cards per saved place (local time, temp, icon, hi/lo, severity dot)".
///
/// docs/02 card 19 `saved_places`. `local_time` is the place's own wall clock, already carrying
/// its offset (docs/04 preamble), so it is printed as-is — a traveller with Panaji saved sees
/// Panaji's time, never the phone's.
class PlacesRenderer extends StatelessWidget {
  const PlacesRenderer({super.key, required this.card});

  final HomeCard card;

  static List<SavedPlaceView> parse(HomeCard card) {
    final raw = card.data['places'];
    if (raw is! List) return const <SavedPlaceView>[];
    final out = <SavedPlaceView>[];
    for (final item in raw) {
      final m = asMapOrNull(item);
      if (m == null) continue;
      out.add(SavedPlaceView.fromJson(m));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final places = parse(card);
    if (places.isEmpty) {
      return const RendererEmpty(message: 'No saved places yet.');
    }

    return SizedBox(
      height: 152,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: places.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) => PlaceTile(place: places[i]),
      ),
    );
  }
}

/// One saved place, as published by docs/02 card 19.
class SavedPlaceView {
  const SavedPlaceView({
    required this.name,
    this.country,
    this.localTime,
    this.tempC,
    this.tmaxC,
    this.tminC,
    this.precipProbPct,
    this.iconName,
    this.conditionCode,
    this.highestSeverity,
  });

  final String name;
  final String? country;
  final String? localTime;
  final num? tempC;
  final num? tmaxC;
  final num? tminC;
  final num? precipProbPct;
  final String? iconName;
  final int? conditionCode;

  /// `yellow|orange|red` or null — docs/04 §Warning severities.
  final String? highestSeverity;

  IconData get icon => AppIcons.byName(
        iconName ?? AppIcons.conditionIconName(conditionCode, isDay: _isDay),
      );

  /// Day/night from the place's own clock, so a night icon is not chosen by the phone's zone.
  bool get _isDay {
    final dt = Fmt.wallClock(localTime);
    if (dt == null) return true;
    return dt.hour >= 6 && dt.hour < 19;
  }

  factory SavedPlaceView.fromJson(Map<String, dynamic> json) => SavedPlaceView(
        name: asString(json['name'], fallback: 'Place'),
        country: asStringOrNull(json['country']),
        localTime: asStringOrNull(json['local_time']),
        tempC: asNum(json['temp_c']),
        tmaxC: asNum(json['tmax_c']),
        tminC: asNum(json['tmin_c']),
        precipProbPct: asNum(json['precip_prob_pct']),
        iconName: asStringOrNull(json['icon']),
        conditionCode: asInt(json['condition_code']),
        highestSeverity: asStringOrNull(json['highest_severity']),
      );
}

/// The horizontal tile drawn per place.
class PlaceTile extends StatelessWidget {
  const PlaceTile({super.key, required this.place, this.width = 128});

  final SavedPlaceView place;
  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final severity = place.highestSeverity;

    return Container(
      width: width,
      padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: severity == null
              ? theme.colorScheme.outlineVariant
              : AppTheme.warningSeverityColor(severity).withValues(alpha: 0.7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  place.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              // docs/06 §Renderers — the severity dot; absent means no active warning.
              if (severity != null)
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: AppTheme.warningSeverityColor(severity),
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
          Text(
            Fmt.time(place.localTime),
            style:
                theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(place.icon, size: 22, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                Fmt.temp(place.tempC, degreeOnly: true),
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w300),
              ),
            ],
          ),
          const Spacer(),
          Text(
            '${Fmt.temp(place.tmaxC, degreeOnly: true)} / ${Fmt.temp(place.tminC, degreeOnly: true)}',
            style: theme.textTheme.labelMedium,
          ),
          if (place.precipProbPct != null)
            Row(
              children: [
                Icon(Icons.water_drop_outlined,
                    size: 11, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 3),
                Text(
                  Fmt.pct(place.precipProbPct),
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
