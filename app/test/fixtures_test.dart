import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mausam_app/core/theme.dart';
import 'package:mausam_app/data/models/card.dart';
import 'package:mausam_app/data/models/home_response.dart';
import 'package:mausam_app/data/models/json.dart';
import 'package:mausam_app/data/models/warning.dart';
import 'package:mausam_app/features/home/renderers/gauge.dart';
import 'package:mausam_app/features/home/renderers/registry.dart';
import 'package:mausam_app/features/home/renderers/timeline.dart';
import 'package:mausam_app/l10n/gen/app_localizations.dart';

import 'fixture.dart';

/// The contract test for the whole corpus: **every** payload in `docs/fixtures/` (10 files,
/// real `/home` output from the A2 engine, 30 of the 33 card types) must parse with the app's
/// models and render with the registry — no exception, in English and in Hindi.
///
/// docs/PROGRESS.md §"B1/B2 — the fixture contract". Renderers B1 has not written yet fall
/// back to `generic`, which is the point: an unknown card must degrade, never crash.
Widget _host(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
      locale: locale,
      theme: AppTheme.light(),
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        L.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: L.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(child: Padding(padding: const EdgeInsets.all(8), child: child)),
      ),
    );

/// docs/02 §Shared objects — the urgency → severity bands the backend must have used.
String _bandFor(double u) {
  if (u < 0.3) return 'info';
  if (u < 0.5) return 'advisory';
  if (u < 0.7) return 'watch';
  if (u < 0.85) return 'warning';
  return 'severe';
}

