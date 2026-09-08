import 'package:intl/intl.dart';

/// docs/06_MOBILE_SPEC.md §Layout `core/formatters.dart`.
///
/// Every timestamp in the API is ISO-8601 **with the location's offset**
/// (docs/04 preamble). `DateTime.parse` keeps that offset only as a UTC flag, so we parse into
/// a "wall clock" `DateTime` that already reads in the location's local time and format it
/// without any further conversion — never `toLocal()`, which would re-interpret it in the
/// phone's zone and shift a Delhi 07:30 to something else on a non-IST device.
class Fmt {
  Fmt._();

  /// docs/04 §Objects `User.units` / docs/06 §settings_page "units". The API always answers in
  /// metric (docs/04 preamble), so the conversion is a display concern and lives here — one
  /// switch instead of a unit argument threaded through fifteen renderers. `SettingsNotifier`
  /// keeps it in step with the stored preference.
  static bool imperial = false;

  static num? toDisplayTemp(num? c) => c == null || !imperial ? c : c * 9 / 5 + 32;

  static num? toDisplaySpeed(num? kph) => kph == null || !imperial ? kph : kph * 0.621371;

  static String get tempUnit => imperial ? '°F' : '°C';

  static String get speedUnit => imperial ? 'mph' : 'km/h';

  static final RegExp _offsetSuffix = RegExp(r'^(.*?)(?:Z|[+-]\d{2}:?\d{2})?$');

  /// Parses an ISO-8601 string and returns the *wall clock at the location*.
  ///
  /// `DateTime.parse('2026-09-08T07:30:00+05:30')` yields a UTC `DateTime` reading 02:00, which
  /// would render a Delhi morning as 02:00 on a UK phone. We therefore drop the offset and parse
  /// the remainder naively, which is exactly what the UI should print.
  static DateTime? wallClock(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    final trimmed = iso.trim();
    final naive = _offsetSuffix.firstMatch(trimmed)?.group(1);
    if (naive != null && naive.isNotEmpty) {
      final parsed = DateTime.tryParse(naive);
      if (parsed != null) return parsed;
    }
    return DateTime.tryParse(trimmed);
  }

  /// The instant the timestamp refers to, for "how long ago" maths.
  static DateTime? instant(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    return DateTime.tryParse(iso)?.toUtc();
  }

  static String time(String? iso, {bool use24h = true}) {
    final dt = wallClock(iso);
    if (dt == null) return '--:--';
    return DateFormat(use24h ? 'HH:mm' : 'h:mm a').format(dt);
  }

  static String hourLabel(String? iso) {
    final dt = wallClock(iso);
    if (dt == null) return '--';
    return DateFormat('HH:mm').format(dt);
  }

  static String dayShort(String? isoOrDate) {
    final dt = wallClock(isoOrDate);
    if (dt == null) return '--';
    return DateFormat('EEE').format(dt);
  }

  static String dayLong(String? isoOrDate) {
    final dt = wallClock(isoOrDate);
    if (dt == null) return '--';
    return DateFormat('EEE d MMM').format(dt);
  }

  static String dateTime(String? iso) {
    final dt = wallClock(iso);
    if (dt == null) return '--';
    return DateFormat('d MMM, HH:mm').format(dt);
  }

  /// Whole minutes elapsed since [iso], clamped at 0. Used by the freshness chip.
  static int? minutesSince(String? iso, {DateTime? now}) {
    final then = instant(iso);
    if (then == null) return null;
    final delta = (now ?? DateTime.now().toUtc()).difference(then).inMinutes;
    return delta < 0 ? 0 : delta;
  }

  static String temp(num? c, {bool degreeOnly = false}) {
    final v = toDisplayTemp(c);
    if (v == null) return '--°';
    return degreeOnly ? '${v.round()}°' : '${v.round()}$tempUnit';
  }

  static String num1(num? v) {
    if (v == null) return '--';
    return v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1);
  }

  static String pct(num? v) => v == null ? '--' : '${v.round()}%';
  static String kph(num? v) {
    final d = toDisplaySpeed(v);
    return d == null ? '--' : '${d.round()} $speedUnit';
  }
  static String mm(num? v) => v == null ? '--' : '${num1(v)} mm';
  static String km(num? v) => v == null ? '--' : '${num1(v)} km';

  /// Turns `school_commute` / `morning_drop` into "School commute" / "Morning drop".
  static String humanize(String? key) {
    if (key == null || key.isEmpty) return '';
    final words = key.replaceAll('_', ' ').trim().split(RegExp(r'\s+'));
    return words
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}
