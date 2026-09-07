import 'dart:convert';
import 'dart:io';

/// The bundled sample payload, read straight from disk so the tests do not need an asset
/// bundle. Declared in `pubspec.yaml` under `flutter/assets`.
const String sampleHomePath = 'assets/fixtures/home_sample.json';

Map<String, dynamic> loadSampleHomeJson() =>
    jsonDecode(File(sampleHomePath).readAsStringSync()) as Map<String, dynamic>;
