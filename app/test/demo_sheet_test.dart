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
}
