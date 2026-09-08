import '../api_client.dart';
import '../models/json.dart';
import '../models/location.dart';

/// docs/04 `/me/places` — `GET` list, `POST` add (**max 8**), `DELETE /me/places/{id}`.
///
/// Saved places are what the traveller cards read (docs/02 cards 25–27: saved-place strip,
/// packing, travel alerts), so this repository is also what makes those cards appear.
class PlacesRepo {
  PlacesRepo({required ApiClient api}) : _api = api; // ignore: prefer_initializing_formals

  /// docs/04 `POST /me/places` … "(max 8)".
  static const int maxPlaces = 8;

  /// docs/04 §Objects `Place.kind`.
  static const List<String> kinds = <String>['home', 'work', 'school', 'travel', 'other'];

  final ApiClient _api;

  Future<List<Place>> list() async {
    try {
      final raw = await _api.getList('/me/places');
      return raw
          .map(asMapOrNull)
          .whereType<Map<String, dynamic>>()
          .map(Place.fromJson)
          .toList();
    } on ApiException {
      return const <Place>[];
    }
  }

  /// Adds a place from a search result. Returns `null` when the backend refused it (an
  /// unreachable backend, or the ninth place).
  Future<Place?> add(LocationResult location, {String kind = 'travel'}) async {
    try {
      return Place.fromJson(await _api.postJson('/me/places', body: <String, dynamic>{
        'name': location.name,
        'lat': location.lat,
        'lon': location.lon,
        'country': location.country,
        'country_code': location.countryCode,
        'admin1': location.admin1,
        'admin2': location.admin2,
        'kind': kind,
      }));
    } on ApiException {
      return null;
    }
  }

  Future<bool> remove(String id) async {
    try {
      await _api.deleteJson('/me/places/$id');
      return true;
    } on ApiException {
      return false;
    }
  }
}
