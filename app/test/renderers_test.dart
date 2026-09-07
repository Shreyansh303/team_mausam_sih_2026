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
    expect(find.text('28°'), findsOneWidget); // temp_c 28.4
    expect(find.text('Humidity'), findsOneWidget);
    expect(find.text('AQI'), findsOneWidget);
  });

  testWidgets('the warnings renderer shows the orange severity tile', (tester) async {
    final card = home.pinned.single;
    await tester.pumpWidget(
        _host(Builder(builder: (context) => RendererRegistry.build(context, card))));
    await tester.pump();
    expect(find.text('Thunderstorm with gusty winds'), findsOneWidget);
    expect(find.text('Orange'), findsOneWidget);
  });

  testWidgets('the hourly renderer lays out all 24 hours', (tester) async {
    final card = home.cards.firstWhere((c) => c.type == 'hourly_forecast');
    await tester.pumpWidget(
        _host(Builder(builder: (context) => RendererRegistry.build(context, card))));
    await tester.pump();
    expect(find.text('Now'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the daily renderer draws one row per day', (tester) async {
    final card = home.moreCards.firstWhere((c) => c.type == 'daily_forecast');
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
}
