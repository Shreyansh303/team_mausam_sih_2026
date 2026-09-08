import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mausam_app/core/theme.dart';
import 'package:mausam_app/data/models/card.dart';
import 'package:mausam_app/data/models/home_response.dart';
import 'package:mausam_app/features/home/renderers/registry.dart';
import 'package:mausam_app/l10n/gen/app_localizations.dart';

import 'fixture.dart';

/// docs/06_MOBILE_SPEC.md §app/test — "renderers_test.dart (every card type in fixture renders
/// without exception)" and §Renderers — "generic: never crash on unknown cards".
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

void main() {
  late HomeResponse home;

  setUpAll(() {
    home = HomeResponse.fromJson(loadSampleHomeJson());
  });

  testWidgets('every card in the fixture renders without exception', (tester) async {
    expect(home.allCards, isNotEmpty);
    for (final card in home.allCards) {
      await tester.pumpWidget(_host(
        Builder(builder: (context) => RendererRegistry.build(context, card)),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull,
          reason: 'card "${card.type}" (renderer "${card.renderer}") threw');
    }
  });

  testWidgets('every card also renders in Hindi', (tester) async {
    for (final card in home.allCards) {
      await tester.pumpWidget(_host(
        Builder(builder: (context) => RendererRegistry.build(context, card)),
        locale: const Locale('hi'),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'card "${card.type}" threw in hi');
    }
  });

  testWidgets('the hero renderer shows the temperature and micro-stats', (tester) async {
    final hero = home.hero!;
    await tester.pumpWidget(
        _host(Builder(builder: (context) => RendererRegistry.build(context, hero))));
    await tester.pump();
    expect(find.text('27°'), findsWidgets); // temp_c 27.0
    expect(find.text('Humidity'), findsOneWidget);
    expect(find.text('AQI'), findsOneWidget);
  });

  testWidgets('the warnings renderer shows the orange severity tile', (tester) async {
    final card = home.pinned.firstWhere((c) => c.type == 'warnings');
    await tester.pumpWidget(
        _host(Builder(builder: (context) => RendererRegistry.build(context, card))));
    await tester.pump();
    expect(find.text('Orange warning: thunderstorm with lightning'), findsOneWidget);
    expect(find.text('Orange'), findsOneWidget);
  });

  testWidgets('the hourly renderer lays out the whole strip', (tester) async {
    final card = home.cards.firstWhere((c) => c.type == 'hourly_forecast');
    await tester.pumpWidget(
        _host(Builder(builder: (context) => RendererRegistry.build(context, card))));
    await tester.pump();
    expect(find.text('Now'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the daily renderer draws one row per day', (tester) async {
    final card = home.cards.firstWhere((c) => c.type == 'daily_forecast');
    await tester.pumpWidget(
        _host(Builder(builder: (context) => RendererRegistry.build(context, card))));
    await tester.pump();
    expect(find.text('Tue'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an unknown card type falls back to the generic renderer', (tester) async {
    final card = HomeCard.fromJson(<String, dynamic>{
      'type': 'a_card_type_that_does_not_exist',
      'title': 'Mystery',
      'renderer': 'a_renderer_that_does_not_exist',
      'data': <String, dynamic>{
        'some_value': 42,
        'a_flag': true,
        'a_time': '2026-09-08T07:30:00+05:30',
        'nested': <String, dynamic>{'x': 1},
        'list': <dynamic>[1, 2, 3],
      },
    });
    await tester.pumpWidget(
        _host(Builder(builder: (context) => RendererRegistry.build(context, card))));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Some Value'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
    expect(find.text('3 items'), findsOneWidget);
  });

  testWidgets('a card with an empty data map still renders', (tester) async {
    final card = HomeCard.fromJson(<String, dynamic>{'type': 'empty', 'title': 'Empty'});
    await tester.pumpWidget(
        _host(Builder(builder: (context) => RendererRegistry.build(context, card))));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  test('the registry covers every renderer kind named in docs/02', () {
    const fromCatalog = <String>{
      'hero',
      'warnings',
      'nowcast',
      'hourly',
      'daily',
      'radar',
      'gauge',
      'metric',
      'advice_list',
      'timeline',
      'alert',
      'sea',
      'tides',
      'places',
      'bar_chart',
      'generic',
    };
    final known = <String>{
      ...RendererRegistry.implemented,
      ...RendererRegistry.pending,
      'generic',
    };
    expect(known, containsAll(fromCatalog));
    // Everything the fixture asks for is either implemented or knowingly pending.
    for (final card in home.allCards) {
      expect(known, contains(card.renderer), reason: 'unlisted renderer ${card.renderer}');
    }
  });

  // ------------------------------------------------------------------ C1 regressions
  //
  // Both of these are "the card says the same thing twice", which reads on screen as a
  // rendering bug. The card shell owns the `Estimated` chip and `insight.detail`; a renderer
  // must not print them a second time.

  Map<String, dynamic> rawCard(String fixture, String type) {
    final payload = loadDocsFixture(fixture);
    for (final key in <String>['pinned', 'cards', 'more_cards']) {
      for (final c in (payload[key] as List<dynamic>? ?? const <dynamic>[])) {
        if ((c as Map<String, dynamic>)['type'] == type) return Map<String, dynamic>.from(c);
      }
    }
    throw StateError('no $type card in $fixture');
  }

  testWidgets('timeline does not repeat the advice the shell already prints', (tester) async {
    final raw = rawCard('home_parent.json', 'school_commute');
    final advice = raw['data']['advice'] as String;
    expect(advice, (raw['insight'] as Map<String, dynamic>)['detail'],
        reason: 'the engine reuses one sentence for both — that is what this guards');

    await tester.pumpWidget(_host(Builder(
      builder: (context) => RendererRegistry.build(context, HomeCard.fromJson(raw)),
    )));
    await tester.pump();
    expect(find.text(advice), findsNothing);

    // A genuinely different advice line still shows.
    final other = Map<String, dynamic>.from(raw)
      ..['data'] = <String, dynamic>{...raw['data'] as Map<String, dynamic>, 'advice': 'Leave 10 minutes earlier.'};
    await tester.pumpWidget(_host(Builder(
      builder: (context) => RendererRegistry.build(context, HomeCard.fromJson(other)),
    )));
    await tester.pump();
    expect(find.text('Leave 10 minutes earlier.'), findsOneWidget);
  });

  testWidgets('tides leaves the Estimated chip to the card shell', (tester) async {
    final raw = rawCard('home_coastal.json', 'tides');
    expect(raw['estimated'], isTrue);

    await tester.pumpWidget(_host(Builder(
      builder: (context) => RendererRegistry.build(context, HomeCard.fromJson(raw)),
    )));
    await tester.pump();
    expect(find.text('Estimated'), findsNothing);

    // A host that does not draw the chip itself still gets one.
    await tester.pumpWidget(_host(Builder(
      builder: (context) => RendererRegistry.build(
          context, HomeCard.fromJson(<String, dynamic>{...raw, 'estimated': false, 'source': 'imd'})),
    )));
    await tester.pump();
    expect(find.text('Estimated'), findsOneWidget);
  });
}
