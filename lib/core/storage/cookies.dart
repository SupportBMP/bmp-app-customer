import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-side replacement for the website's js-cookie helpers
/// (`getCookieItem` / `setCookieItem` / `removeCookieItem` in utils/utils.jsx).
///
/// Values are cached in memory so reads stay synchronous like `Cookies.get`.
/// The access token lives in secure storage; everything else in prefs.
class Cookies {
  Cookies._();

  static const _secureKeys = {'accessToken'};
  static const _secure = FlutterSecureStorage();
  static late SharedPreferences _prefs;
  static final Map<String, String> _cache = {};

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    for (final k in _prefs.getKeys()) {
      if (!k.startsWith('cookie:')) continue;
      final v = _prefs.getString(k);
      if (v != null) _cache[k.substring(7)] = v;
    }
    for (final k in _secureKeys) {
      try {
        final v = await _secure.read(key: k);
        if (v != null) _cache[k] = v;
      } catch (_) {
        // A keystore reset leaves the user signed out; nothing else to do.
      }
    }
  }

  static String? get(String key) => _cache[key];

  /// Like the website, non-token values are lower-cased.
  static void set(String key, String value) {
    final v = _secureKeys.contains(key) ? value : value.toLowerCase();
    _cache[key] = v;
    if (_secureKeys.contains(key)) {
      _secure.write(key: key, value: v);
    } else {
      _prefs.setString('cookie:$key', v);
    }
  }

  static void remove(String key) {
    _cache.remove(key);
    if (_secureKeys.contains(key)) {
      _secure.delete(key: key);
    } else {
      _prefs.remove('cookie:$key');
    }
  }

  static SharedPreferences get prefs => _prefs;
}
