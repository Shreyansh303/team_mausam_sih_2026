import '../models/card.dart';
import '../models/home_response.dart';
import '../models/json.dart';

/// The compact payload the Android home-screen widget renders (docs/06 §Home-screen widget).
///
/// The widget draws with `RemoteViews`, outside the Flutter engine, so everything it shows has
/// to survive as plain JSON in shared storage. Two producers write this exact shape and both
/// must stay in step:
///   * Dart — [WidgetSnapshot.fromHome], on every `/home` payload the app receives;
///   * Kotlin — `MausamWidgetWorker` / `SnapshotJson.kt`, on the hourly background refresh.
///
/// Card *content* is already localized by the backend (docs/04 `lang`), so nothing here is
/// translated on the device; [lang] only records which language the strings are in, so the
/// widget can tell a stale Hindi snapshot from a fresh English one after a language switch.
class WidgetSnapshot {
  const WidgetSnapshot({
    this.locationName = '',
    this.updatedAt,
    this.lang = 'en',
    this.units = 'metric',
    this.hero,
    this.pinned,
  });

  /// docs/04 §Objects `HomeResponse.location.name`.
  final String locationName;

  /// When the data was produced, not when it was written: the payload's newest `freshness`
  /// timestamp, falling back to `generated_at`. The widget's age label and its ">6 h → open
  /// Mausam to refresh" rule are both computed from this, so a cache replay stays honest.
  final String? updatedAt;

  final String lang;

  /// `metric` | `imperial` — the widget formats the temperature itself.
  final String units;

  final WidgetHero? hero;

  /// The top pinned card, or the top ranked card when nothing is pinned.
  final WidgetPinned? pinned;

  /// Nothing worth drawing: the widget falls back to "Open Mausam to refresh".
  bool get isEmpty => hero == null && pinned == null;

  /// Empty payloads still carry the language so the widget's own chrome keeps its locale.
  static const WidgetSnapshot empty = WidgetSnapshot();

  /// Builds the snapshot from a `/home` (or `/home?lite=1`) response.
  ///
  /// Selection rules, mirrored in Kotlin:
  ///   * hero  — `hero`, which docs/02 card 1 guarantees is `current_conditions`;
  ///   * pinned — `pinned.first` when the ranker pinned anything (a warning always is),
  ///     otherwise the first ranked card, which is the highest scoring one.
  factory WidgetSnapshot.fromHome(
    HomeResponse home, {
    String? lang,
    String units = 'metric',
  }) {
    final top = home.pinned.isNotEmpty
        ? home.pinned.first
        : (home.cards.isNotEmpty ? home.cards.first : null);
    return WidgetSnapshot(
      locationName: home.location.name,
      updatedAt: home.newestFreshness ?? home.generatedAt,
      lang: lang ?? home.context.lang,
      units: units,
      hero: home.hero == null ? null : WidgetHero.fromCard(home.hero!),
      pinned: top == null ? null : WidgetPinned.fromCard(top),
    );
  }

  factory WidgetSnapshot.fromJson(Map<String, dynamic> json) => WidgetSnapshot(
        locationName: asString(json['location']),
        updatedAt: asStringOrNull(json['updated_at']),
        lang: asString(json['lang'], fallback: 'en'),
        units: asString(json['units'], fallback: 'metric'),
        hero: json['hero'] == null ? null : WidgetHero.fromJson(asMap(json['hero'])),
        pinned: json['pinned'] == null ? null : WidgetPinned.fromJson(asMap(json['pinned'])),
      );

  /// `v` is the schema version: the Kotlin side ignores a snapshot it does not understand
  /// rather than drawing half of it.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'v': schemaVersion,
        'location': locationName,
        'updated_at': updatedAt,
        'lang': lang,
        'units': units,
        'hero': hero?.toJson(),
        'pinned': pinned?.toJson(),
      };

  static const int schemaVersion = 1;
}

/// docs/02 card 1 `current_conditions` — the four things that fit on one widget row.
class WidgetHero {
  const WidgetHero({
    this.tempC,
    this.condition = '',
    this.icon,
    this.feelsLikeC,
    this.tmaxC,
    this.tminC,
  });

  final double? tempC;

  /// Already localized by the backend (`data.condition_text`).
  final String condition;

