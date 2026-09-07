import 'json.dart';

/// docs/04_API_CONTRACT.md §Objects `Warning`.
class WeatherWarning {
  const WeatherWarning({
    required this.id,
    required this.severity,
    required this.hazard,
    required this.title,
    this.description = '',
    this.issuedAt,
    this.validFrom,
    this.validTo,
    this.district,
    this.state,
    this.lat,
    this.lon,
    this.radiusKm,
    this.source,
    this.colorHex,
  });

  final String id;

  /// yellow|orange|red
  final String severity;

  /// heavy_rain|very_heavy_rain|thunderstorm|lightning|squall|hail|heatwave|cold_wave|fog|
  /// dust_storm|cyclone|strong_wind|snow|flood|other
  final String hazard;
  final String title;
  final String description;
  final String? issuedAt;
  final String? validFrom;
  final String? validTo;
  final String? district;
  final String? state;
  final double? lat;
  final double? lon;
  final num? radiusKm;

  /// imd|admin|scenario
  final String? source;
  final String? colorHex;

  /// docs/04 pins/banners anything at orange or above.
  bool get isOrangeOrAbove => severity == 'orange' || severity == 'red';

  static const List<String> severityOrder = <String>['yellow', 'orange', 'red'];

  int get severityRank {
    final i = severityOrder.indexOf(severity);
    return i < 0 ? -1 : i;
  }

  factory WeatherWarning.fromJson(Map<String, dynamic> json) => WeatherWarning(
        id: asString(json['id']),
        severity: asString(json['severity'], fallback: 'yellow'),
        hazard: asString(json['hazard'], fallback: 'other'),
        title: asString(json['title']),
        description: asString(json['description']),
        issuedAt: asStringOrNull(json['issued_at']),
        validFrom: asStringOrNull(json['valid_from']),
        validTo: asStringOrNull(json['valid_to']),
        district: asStringOrNull(json['district']),
        state: asStringOrNull(json['state']),
        lat: asDouble(json['lat']),
        lon: asDouble(json['lon']),
        radiusKm: asNum(json['radius_km']),
        source: asStringOrNull(json['source']),
        colorHex: asStringOrNull(json['color_hex']),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'severity': severity,
        'hazard': hazard,
        'title': title,
        'description': description,
        'issued_at': issuedAt,
        'valid_from': validFrom,
        'valid_to': validTo,
        'district': district,
        'state': state,
        'lat': lat,
        'lon': lon,
        'radius_km': radiusKm,
        'source': source,
        'color_hex': colorHex,
      };
}

/// docs/04 `HomeResponse.banner` — the highest active warning at orange or above.
class HomeBanner {
  const HomeBanner({
    required this.warningId,
    required this.severity,
    required this.title,
    this.colorHex,
  });

  final String warningId;
  final String severity;
  final String title;
  final String? colorHex;

  factory HomeBanner.fromJson(Map<String, dynamic> json) => HomeBanner(
        warningId: asString(json['warning_id']),
        severity: asString(json['severity'], fallback: 'orange'),
        title: asString(json['title']),
        colorHex: asStringOrNull(json['color_hex']),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'warning_id': warningId,
        'severity': severity,
        'title': title,
        'color_hex': colorHex,
      };
}
