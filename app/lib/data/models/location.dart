import 'json.dart';

/// docs/04_API_CONTRACT.md §Objects `LocationResult`.
class LocationResult {
  const LocationResult({
    required this.id,
    required this.name,
    required this.lat,
    required this.lon,
    this.admin1,
    this.admin2,
    this.country,
    this.countryCode,
    this.timezone,
    this.isCoastal = false,
    this.elevationM,
    this.population,
  });

  final String id;
  final String name;
  final String? admin1;
  final String? admin2;
  final String? country;
  final String? countryCode;
  final double lat;
  final double lon;
  final String? timezone;
  final bool isCoastal;
  final num? elevationM;
  final num? population;

  /// "New Delhi, Delhi" — what the app bar and the location page show.
  String get subtitle {
    final parts = <String>[
      if ((admin1 ?? '').isNotEmpty && admin1 != name) admin1!,
      if ((country ?? '').isNotEmpty) country!,
    ];
    return parts.join(', ');
  }

  factory LocationResult.fromJson(Map<String, dynamic> json) => LocationResult(
        id: asString(json['id'], fallback: 'geo:${json['lat']},${json['lon']}'),
        name: asString(json['name'], fallback: 'Unknown'),
        admin1: asStringOrNull(json['admin1']),
        admin2: asStringOrNull(json['admin2']),
        country: asStringOrNull(json['country']),
        countryCode: asStringOrNull(json['country_code']),
        lat: asDouble(json['lat']) ?? 0,
        lon: asDouble(json['lon']) ?? 0,
        timezone: asStringOrNull(json['timezone']),
        isCoastal: asBool(json['is_coastal']),
        elevationM: asNum(json['elevation_m']),
        population: asNum(json['population']),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'admin1': admin1,
        'admin2': admin2,
        'country': country,
        'country_code': countryCode,
        'lat': lat,
        'lon': lon,
        'timezone': timezone,
        'is_coastal': isCoastal,
        'elevation_m': elevationM,
        'population': population,
      };
}

/// docs/04_API_CONTRACT.md §Objects `Place`.
class Place {
  const Place({
    required this.id,
    required this.name,
    required this.lat,
    required this.lon,
    this.country,
    this.countryCode,
    this.admin1,
    this.admin2,
    this.kind = 'other',
    this.timezone,
    this.isCoastal = false,
    this.createdAt,
  });

  final String id;
  final String name;
  final double lat;
  final double lon;
  final String? country;
  final String? countryCode;
  final String? admin1;
  final String? admin2;

  /// home|work|school|travel|other
  final String kind;
  final String? timezone;
  final bool isCoastal;
  final String? createdAt;

  factory Place.fromJson(Map<String, dynamic> json) => Place(
        id: asString(json['id']),
        name: asString(json['name']),
        lat: asDouble(json['lat']) ?? 0,
        lon: asDouble(json['lon']) ?? 0,
        country: asStringOrNull(json['country']),
        countryCode: asStringOrNull(json['country_code']),
        admin1: asStringOrNull(json['admin1']),
        admin2: asStringOrNull(json['admin2']),
        kind: asString(json['kind'], fallback: 'other'),
        timezone: asStringOrNull(json['timezone']),
        isCoastal: asBool(json['is_coastal']),
        createdAt: asStringOrNull(json['created_at']),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'lat': lat,
        'lon': lon,
        'country': country,
        'country_code': countryCode,
        'admin1': admin1,
        'admin2': admin2,
        'kind': kind,
        'timezone': timezone,
        'is_coastal': isCoastal,
        'created_at': createdAt,
      };
}
