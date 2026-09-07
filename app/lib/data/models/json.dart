/// Defensive JSON coercion helpers shared by every hand-written model.
///
/// docs/06_MOBILE_SPEC.md requires the generic renderer to "never crash on unknown cards";
/// the same applies to parsing — a field that is missing, null or of an unexpected type must
/// degrade, not throw. There is no build_runner codegen in this project by design (docs/06).
library;

String asString(Object? v, {String fallback = ''}) {
  if (v == null) return fallback;
  if (v is String) return v;
  return v.toString();
}

String? asStringOrNull(Object? v) {
  if (v == null) return null;
  if (v is String) return v.isEmpty ? null : v;
  return v.toString();
}

num? asNum(Object? v) {
  if (v == null) return null;
  if (v is num) return v;
  if (v is String) return num.tryParse(v);
  return null;
}

double? asDouble(Object? v) => asNum(v)?.toDouble();

int? asInt(Object? v) => asNum(v)?.round();

bool asBool(Object? v, {bool fallback = false}) {
  if (v == null) return fallback;
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) return v == 'true' || v == '1' || v == 'yes';
  return fallback;
}

/// A JSON object, or an empty map when the value is anything else.
Map<String, dynamic> asMap(Object? v) {
  if (v is Map) return Map<String, dynamic>.from(v);
  return <String, dynamic>{};
}

Map<String, dynamic>? asMapOrNull(Object? v) {
  if (v is Map) return Map<String, dynamic>.from(v);
  return null;
}

/// A JSON array of objects, mapped through [fromJson]; non-objects are skipped.
List<T> asList<T>(Object? v, T Function(Map<String, dynamic>) fromJson) {
  if (v is! List) return <T>[];
  final out = <T>[];
  for (final item in v) {
    final m = asMapOrNull(item);
    if (m != null) out.add(fromJson(m));
  }
  return out;
}

List<String> asStringList(Object? v) {
  if (v is! List) return <String>[];
  return v.where((e) => e != null).map((e) => asString(e)).toList();
}