void main() {
  const sizes = <String>{'hero', 'large', 'medium', 'small'};
  const severities = <String>{'info', 'advisory', 'watch', 'warning', 'severe'};
  const actionIds = <String>{
    'details',
    'share',
    'pin',
    'unpin',
    'dismiss',
    'hide',
    'open_map',
    'open_places',
    'open_settings',
  };
  const personaIds = <String>{
    'health',
    'fitness',
    'beach',
    'traveler',
    'parent',
    'agriculture',
    'commuter',
    'event_planner',
  };
  final knownRenderers = <String>{
    ...RendererRegistry.implemented,
    ...RendererRegistry.pending,
    'generic',
  };

  late List<MapEntry<String, Map<String, dynamic>>> fixtures;
  final seenTypes = <String>{};
  final seenRenderers = <String>{};
  final oneCardPerType = <String, HomeCard>{};

  setUpAll(() {
    fixtures = loadDocsFixtures();
    for (final entry in fixtures) {
      for (final card in HomeResponse.fromJson(entry.value).allCards) {
        seenTypes.add(card.type);
        seenRenderers.add(card.renderer);
        oneCardPerType.putIfAbsent(card.type, () => card);
      }
    }
  });

  test('all ten reference payloads are present', () {
    expect(fixtures.map((e) => e.key).toList(), <String>[
      'home_agriculture.json',
      'home_beach.json',
      'home_coastal.json',
      'home_commuter.json',
      'home_event_planner.json',
      'home_fitness.json',
      'home_health.json',
      'home_parent.json',
      'home_severe.json',
      'home_traveler.json',
    ]);
  });

  test('every payload parses and obeys the docs/04 Card enums', () {
    for (final entry in fixtures) {
      final home = HomeResponse.fromJson(entry.value);
      final where = entry.key;

      expect(home.generatedAt, isNotEmpty, reason: '$where generated_at');
      expect(home.location.name, isNotEmpty, reason: '$where location.name');
      expect(home.context.activePersonas, isNotEmpty, reason: '$where active_personas');
      for (final p in home.context.activePersonas) {
        expect(personaIds, contains(p), reason: '$where persona $p');
      }
      expect(home.hero, isNotNull, reason: '$where hero');
      expect(home.engine['version'], '1.0', reason: '$where engine.version');
      expect(home.allCards.length, greaterThanOrEqualTo(10), reason: '$where card count');

      for (final card in home.allCards) {
        final at = '$where ${card.type}';
        expect(card.type, isNotEmpty, reason: at);
        expect(card.instanceId, isNotEmpty, reason: at);
        expect(card.title, isNotEmpty, reason: at);
        expect(sizes, contains(card.size), reason: '$at .size');
        expect(severities, contains(card.severity), reason: '$at .severity');
        expect(card.urgency, inInclusiveRange(0, 1), reason: '$at .urgency');
        // `score` is a ranking number, not a probability: docs/03 §Scoring is
        // `0.5*rel*ctx + 0.5*urg + eng` plus pin/urgency boosts, so it can exceed 1
        // (home_severe's pinned school_commute scores 1.175). The app must never assume 0..1.
        expect(card.score, greaterThanOrEqualTo(0), reason: '$at .score');
        expect(card.severity, _bandFor(card.urgency), reason: '$at urgency band');
        expect(card.insight, isNotNull, reason: '$at .insight');
        expect(card.insight!.headline, isNotEmpty, reason: '$at .insight.headline');
        expect(card.updatedAt, isNotNull, reason: '$at .updated_at');
        expect(DateTime.tryParse(card.updatedAt!), isNotNull, reason: '$at .updated_at parses');
        for (final a in card.actions) {
          expect(actionIds, contains(a.id), reason: '$at action ${a.id}');
        }
        for (final p in card.personas) {
          expect(personaIds, contains(p), reason: '$at persona $p');
        }
        // CLAUDE.md §6 — modelled data must be labelled.
        if (card.source == 'estimated') {
          expect(card.isEstimated, isTrue, reason: '$at must show the Estimated chip');
        }
      }

      // docs/04 — the banner is the highest active warning at orange or above, and it must
      // point at a warning that is actually in the payload.
      if (home.banner != null) {
        expect(<String>{'orange', 'red'}, contains(home.banner!.severity), reason: '$where banner');
        final ids = <String>{
          for (final card in home.allCards)
            for (final w in asList(card.data['warnings'], WeatherWarning.fromJson)) w.id,
        };
        expect(ids, contains(home.banner!.warningId), reason: '$where banner warning_id');
      }
    }
  });

  test('every payload round-trips through toJson', () {
    for (final entry in fixtures) {
      final home = HomeResponse.fromJson(entry.value);
      final again =
          HomeResponse.fromJson(jsonDecode(jsonEncode(home.toJson())) as Map<String, dynamic>);
      expect(again.allCards.map((c) => c.instanceId).toList(),
          home.allCards.map((c) => c.instanceId).toList(),
          reason: entry.key);
      expect(again.banner?.warningId, home.banner?.warningId, reason: entry.key);
    }
  });

  test('the corpus covers the 30 card types docs/PROGRESS.md promises', () {
    expect(seenTypes.length, 30, reason: 'types seen: ${seenTypes.toList()..sort()}');
    // The three that no fixture scenario triggers (frost/heatwave/dense_fog gates).
    for (final missing in <String>['frost_alert', 'heat_alert', 'travel_alerts']) {
      expect(seenTypes, isNot(contains(missing)));
    }
  });

  test('every renderer the corpus asks for is implemented or knowingly pending', () {
    for (final r in seenRenderers) {
      expect(knownRenderers, contains(r), reason: 'unlisted renderer $r');
    }
    // Nothing in the corpus is left without a widget: unknown kinds land on `generic`.
    expect(seenRenderers.difference(RendererRegistry.implemented).difference(
          RendererRegistry.pending,
        ), isEmpty);
  });

  group('renders without exception', () {
    for (final name in <String>[
      'home_agriculture.json',
      'home_beach.json',
      'home_coastal.json',
      'home_commuter.json',
      'home_event_planner.json',
      'home_fitness.json',
      'home_health.json',
      'home_parent.json',
      'home_severe.json',
      'home_traveler.json',
    ]) {
      testWidgets(name, (tester) async {
        final entry = fixtures.firstWhere((e) => e.key == name);
        final home = HomeResponse.fromJson(entry.value);
        expect(home.allCards, isNotEmpty);
        for (final card in home.allCards) {
          await tester.pumpWidget(
              _host(Builder(builder: (context) => RendererRegistry.build(context, card))));
          await tester.pump();
          expect(tester.takeException(), isNull,
              reason: '$name: "${card.type}" (renderer "${card.renderer}") threw');
        }
      });
    }
  });

  /// docs/07 §B2a — the acceptance gate for a renderer is not "it did not throw" but
  /// "its distinctive widget is on screen". One assertion per implemented renderer, driven by
  /// the real payload the backend produced.
  group('each B2a renderer draws its distinctive widget', () {
    Future<void> pumpType(WidgetTester tester, String type) async {
      final card = oneCardPerType[type];
      expect(card, isNotNull, reason: 'no $type card in the corpus');
      await tester.pumpWidget(
          _host(Builder(builder: (context) => RendererRegistry.build(context, card!))));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: type);
    }

    testWidgets('gauge — aqi draws the CPCB arc, the value and the category', (tester) async {
      await pumpType(tester, 'aqi');
      final card = oneCardPerType['aqi']!;
      expect(
        find.byWidgetPredicate((w) => w is CustomPaint && w.painter is GaugeArcPainter),
        findsOneWidget,
      );
      expect(find.text('${(card.data['aqi'] as num).round()}'), findsOneWidget);
      expect(find.text(card.data['category'] as String), findsOneWidget);
      expect(find.textContaining('CPCB'), findsOneWidget);
    });

    testWidgets('gauge — soil_moisture shows a volumetric % and its status', (tester) async {
      await pumpType(tester, 'soil_moisture');
      final card = oneCardPerType['soil_moisture']!;
      final pct = ((card.data['surface_m3m3'] as num) * 100).round();
      expect(find.text('$pct'), findsOneWidget);
      expect(find.text('%'), findsOneWidget);
      expect(find.textContaining('Root zone'), findsOneWidget);
    });

    testWidgets('gauge — comfort_index shows the 0–100 index', (tester) async {
      await pumpType(tester, 'comfort_index');
      final card = oneCardPerType['comfort_index']!;
      expect(find.text('${(card.data['index'] as num).round()}'), findsOneWidget);
      expect(find.text(card.data['category'] as String), findsOneWidget);
    });

    testWidgets('timeline — school_commute shows both windows and the overall verdict',
        (tester) async {
      await pumpType(tester, 'school_commute');
      final card = oneCardPerType['school_commute']!;
      final windows = (card.data['windows'] as List).cast<Map<String, dynamic>>();
      expect(find.byType(TimelineBar), findsOneWidget);
      expect(find.byType(TimelineWindowRow), findsNWidgets(windows.length));
      expect(find.text('Morning Drop'), findsWidgets);
      expect(
        find.textContaining('Overall: ${card.data['overall_verdict'].toString()[0].toUpperCase()}'),
        findsOneWidget,
      );
    });

    testWidgets('timeline — best_workout_window scores each window out of 100',
        (tester) async {
      await pumpType(tester, 'best_workout_window');
      final card = oneCardPerType['best_workout_window']!;
      final first = (card.data['windows'] as List).first as Map<String, dynamic>;
      expect(find.byType(TimelineBar), findsOneWidget);
      expect(find.text('${(first['score'] as num).round()}/100'), findsOneWidget);
    });

    testWidgets('timeline — commute_conditions shows the impact and the delay',
        (tester) async {
      await pumpType(tester, 'commute_conditions');
      final card = oneCardPerType['commute_conditions']!;
      final first = (card.data['windows'] as List).first as Map<String, dynamic>;
      expect(find.textContaining('impact'), findsWidgets);
      // The stats row is a Text.rich ("Delay  +12 min"), so search the spans too.
      expect(
        find.textContaining('+${(first['delay_min'] as num).round()} min', findRichText: true),
        findsWidgets,
      );
    });
  });

  testWidgets('one card of every type in the corpus also renders in Hindi', (tester) async {
    expect(oneCardPerType, isNotEmpty);
    for (final card in oneCardPerType.values) {
      await tester.pumpWidget(
        _host(Builder(builder: (context) => RendererRegistry.build(context, card)),
            locale: const Locale('hi')),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: '"${card.type}" threw in hi');
    }
  });
}
