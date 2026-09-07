import 'json.dart';

/// docs/04_API_CONTRACT.md §Objects `Reason`.
class Reason {
  const Reason({required this.code, required this.text});

  final String code;
  final String text;

  /// `persona:health` → `health`; used by the why-sheet to list the driving personas.
  String? get personaId => code.startsWith('persona:') ? code.substring(8) : null;

  factory Reason.fromJson(Map<String, dynamic> json) => Reason(
        code: asString(json['code']),
        text: asString(json['text']),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{'code': code, 'text': text};
}

/// docs/04_API_CONTRACT.md §Objects `Insight`.
class Insight {
  const Insight({required this.headline, this.detail = '', this.icon});

  final String headline;
  final String detail;
  final String? icon;

  factory Insight.fromJson(Map<String, dynamic> json) => Insight(
        headline: asString(json['headline']),
        detail: asString(json['detail']),
        icon: asStringOrNull(json['icon']),
      );

  Map<String, dynamic> toJson() =>
      <String, dynamic>{'headline': headline, 'detail': detail, 'icon': icon};
}

/// docs/04_API_CONTRACT.md §Objects `Action`.
class CardAction {
  const CardAction({required this.id, required this.label});

  /// details|share|pin|unpin|dismiss|hide|open_map|open_places|open_settings
  final String id;
  final String label;

  factory CardAction.fromJson(Map<String, dynamic> json) => CardAction(
        id: asString(json['id']),
        label: asString(json['label']),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{'id': id, 'label': label};
}

/// docs/04_API_CONTRACT.md §Objects `Card`. `data` stays a raw map: its shape is per-card
/// (docs/02 §Per-card specification) and the renderers read it directly, so the generic
/// renderer can still show something useful for a card type the app has never seen.
class HomeCard {
  const HomeCard({
    required this.type,
    required this.instanceId,
    required this.title,
    this.subtitle = '',
    this.size = 'medium',
    this.renderer = 'generic',
    this.urgency = 0,
    this.severity = 'info',
    this.pinned = false,
    this.score = 0,
    this.reasons = const <Reason>[],
    this.insight,
    this.data = const <String, dynamic>{},
    this.actions = const <CardAction>[],
    this.personas = const <String>[],
    this.source,
    this.estimated = false,
    this.updatedAt,
  });

  final String type;
  final String instanceId;
  final String title;
  final String subtitle;

  /// hero|large|medium|small
  final String size;

  /// Renderer kind from docs/02 (hero, warnings, nowcast, hourly, daily, radar, gauge, metric,
  /// advice_list, timeline, alert, sea, tides, places, bar_chart, generic).
  final String renderer;

  final double urgency;

  /// info|advisory|watch|warning|severe
  final String severity;
  final bool pinned;
  final double score;
  final List<Reason> reasons;
  final Insight? insight;
  final Map<String, dynamic> data;
  final List<CardAction> actions;
  final List<String> personas;

  /// open-meteo|imd|estimated|scenario|mixed
  final String? source;
  final bool estimated;
  final String? updatedAt;

  bool get isEstimated => estimated || source == 'estimated';

  bool hasAction(String id) => actions.any((a) => a.id == id);

  /// docs/06 §Card shell — "{title}. {subtitle}. {insight.headline}".
  String get semanticsLabel => <String>[
        title,
        if (subtitle.isNotEmpty) subtitle,
        if (insight != null && insight!.headline.isNotEmpty) insight!.headline,
      ].join('. ');

  factory HomeCard.fromJson(Map<String, dynamic> json) {
    final type = asString(json['type'], fallback: 'unknown');
    return HomeCard(
      type: type,
      instanceId: asString(json['instance_id'], fallback: type),
      title: asString(json['title']),
      subtitle: asString(json['subtitle']),
      size: asString(json['size'], fallback: 'medium'),
      renderer: asString(json['renderer'], fallback: 'generic'),
      urgency: asDouble(json['urgency']) ?? 0,
      severity: asString(json['severity'], fallback: 'info'),
      pinned: asBool(json['pinned']),
      score: asDouble(json['score']) ?? 0,
      reasons: asList(json['reasons'], Reason.fromJson),
      insight: json['insight'] == null ? null : Insight.fromJson(asMap(json['insight'])),
      data: asMap(json['data']),
      actions: asList(json['actions'], CardAction.fromJson),
      personas: asStringList(json['personas']),
      source: asStringOrNull(json['source']),
      estimated: asBool(json['estimated']),
      updatedAt: asStringOrNull(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': type,
        'instance_id': instanceId,
        'title': title,
        'subtitle': subtitle,
        'size': size,
        'renderer': renderer,
        'urgency': urgency,
        'severity': severity,
        'pinned': pinned,
        'score': score,
        'reasons': reasons.map((r) => r.toJson()).toList(),
        'insight': insight?.toJson(),
        'data': data,
        'actions': actions.map((a) => a.toJson()).toList(),
        'personas': personas,
        'source': source,
        'estimated': estimated,
        'updated_at': updatedAt,
      };
}
