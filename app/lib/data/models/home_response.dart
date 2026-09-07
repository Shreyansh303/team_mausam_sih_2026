import 'card.dart';
import 'json.dart';
import 'location.dart';
import 'warning.dart';

/// docs/04_API_CONTRACT.md §Objects `HomeResponse.context`.
class HomeContext {
  const HomeContext({
    this.now,
    this.daypart = 'morning',
    this.isWeekend = false,
    this.season = 'monsoon',
    this.isCoastal = false,
    this.scenario = 'live',
    this.activePersonas = const <String>[],
    this.warningCount = 0,
    this.lang = 'en',
  });

  final String? now;

  /// night|dawn|morning|midday|afternoon|evening|late
  final String daypart;
  final bool isWeekend;

  /// winter|pre_monsoon|monsoon|post_monsoon
  final String season;
  final bool isCoastal;
  final String scenario;
  final List<String> activePersonas;
  final int warningCount;
  final String lang;

  factory HomeContext.fromJson(Map<String, dynamic> json) => HomeContext(
        now: asStringOrNull(json['now']),
        daypart: asString(json['daypart'], fallback: 'morning'),
        isWeekend: asBool(json['is_weekend']),
        season: asString(json['season'], fallback: 'monsoon'),
        isCoastal: asBool(json['is_coastal']),
        scenario: asString(json['scenario'], fallback: 'live'),
        activePersonas: asStringList(json['active_personas']),
        warningCount: asInt(json['warning_count']) ?? 0,
        lang: asString(json['lang'], fallback: 'en'),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'now': now,
        'daypart': daypart,
        'is_weekend': isWeekend,
        'season': season,
        'is_coastal': isCoastal,
        'scenario': scenario,
        'active_personas': activePersonas,
        'warning_count': warningCount,
        'lang': lang,
      };
}

/// docs/04_API_CONTRACT.md §Objects `HomeResponse`.
class HomeResponse {
  const HomeResponse({
    required this.generatedAt,
    required this.location,
    required this.context,
    this.banner,
    this.pinned = const <HomeCard>[],
    this.hero,
    this.cards = const <HomeCard>[],
    this.moreCards = const <HomeCard>[],
    this.hiddenTypes = const <String>[],
    this.freshness = const <String, dynamic>{},
    this.sources = const <String, dynamic>{},
    this.engine = const <String, dynamic>{},
  });

  final String generatedAt;
  final LocationResult location;
  final HomeContext context;
  final HomeBanner? banner;
  final List<HomeCard> pinned;
  final HomeCard? hero;
  final List<HomeCard> cards;
  final List<HomeCard> moreCards;
  final List<String> hiddenTypes;
  final Map<String, dynamic> freshness;
  final Map<String, dynamic> sources;
  final Map<String, dynamic> engine;

  /// Everything in display order: pinned, hero, then the ranked list.
  List<HomeCard> get orderedCards => <HomeCard>[
        ...pinned,
        ?hero,
        ...cards,
      ];

  /// Every card in the payload, including the "More for you" tail — what the renderer test
  /// walks so that no card type can crash the home screen.
  List<HomeCard> get allCards => <HomeCard>[...orderedCards, ...moreCards];

  /// The most recent of the per-source `freshness` timestamps, used by the freshness chip.
  String? get newestFreshness {
    String? best;
    DateTime? bestAt;
    for (final v in freshness.values) {
      if (v is! String) continue;
      final dt = DateTime.tryParse(v);
      if (dt == null) continue;
      if (bestAt == null || dt.isAfter(bestAt)) {
        bestAt = dt;
        best = v;
      }
    }
    return best ?? generatedAt;
  }

  factory HomeResponse.fromJson(Map<String, dynamic> json) => HomeResponse(
        generatedAt: asString(json['generated_at']),
        location: LocationResult.fromJson(asMap(json['location'])),
        context: HomeContext.fromJson(asMap(json['context'])),
        banner: json['banner'] == null ? null : HomeBanner.fromJson(asMap(json['banner'])),
        pinned: asList(json['pinned'], HomeCard.fromJson),
        hero: json['hero'] == null ? null : HomeCard.fromJson(asMap(json['hero'])),
        cards: asList(json['cards'], HomeCard.fromJson),
        moreCards: asList(json['more_cards'], HomeCard.fromJson),
        hiddenTypes: asStringList(json['hidden_types']),
        freshness: asMap(json['freshness']),
        sources: asMap(json['sources']),
        engine: asMap(json['engine']),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'generated_at': generatedAt,
        'location': location.toJson(),
        'context': context.toJson(),
        'banner': banner?.toJson(),
        'pinned': pinned.map((c) => c.toJson()).toList(),
        'hero': hero?.toJson(),
        'cards': cards.map((c) => c.toJson()).toList(),
        'more_cards': moreCards.map((c) => c.toJson()).toList(),
        'hidden_types': hiddenTypes,
        'freshness': freshness,
        'sources': sources,
        'engine': engine,
      };
}
