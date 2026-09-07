import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A cached payload plus the moment it was written.
class CacheEntry {
  const CacheEntry({required this.data, required this.storedAt});

  final Map<String, dynamic> data;
  final DateTime storedAt;

  Duration get age => DateTime.now().difference(storedAt);
}

/// docs/06_MOBILE_SPEC.md §Layout `data/cache/json_file_cache.dart` —
/// "per key file under app documents dir; get/put with timestamp".
///
/// On the web there is no documents directory, so the same contract is served out of
/// `SharedPreferences` (localStorage). The home screen's cache-first load therefore works
/// identically in the web build used for the judge demo.
class JsonFileCache {
  JsonFileCache({this._directory});

  Directory? _directory;
  Future<Directory>? _pending;

  static String _safe(String key) => key.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');

  Future<Directory> _dir() async {
    if (_directory != null) return _directory!;
    return _pending ??= () async {
      final base = await getApplicationDocumentsDirectory();
      final dir = Directory('${base.path}/mausam_cache');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      _directory = dir;
      return dir;
    }();
  }

  Future<void> put(String key, Map<String, dynamic> data) async {
    final envelope = <String, dynamic>{
      'stored_at': DateTime.now().toIso8601String(),
      'data': data,
    };
    final encoded = jsonEncode(envelope);
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cache_${_safe(key)}', encoded);
      return;
    }
    try {
      final dir = await _dir();
      await File('${dir.path}/${_safe(key)}.json').writeAsString(encoded, flush: true);
    } catch (_) {
      // A cache write must never break the screen that triggered it.
    }
  }

  Future<CacheEntry?> get(String key) async {
    String? raw;
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        raw = prefs.getString('cache_${_safe(key)}');
      } else {
        final file = File('${(await _dir()).path}/${_safe(key)}.json');
        if (!await file.exists()) return null;
        raw = await file.readAsString();
      }
    } catch (_) {
      return null;
    }
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final storedAt = DateTime.tryParse('${decoded['stored_at']}') ?? DateTime.now();
      final data = decoded['data'];
      if (data is! Map) return null;
      return CacheEntry(data: Map<String, dynamic>.from(data), storedAt: storedAt);
    } catch (_) {
      return null;
    }
  }

  Future<void> remove(String key) async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('cache_${_safe(key)}');
        return;
      }
      final file = File('${(await _dir()).path}/${_safe(key)}.json');
      if (await file.exists()) await file.delete();
    } catch (_) {
      // ignore
    }
  }

  Future<void> clear() async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        for (final k in prefs.getKeys().where((k) => k.startsWith('cache_')).toList()) {
          await prefs.remove(k);
        }
        return;
      }
      final dir = await _dir();
      if (await dir.exists()) await dir.delete(recursive: true);
      _directory = null;
      _pending = null;
    } catch (_) {
      // ignore
    }
  }
}
