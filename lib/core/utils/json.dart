/// Loose JSON accessors for the BMP_BE payloads, which the website reads with
/// optional chaining (`a?.b?.[0]?.c`). Every helper tolerates nulls and
/// wrong types and falls back to an empty value.
library;

typedef Json = Map<String, dynamic>;

/// `value` as a map, or `{}`.
Json obj(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((k, v) => MapEntry('$k', v));
  return <String, dynamic>{};
}

/// `value` as a list, or `[]`.
List<dynamic> list(dynamic value) => value is List ? value : const [];

/// `value` as a list of maps (non-map entries dropped).
List<Json> objList(dynamic value) =>
    list(value).whereType<Map>().map(obj).toList();

/// `value` as a string; numbers and bools are stringified, null → [fallback].
String str(dynamic value, [String fallback = '']) {
  if (value == null) return fallback;
  if (value is String) return value;
  if (value is num || value is bool) return '$value';
  return fallback;
}

/// `value` as a nullable non-empty string.
String? strOrNull(dynamic value) {
  final s = str(value);
  return s.isEmpty ? null : s;
}

num numOf(dynamic value, [num fallback = 0]) {
  if (value is num) return value;
  if (value is String) return num.tryParse(value) ?? fallback;
  return fallback;
}

int intOf(dynamic value, [int fallback = 0]) => numOf(value, fallback).toInt();

double dbl(dynamic value, [double fallback = 0]) => numOf(value, fallback).toDouble();

bool boolOf(dynamic value, [bool fallback = false]) {
  if (value is bool) return value;
  if (value is String) return value.toLowerCase() == 'true';
  if (value is num) return value != 0;
  return fallback;
}

/// JS truthiness, for porting `a || b` / `a && ...` expressions.
bool truthy(dynamic v) {
  if (v == null) return false;
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) return v.isNotEmpty;
  return true;
}

/// Walks a path of keys/indexes: `pick(order, ['pooja', 'media', 0, 'mediaUrl'])`.
dynamic pick(dynamic root, List<Object> path) {
  dynamic cur = root;
  for (final p in path) {
    if (cur == null) return null;
    if (p is int) {
      if (cur is List && p >= 0 && p < cur.length) {
        cur = cur[p];
      } else {
        return null;
      }
    } else {
      if (cur is Map) {
        cur = cur[p];
      } else {
        return null;
      }
    }
  }
  return cur;
}
