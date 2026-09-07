import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mausam_app/core/formatters.dart';
import 'package:mausam_app/data/models/card.dart';
import 'package:mausam_app/data/models/home_response.dart';
import 'package:mausam_app/data/models/json.dart';
import 'package:mausam_app/data/models/user.dart';
import 'package:mausam_app/data/models/warning.dart';

import 'fixture.dart';

/// Every field name and enum checked here comes from docs/04_API_CONTRACT.md.
///
/// The bundled fixture is a copy of `docs/fixtures/home_severe.json` — real engine output
/// (parent, New Delhi, `scenario=thunderstorm`). `fixtures_test.dart` runs the same shape
/// checks across all ten reference payloads; this file pins the exact values the app's own
/// widget tests and the offline demo depend on.
void main() {
  late Map<String, dynamic> raw;
  late HomeResponse home;

  setUpAll(() {
    raw = loadSampleHomeJson();
    home = HomeResponse.fromJson(raw);
  });

  group('the bundled fixture matches docs/04', () {
    test('is valid JSON with the HomeResponse top-level keys', () {
      for (final key in <String>[
        'generated_at',
        'location',
        'context',
        'banner',
        'pinned',
        'hero',
        'cards',
        'more_cards',
        'hidden_types',
        'freshness',
        'sources',
        'engine',
      ]) {
        expect(raw.containsKey(key), isTrue, reason: 'missing HomeResponse.$key');
      }
    });

    test('parses location, context and engine', () {
      expect(home.location.name, 'New Delhi');
      expect(home.location.lat, closeTo(28.61, 0.001));
      expect(home.location.isCoastal, isFalse);
      expect(home.context.activePersonas, <String>['parent']);
      expect(home.context.scenario, 'thunderstorm');
      expect(home.context.warningCount, 1);
      expect(home.context.daypart, 'dawn');
      expect(home.context.season, 'monsoon');
      expect(home.engine['version'], '1.0');
    });

    test('has a hero, 8 ranked cards and a "More for you" tail (docs/03 §Ranking)', () {
      expect(home.hero, isNotNull);
      expect(home.hero!.type, 'current_conditions');
      expect(home.hero!.renderer, 'hero');
      expect(home.cards.length, 8); // docs/03 §Ranking — the first 8 are `cards`
      expect(home.moreCards, isNotEmpty);
      expect(home.moreCards.length, 12);
    });

    test('pins the urgent cards and raises the orange banner', () {
      // docs/03 §Ranking — pinned is sorted by urgency desc; a warning ≥ orange always lands here.
      expect(home.pinned, hasLength(4));
      expect(home.pinned.map((c) => c.type).toList(),
          <String>['commute_conditions', 'school_commute', 'rain_alert', 'warnings']);
      expect(home.pinned.every((c) => c.pinned), isTrue);
      final card = home.pinned.firstWhere((c) => c.type == 'warnings');
      expect(card.pinned, isTrue);

      final warnings = asList(card.data['warnings'], WeatherWarning.fromJson);
      expect(warnings, hasLength(1));
      final w = warnings.single;
      expect(w.severity, 'orange');
      expect(w.hazard, 'thunderstorm');
      expect(w.isOrangeOrAbove, isTrue);
      expect(w.colorHex, '#F28C28'); // docs/02 §Shared objects
      expect(w.source, 'scenario'); // the fixture was generated with ?scenario=thunderstorm

      // docs/04: banner is the highest active warning at orange or above.
      expect(home.banner, isNotNull);
      expect(home.banner!.warningId, w.id);
      expect(home.banner!.severity, 'orange');
    });

    test('every card obeys the docs/04 Card enums', () {
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

      expect(home.allCards, isNotEmpty);
      for (final card in home.allCards) {
        expect(card.type, isNotEmpty);
        expect(card.instanceId, isNotEmpty);
        expect(card.title, isNotEmpty);
        expect(sizes, contains(card.size), reason: '${card.type}.size');
        expect(severities, contains(card.severity), reason: '${card.type}.severity');
        expect(card.urgency, inInclusiveRange(0, 1), reason: '${card.type}.urgency');
        // Not a probability — docs/03's `0.5*rel*ctx + 0.5*urg + eng` plus boosts can exceed 1.
        expect(card.score, greaterThanOrEqualTo(0), reason: '${card.type}.score');
        expect(card.insight, isNotNull, reason: '${card.type}.insight');
        expect(card.insight!.headline, isNotEmpty);
        expect(card.updatedAt, isNotNull);
        for (final a in card.actions) {
          expect(actionIds, contains(a.id), reason: '${card.type} action ${a.id}');
        }
        for (final p in card.personas) {
          expect(personaIds, contains(p), reason: '${card.type} persona $p');
        }
      }
    });

    test('severity is consistent with the urgency bands in docs/02', () {
      String bandFor(double u) {
        if (u < 0.3) return 'info';
        if (u < 0.5) return 'advisory';
        if (u < 0.7) return 'watch';
        if (u < 0.85) return 'warning';
        return 'severe';
      }

      for (final card in home.allCards) {
        expect(card.severity, bandFor(card.urgency),
            reason: '${card.type}: urgency ${card.urgency}');
      }
    });

    test('anything modelled is labelled estimated (CLAUDE.md §6)', () {
      for (final card in home.allCards) {
        if (card.source == 'estimated') {
          expect(card.isEstimated, isTrue, reason: '${card.type} must show the Estimated chip');
        }
      }
      // docs/PROGRESS.md §A1 — pollen is always modelled for Indian coordinates, and the
      // commute/traffic block has no free data source either.
      for (final type in <String>['pollen', 'commute_conditions']) {
        final card = home.allCards.firstWhere((c) => c.type == type);
        expect(card.source, 'estimated', reason: type);
        expect(card.isEstimated, isTrue, reason: '$type must show the Estimated chip');
      }
    });

    test('hourly and daily payloads have the documented lengths', () {
      final hourly = home.cards.firstWhere((c) => c.type == 'hourly_forecast');
      // docs/02 card 4 asks for 24 h; the engine emits what is left of the 48 h window from
      // `now` (17 at 07:30), and trims to 12 under `?lite=1`. The renderer must not assume 24.
      expect((hourly.data['hours'] as List).length, inInclusiveRange(12, 24));
      final daily = home.cards.firstWhere((c) => c.type == 'daily_forecast');
      expect((daily.data['days'] as List).length, 7); // docs/02 card 5
      final extended = home.moreCards.firstWhere((c) => c.type == 'extended_forecast');
      expect((extended.data['days'] as List).length, 14); // docs/02 card 6
    });

    test('round-trips through toJson without losing card identity', () {
      final again = HomeResponse.fromJson(
          jsonDecode(jsonEncode(home.toJson())) as Map<String, dynamic>);
      expect(again.allCards.map((c) => c.type).toList(),
          home.allCards.map((c) => c.type).toList());
      expect(again.banner?.warningId, home.banner?.warningId);
      expect(again.hero?.data['temp_c'], home.hero?.data['temp_c']);
    });
  });

  group('models degrade instead of throwing', () {
    test('an empty map yields a usable HomeResponse', () {
      final empty = HomeResponse.fromJson(<String, dynamic>{});
      expect(empty.cards, isEmpty);
      expect(empty.hero, isNull);
      expect(empty.banner, isNull);
      expect(empty.location.name, 'Unknown');
    });

    test('wrongly-typed fields are coerced, not fatal', () {
      final card = HomeCard.fromJson(<String, dynamic>{
        'type': 'aqi',
        'title': 'Air quality',
        'urgency': '0.5', // string instead of number
        'reasons': 'not-a-list',
        'data': 'not-a-map',
        'personas': <dynamic>[null, 'health'],
      });
      expect(card.urgency, 0.5);
      expect(card.instanceId, 'aqi'); // falls back to type
      expect(card.reasons, isEmpty);
      expect(card.data, isEmpty);
      expect(card.personas, <String>['health']);
      expect(card.renderer, 'generic');
    });

    test('User parses the docs/04 shape', () {
      final user = User.fromJson(<String, dynamic>{
        'id': 'usr_1',
        'is_guest': true,
        'language': 'hi',
        'personas': [
          {'id': 'parent', 'weight': 1.0},
          {'id': 'commuter', 'weight': 0.7},
        ],
        'school_windows': [
          {'label': 'morning_drop', 'start': '07:00', 'end': '09:00'},
        ],
      });
      expect(user.personaIds, <String>['parent', 'commuter']);
      expect(user.personas.last.weight, 0.7);
      expect(user.schoolWindows.single.label, 'morning_drop');
      expect(user.language, 'hi');
    });
  });

  group('formatters keep the location wall clock', () {
    test('an offset timestamp is not shifted into the device timezone', () {
      // docs/04: times carry the location's offset. 07:30+05:30 must read 07:30 anywhere.
      expect(Fmt.time('2026-09-08T07:30:00+05:30'), '07:30');
      expect(Fmt.dayShort('2026-09-08'), 'Tue');
    });

    test('missing values never throw', () {
      expect(Fmt.time(null), '--:--');
      expect(Fmt.temp(null), '--°');
      expect(Fmt.pct(null), '--');
      expect(Fmt.humanize('school_commute'), 'School Commute');
    });
  });

  test('the fixture file lives where pubspec declares it', () {
    expect(File(sampleHomePath).existsSync(), isTrue);
  });
}
