import '../api_client.dart';
import '../models/json.dart';

/// docs/04 `GET/PUT /me/card-prefs` → `{pins:[type], hidden:[type]}`.
class CardPrefs {
  const CardPrefs({this.pins = const <String>[], this.hidden = const <String>[]});

  final List<String> pins;
  final List<String> hidden;

  bool get isEmpty => pins.isEmpty && hidden.isEmpty;

  factory CardPrefs.fromJson(Map<String, dynamic> json) => CardPrefs(
        pins: asStringList(json['pins']),
        hidden: asStringList(json['hidden']),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{'pins': pins, 'hidden': hidden};
}

/// docs/06_MOBILE_SPEC.md §Layout `profile_repo` — the `/me*` calls that are not authentication:
/// card preferences and the learning reset.
///
/// `pin/unpin/hide/unhide` are already written server-side by `POST /events` (docs/04
/// §Engagement events), so the app only *reads* prefs — to seed its local overlay after a fresh
/// install — and only writes them when the user restores everything at once.
class ProfileRepo {
  ProfileRepo({required ApiClient api}) : _api = api; // ignore: prefer_initializing_formals

  final ApiClient _api;

  Future<CardPrefs?> cardPrefs() async {
    try {
      return CardPrefs.fromJson(await _api.getJson('/me/card-prefs'));
    } on ApiException {
      return null;
    }
  }

  Future<CardPrefs?> saveCardPrefs(CardPrefs prefs) async {
    try {
      return CardPrefs.fromJson(await _api.putJson('/me/card-prefs', body: prefs.toJson()));
    } on ApiException {
      return null;
    }
  }

  /// docs/04 `POST /me/reset-learning` — clears engagement + prefs. Used by Settings.
  Future<bool> resetLearning() async {
    try {
      await _api.postJson('/me/reset-learning');
      return true;
    } on ApiException {
      return false;
    }
  }
}
