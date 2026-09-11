import 'package:shared_preferences/shared_preferences.dart';

import '../api_client.dart';
import '../models/json.dart';
import '../models/user.dart';

/// docs/04 `POST /auth/guest`, `GET /me`, `PUT /me/profile`.
///
/// The app only uses the guest flow: onboarding finishes with a guest token plus a profile
/// PUT; the backend's OTP login is not wired up here. Every call degrades gracefully — a
/// demo must still run with the
/// backend switched off, so a failed token fetch simply leaves the app unauthenticated and the
/// home repository falls back to cache/fixture.
class AuthRepo {
  AuthRepo({required this._api, this._prefs});

  static const _kToken = 'auth_token';

  final ApiClient _api;
  SharedPreferences? _prefs;

  Future<SharedPreferences> _p() async => _prefs ??= await SharedPreferences.getInstance();

  Future<String?> loadStoredToken() async {
    final token = (await _p()).getString(_kToken);
    _api.token = token;
    return token;
  }

  Future<void> _store(String? token) async {
    _api.token = token;
    final p = await _p();
    if (token == null) {
      await p.remove(_kToken);
    } else {
      await p.setString(_kToken, token);
    }
  }

  /// Returns the token, or null when the backend is unreachable.
  Future<String?> ensureGuestToken({bool force = false}) async {
    if (!force) {
      final existing = await loadStoredToken();
      if (existing != null && existing.isNotEmpty) return existing;
    }
    try {
      final res = await _api.postJson('/auth/guest');
      final token = asStringOrNull(res['token']);
      if (token != null) await _store(token);
      return token;
    } on ApiException {
      return null;
    }
  }

  Future<User?> me() async {
    try {
      return User.fromJson(await _api.getJson('/me'));
    } on ApiException {
      return null;
    }
  }

  /// docs/04 `PUT /me/profile` — partial body of
  /// `personas, language, units, home_location, school_windows, commute_windows`.
  Future<User?> updateProfile(Map<String, dynamic> patch) async {
    try {
      return User.fromJson(await _api.putJson('/me/profile', body: patch));
    } on ApiException {
      return null;
    }
  }

  Future<void> signOut() => _store(null);
}
