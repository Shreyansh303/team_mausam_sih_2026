import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mausam_app/core/config.dart';
import 'package:mausam_app/l10n/gen/app_localizations.dart';
import 'package:mausam_app/l10n/labels.dart';

/// docs/06_MOBILE_SPEC.md §i18n and docs/07 §B2 — "l10n en/hi complete (+ mr/ta/bn
/// best-effort)". These tests are the gate on that promise: every key the template declares
/// has to exist in Hindi, and the partial locales have to stay valid ARB.
Map<String, dynamic> _arb(String code) =>
    jsonDecode(File('lib/l10n/app_$code.arb').readAsStringSync()) as Map<String, dynamic>;

Iterable<String> _messageKeys(Map<String, dynamic> arb) =>
    arb.keys.where((k) => !k.startsWith('@'));

void main() {
  late Map<String, dynamic> en;

  setUpAll(() => en = _arb('en'));

  test('the template carries a locale marker and a healthy number of messages', () {
    expect(en['@@locale'], 'en');
    expect(_messageKeys(en).length, greaterThan(200));
  });

  test('Hindi is complete: every en key exists in hi, with no empty values', () {
    final hi = _arb('hi');
    expect(hi['@@locale'], 'hi');

    final missing = _messageKeys(en).where((k) => !hi.containsKey(k)).toList()..sort();
    expect(missing, isEmpty, reason: 'missing Hindi translations for: $missing');

    final extra = _messageKeys(hi).where((k) => !en.containsKey(k)).toList()..sort();
    expect(extra, isEmpty, reason: 'Hindi keys that no longer exist in English: $extra');

    for (final key in _messageKeys(hi)) {
      expect('${hi[key]}'.trim(), isNotEmpty, reason: '$key is empty in hi');
    }
  });

  test('every placeholder set matches between en and hi', () {
    final hi = _arb('hi');
    final placeholder = RegExp(r'\{(\w+)\}');
    for (final key in _messageKeys(en)) {
      final enSlots = placeholder.allMatches('${en[key]}').map((m) => m.group(1)!).toSet();
      final hiSlots = placeholder.allMatches('${hi[key]}').map((m) => m.group(1)!).toSet();
      expect(hiSlots, enSlots, reason: 'placeholder mismatch in "$key"');
    }
  });

  test('mr, ta and bn are valid partial ARBs whose keys all exist in English', () {
    for (final code in <String>['mr', 'ta', 'bn']) {
      final arb = _arb(code);
      expect(arb['@@locale'], code);
      final keys = _messageKeys(arb).toList();
      expect(keys.length, greaterThanOrEqualTo(50),
          reason: '$code should cover at least the core chrome');
      final unknown = keys.where((k) => !en.containsKey(k)).toList()..sort();
      expect(unknown, isEmpty, reason: '$code has keys English does not: $unknown');
      for (final key in keys) {
        expect('${arb[key]}'.trim(), isNotEmpty, reason: '$key is empty in $code');
      }
    }
  });

  test('AppConfig lists exactly the locales the generated delegate supports', () {
    expect(
      L.supportedLocales.map((l) => l.languageCode).toSet(),
      AppConfig.supportedLanguages.toSet(),
    );
  });

  testWidgets('the generated bundles resolve for every supported locale', (tester) async {
    for (final code in AppConfig.supportedLanguages) {
      late L l;
      await tester.pumpWidget(MaterialApp(
        locale: Locale(code),
        supportedLocales: L.supportedLocales,
        localizationsDelegates: const <LocalizationsDelegate<Object>>[
          L.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Builder(builder: (context) {
          l = L.of(context);
          return Text(l.appTitle);
        }),
      ));
      await tester.pump();

      expect(tester.takeException(), isNull, reason: '$code failed to build');
      expect(l.appTitle, isNotEmpty);
      // A partial locale still answers every getter — gen-l10n falls back to the template.
      expect(l.settingsTitle, isNotEmpty);
      expect(l.warningMovedToTop, isNotEmpty);
      expect(l.placesSubtitle(8), contains('8'));
    }
  });

  testWidgets('the data-value label helpers cover the docs/02 enums and degrade gracefully',
      (tester) async {
    late L l;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      supportedLocales: L.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        L.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Builder(builder: (context) {
        l = L.of(context);
        return const SizedBox.shrink();
      }),
    ));
    await tester.pump();

    expect(aqiBandLabel(l, 'very_poor'), 'Very poor');
    expect(soilBandLabel(l, 'saturated'), 'Saturated');
    expect(seaStateLabel(l, 'very_rough'), 'Very rough');
    expect(qualityLabel(l, 'caution'), 'Caution');
    expect(levelLabel(l, 'moderate'), 'Moderate');
    expect(hazardLabel(l, 'cold_wave'), 'Cold wave');
    expect(seasonLabel(l, 'pre_monsoon'), 'Pre-monsoon');
    expect(windowLabel(l, 'morning_drop'), 'Morning drop');
    expect(severityLabel(l, 'orange'), 'Orange');
    // A value this build has never seen still reads as words, not a raw key.
    expect(hazardLabel(l, 'volcanic_ash'), 'Volcanic Ash');
  });
}
