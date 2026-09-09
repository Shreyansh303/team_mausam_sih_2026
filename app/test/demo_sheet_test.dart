import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mausam_app/features/demo/demo_sheet.dart';

/// docs/00 §Judge demo script step 2 — "Home at '7:30 AM' (time override in demo menu)".
///
/// C1 regression: the four presets used to be full ISO literals carrying the calendar date
/// they were written on. The backend only moves the reading to a demo hour it has a forecast
/// row for, so the morning after, "07:30" silently fell back to the live observation and the
/// hero drew whatever the real clock said.
void main() {
  test('the demo clock presets are built on today, not a hardcoded date', () {
    final today = DateTime.now();
    final stamp = '${today.year.toString().padLeft(4, '0')}-'
        '${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}';

    final presets = DemoSheet.clockPresets;
    expect(presets, hasLength(DemoSheet.clockHours.length));
    for (final iso in presets) {
      expect(iso, startsWith(stamp), reason: '$iso is not on today');
      expect(iso, endsWith('+05:30'), reason: 'docs/04 reads a bare demo clock as IST');
      expect(DateTime.tryParse(iso), isNotNull, reason: '$iso must parse');
    }

    // The chip label is the substring the sheet shows, so the hours must stay where it looks.
    expect(presets.map((iso) => iso.substring(11, 16)).toList(), DemoSheet.clockHours);
    expect(DemoSheet.clockHours.first, '07:30', reason: 'the school-run hour docs/00 names');
  });

  test('presetFor stamps the date it is given', () {
    expect(
      DemoSheet.presetFor('07:30', today: DateTime(2026, 1, 2)),
      '2026-01-02T07:30:00+05:30',
    );
  });

  test('every scenario chip has a scenario file behind it', () {
    // C1: `cold_wave` was offered with no `backend/app/data/scenarios/cold_wave.json`. The
    // backend answers an unknown scenario with live data, so the chip did nothing.
    final dir = Directory('../backend/app/data/scenarios');
    expect(dir.existsSync(), isTrue, reason: 'run this from app/ with the repo checked out');

    final shipped = dir
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .where((n) => n.endsWith('.json'))
        .map((n) => n.substring(0, n.length - 5))
        .toSet();

    expect(DemoSheet.scenarios.toSet(), shipped,
        reason: 'the sheet and docs/05 §Scenarios must name the same ten');
    expect(DemoSheet.scenarios.first, 'live');
    expect(DemoSheet.scenarios, hasLength(10));
  });

  test('no scenario chip mangles an acronym the rest of the app capitalises', () {
    // C1: the chip read "Severe Aqi" while the card it promotes is titled "AQI".
    expect(DemoSheet.scenarioLabel('severe_aqi'), 'Severe AQI');
    expect(DemoSheet.scenarioLabel('clear_pleasant'), 'Clear Pleasant');
    expect(DemoSheet.scenarioLabel('live'), 'Live');
    for (final name in DemoSheet.scenarios) {
      final label = DemoSheet.scenarioLabel(name);
      expect(label, isNotEmpty);
      expect(label.contains('_'), isFalse, reason: '$name still shows a raw key');
      expect(RegExp(r'\bAqi\b').hasMatch(label), isFalse,
          reason: '$name renders "$label" — AQI is written in capitals everywhere else');
    }
  });

  test('the custom time picker stamps today, like the presets do', () {
    // C1: "Pick a time" hardcoded 2026-09-08 long after the presets stopped doing so. The
    // backend only moves the reading to a demo hour it has a forecast row for, so a judge
    // picking 07:30 by hand got the live observation and a clock that appeared to do nothing.
    final today = DateTime.now();
    final ymd = '${today.year.toString().padLeft(4, '0')}-'
        '${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}';
    // The picker builds its override with exactly this call.
    expect(DemoSheet.presetFor('07:30'), '${ymd}T07:30:00+05:30');
    expect(DemoSheet.presetFor('23:05'), '${ymd}T23:05:00+05:30');

    final source = File('lib/features/demo/demo_sheet.dart').readAsStringSync();
    expect(RegExp(r"'20\d\d-\d\d-\d\dT").hasMatch(source), isFalse,
        reason: 'demo_sheet.dart has a hardcoded ISO date again — build it with presetFor');
  });
}
