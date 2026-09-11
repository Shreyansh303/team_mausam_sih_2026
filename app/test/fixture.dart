import 'dart:convert';
import 'dart:io';

/// The bundled sample payload, read straight from disk so the tests do not need an asset
/// bundle. Declared in `pubspec.yaml` under `flutter/assets`.
///
/// This file is a byte-for-byte copy of `docs/fixtures/home_severe.json` — real `/home`
/// output from the engine (parent, New Delhi, `scenario=thunderstorm`, orange banner, four
/// pinned cards), not a hand-written payload.
const String sampleHomePath = 'assets/fixtures/home_sample.json';

/// The ten reference payloads generated from the real engine. `flutter test` runs with the
/// package root (`app/`) as its working directory, so they sit one level up.
const String docsFixtureDir = '../docs/fixtures';

Map<String, dynamic> loadSampleHomeJson() => _readJson(File(sampleHomePath));

/// Every `docs/fixtures/home_*.json`, sorted, as (file name, decoded payload) pairs.
///
/// The whole set is exercised by `fixtures_test.dart`: the app must parse and render anything
/// the backend can produce, not only the one payload it bundles.
List<MapEntry<String, Map<String, dynamic>>> loadDocsFixtures() {
  final dir = Directory(docsFixtureDir);
  if (!dir.existsSync()) {
    throw StateError(
      'docs/fixtures not found at $docsFixtureDir — run `flutter test` from the app/ directory '
      'of the repository.',
    );
  }
  final files = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  return <MapEntry<String, Map<String, dynamic>>>[
    for (final f in files) MapEntry(f.uri.pathSegments.last, _readJson(f)),
  ];
}

/// One named payload out of `docs/fixtures/`, e.g. `loadDocsFixture('home_parent.json')`.
Map<String, dynamic> loadDocsFixture(String name) => _readJson(File('$docsFixtureDir/$name'));

Map<String, dynamic> _readJson(File file) =>
    jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
