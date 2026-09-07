import '../api_client.dart';
import '../models/json.dart';
import '../models/location.dart';

/// docs/04 `/locations/search`, `/locations/reverse`, `/locations/popular`.
///
/// The onboarding location page must work with the backend switched off, so `popular` falls back
/// to a small built-in list of Indian cities (coastal + hill + metros, matching the curated set
/// the backend serves from `data/cities.json`).
class LocationsRepo {
  LocationsRepo({required this._api});

  final ApiClient _api;

  Future<List<LocationResult>> search(String q, {int limit = 8}) async {
    if (q.trim().length < 2) return const <LocationResult>[];
    try {
      final list = await _api.getList('/locations/search', query: {'q': q, 'limit': limit});
      return list
          .map(asMapOrNull)
          .whereType<Map<String, dynamic>>()
          .map(LocationResult.fromJson)
          .toList();
    } on ApiException {
      final needle = q.trim().toLowerCase();
      return fallbackCities
          .where((c) => c.name.toLowerCase().contains(needle))
          .take(limit)
          .toList();
    }
  }

  Future<LocationResult?> reverse(double lat, double lon) async {
    try {
      return LocationResult.fromJson(
          await _api.getJson('/locations/reverse', query: {'lat': lat, 'lon': lon}));
    } on ApiException {
      return LocationResult(
        id: 'geo:${lat.toStringAsFixed(2)},${lon.toStringAsFixed(2)}',
        name: 'My location',
        lat: lat,
        lon: lon,
        country: 'India',
        countryCode: 'IN',
      );
    }
  }

  Future<List<LocationResult>> popular() async {
    try {
      final list = await _api.getList('/locations/popular');
      final parsed = list
          .map(asMapOrNull)
          .whereType<Map<String, dynamic>>()
          .map(LocationResult.fromJson)
          .toList();
      if (parsed.isNotEmpty) return parsed;
      return fallbackCities;
    } on ApiException {
      return fallbackCities;
    }
  }

  /// Offline fallback for the onboarding grid. Coordinates match `backend/app/data/cities.json`.
  static const List<LocationResult> fallbackCities = <LocationResult>[
    LocationResult(
        id: 'city:delhi',
        name: 'New Delhi',
        admin1: 'Delhi',
        country: 'India',
        countryCode: 'IN',
        lat: 28.61,
        lon: 77.21,
        timezone: 'Asia/Kolkata'),
    LocationResult(
        id: 'city:mumbai',
        name: 'Mumbai',
        admin1: 'Maharashtra',
        country: 'India',
        countryCode: 'IN',
        lat: 19.08,
        lon: 72.88,
        timezone: 'Asia/Kolkata',
        isCoastal: true),
    LocationResult(
        id: 'city:bengaluru',
        name: 'Bengaluru',
        admin1: 'Karnataka',
        country: 'India',
        countryCode: 'IN',
        lat: 12.97,
        lon: 77.59,
        timezone: 'Asia/Kolkata'),
    LocationResult(
        id: 'city:chennai',
        name: 'Chennai',
        admin1: 'Tamil Nadu',
        country: 'India',
        countryCode: 'IN',
        lat: 13.08,
        lon: 80.27,
        timezone: 'Asia/Kolkata',
        isCoastal: true),
    LocationResult(
        id: 'city:kolkata',
        name: 'Kolkata',
        admin1: 'West Bengal',
        country: 'India',
        countryCode: 'IN',
        lat: 22.57,
        lon: 88.36,
        timezone: 'Asia/Kolkata'),
    LocationResult(
        id: 'city:hyderabad',
        name: 'Hyderabad',
        admin1: 'Telangana',
        country: 'India',
        countryCode: 'IN',
        lat: 17.39,
        lon: 78.49,
        timezone: 'Asia/Kolkata'),
    LocationResult(
        id: 'city:pune',
        name: 'Pune',
        admin1: 'Maharashtra',
        country: 'India',
        countryCode: 'IN',
        lat: 18.52,
        lon: 73.86,
        timezone: 'Asia/Kolkata'),
    LocationResult(
        id: 'city:ahmedabad',
        name: 'Ahmedabad',
        admin1: 'Gujarat',
        country: 'India',
        countryCode: 'IN',
        lat: 23.03,
        lon: 72.58,
        timezone: 'Asia/Kolkata'),
    LocationResult(
        id: 'city:jaipur',
        name: 'Jaipur',
        admin1: 'Rajasthan',
        country: 'India',
        countryCode: 'IN',
        lat: 26.91,
        lon: 75.79,
        timezone: 'Asia/Kolkata'),
    LocationResult(
        id: 'city:lucknow',
        name: 'Lucknow',
        admin1: 'Uttar Pradesh',
        country: 'India',
        countryCode: 'IN',
        lat: 26.85,
        lon: 80.95,
        timezone: 'Asia/Kolkata'),
    LocationResult(
        id: 'city:panaji',
        name: 'Panaji',
        admin1: 'Goa',
        country: 'India',
        countryCode: 'IN',
        lat: 15.49,
        lon: 73.83,
        timezone: 'Asia/Kolkata',
        isCoastal: true),
    LocationResult(
        id: 'city:puri',
        name: 'Puri',
        admin1: 'Odisha',
        country: 'India',
        countryCode: 'IN',
        lat: 19.81,
        lon: 85.83,
        timezone: 'Asia/Kolkata',
        isCoastal: true),
    LocationResult(
        id: 'city:kochi',
        name: 'Kochi',
        admin1: 'Kerala',
        country: 'India',
        countryCode: 'IN',
        lat: 9.93,
        lon: 76.27,
        timezone: 'Asia/Kolkata',
        isCoastal: true),
    LocationResult(
        id: 'city:visakhapatnam',
        name: 'Visakhapatnam',
        admin1: 'Andhra Pradesh',
        country: 'India',
        countryCode: 'IN',
        lat: 17.69,
        lon: 83.22,
        timezone: 'Asia/Kolkata',
        isCoastal: true),
    LocationResult(
        id: 'city:shimla',
        name: 'Shimla',
        admin1: 'Himachal Pradesh',
        country: 'India',
        countryCode: 'IN',
        lat: 31.10,
        lon: 77.17,
        timezone: 'Asia/Kolkata',
        elevationM: 2276),
    LocationResult(
        id: 'city:leh',
        name: 'Leh',
        admin1: 'Ladakh',
        country: 'India',
        countryCode: 'IN',
        lat: 34.16,
        lon: 77.58,
        timezone: 'Asia/Kolkata',
        elevationM: 3500),
    LocationResult(
        id: 'city:guwahati',
        name: 'Guwahati',
        admin1: 'Assam',
        country: 'India',
        countryCode: 'IN',
        lat: 26.14,
        lon: 91.74,
        timezone: 'Asia/Kolkata'),
    LocationResult(
        id: 'city:bhopal',
        name: 'Bhopal',
        admin1: 'Madhya Pradesh',
        country: 'India',
        countryCode: 'IN',
        lat: 23.26,
        lon: 77.41,
        timezone: 'Asia/Kolkata'),
  ];
}