  /// docs/06 §Layout `core/icons.dart` icon name, e.g. `thunderstorm`.
  final String? icon;
  final double? feelsLikeC;
  final double? tmaxC;
  final double? tminC;

  factory WidgetHero.fromCard(HomeCard card) {
    final d = card.data;
    return WidgetHero(
      tempC: asDouble(d['temp_c']),
      condition: asString(d['condition_text'], fallback: card.subtitle),
      icon: asStringOrNull(d['icon']),
      feelsLikeC: asDouble(d['feels_like_c']),
      tmaxC: asDouble(d['tmax_c']),
      tminC: asDouble(d['tmin_c']),
    );
  }

  factory WidgetHero.fromJson(Map<String, dynamic> json) => WidgetHero(
        tempC: asDouble(json['temp_c']),
        condition: asString(json['condition']),
        icon: asStringOrNull(json['icon']),
        feelsLikeC: asDouble(json['feels_like_c']),
        tmaxC: asDouble(json['tmax_c']),
        tminC: asDouble(json['tmin_c']),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'temp_c': tempC,
        'condition': condition,
        'icon': icon,
        'feels_like_c': feelsLikeC,
        'tmax_c': tmaxC,
        'tmin_c': tminC,
      };
}

/// One line of "what matters right now": the pinned card's title, its insight headline and the
/// colour the widget paints its accent bar with.
class WidgetPinned {
  const WidgetPinned({
    required this.type,
    this.title = '',
    this.insight = '',
    this.severity = 'info',
    this.colorHex = WidgetPinned.infoHex,
    this.estimated = false,
  });

  final String type;
  final String title;

  /// `insight.headline`, falling back to the subtitle — one line, already localized.
  final String insight;

  /// info|advisory|watch|warning|severe (docs/02 §Card anatomy).
  final String severity;

  /// `#RRGGBB`. For a `warnings` card this is the IMD warning colour that came with the
  /// payload, so the widget shows the same yellow/orange/red as the app.
  final String colorHex;

  /// CLAUDE.md §6 — modelled data is labelled as such, in the widget too.
  final bool estimated;

  /// docs/06 §Layout `core/theme.dart` severity colours, as hex so Kotlin can parse them.
  static const String yellowHex = '#F5C518';
  static const String orangeHex = '#F28C28';
  static const String redHex = '#D32F2F';

  /// The M3 seed (#1565C0) stands in for `colorScheme.primary`, which a RemoteViews layout
  /// cannot resolve.
  static const String infoHex = '#1565C0';

  factory WidgetPinned.fromCard(HomeCard card) => WidgetPinned(
        type: card.type,
        title: card.title,
        insight: card.insight?.headline.isNotEmpty == true
            ? card.insight!.headline
            : card.subtitle,
        severity: card.severity,
        colorHex: colorFor(card),
        estimated: card.isEstimated,
      );

  /// A `warnings` card is coloured by the warning it carries (docs/04 `Warning.color_hex`);
  /// everything else by the card severity band (docs/06 §theme `cardSeverityColor`).
  static String colorFor(HomeCard card) {
    if (card.type == 'warnings') {
      final warnings = card.data['warnings'];
      if (warnings is List && warnings.isNotEmpty && warnings.first is Map) {
        final first = asMap(warnings.first);
        final hex = asStringOrNull(first['color_hex']);
        if (hex != null && hex.isNotEmpty) return hex;
        switch (asStringOrNull(first['severity'])) {
          case 'red':
            return redHex;
          case 'orange':
            return orangeHex;
          case 'yellow':
            return yellowHex;
        }
      }
    }
    switch (card.severity) {
      case 'severe':
        return redHex;
      case 'warning':
        return orangeHex;
      case 'watch':
        return yellowHex;
      default:
        return infoHex;
    }
  }

  factory WidgetPinned.fromJson(Map<String, dynamic> json) => WidgetPinned(
        type: asString(json['type']),
        title: asString(json['title']),
        insight: asString(json['insight']),
        severity: asString(json['severity'], fallback: 'info'),
        colorHex: asString(json['color_hex'], fallback: infoHex),
        estimated: asBool(json['estimated']),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': type,
        'title': title,
        'insight': insight,
        'severity': severity,
        'color_hex': colorHex,
        'estimated': estimated,
      };
}
