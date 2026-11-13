import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/bmp_api.dart';
import '../storage/cookies.dart';
import '../utils/json.dart';

/// commons/constants.js
const defaultLocationName = 'bangalore';
const defaultLanguageName = 'hindi';
const visibleLocationNames = ['Bangalore', 'Delhi', 'Chennai', 'Mumbai', 'Pune', 'Hyderabad', 'E-Pooja'];

String _locKey(String? name) => (name ?? '').toLowerCase().replaceAll(RegExp(r'[\s-]+'), '');

/// utils/locLangUtils.js `isVisibleLocation`.
bool isVisibleLocation(String? name) => visibleLocationNames.map(_locKey).contains(_locKey(name));

/// utils/locLangUtils.js `filterVisibleLocations`.
List<Json> filterVisibleLocations(List<Json> list) {
  final order = visibleLocationNames.map(_locKey).toList();
  final out = list.where((l) => isVisibleLocation(str(l['locationName']))).toList();
  out.sort((a, b) => order.indexOf(_locKey(str(a['locationName']))).compareTo(order.indexOf(_locKey(str(b['locationName'])))));
  return out;
}

/// Redux `locationandlanguages.locations.body` (store/slices/loclangslice.js).
final locationsProvider = FutureProvider<List<Json>>((ref) async {
  final res = await BmpApi.allLocations();
  return objList(obj(res.data)['body']);
});

/// Redux `locationandlanguages.languages.body` (fetched with status=1).
final languagesProvider = FutureProvider<List<Json>>((ref) async {
  final res = await BmpApi.allLanguages(1);
  return objList(obj(res.data)['body']);
});

/// `findLocLangIds`.
({String? locationId, String? languageId}) findLocLangIds(
  List<Json> locations,
  List<Json> languages,
  String? locName,
  String? langName,
) {
  final loc = locations.where((l) => str(l['locationName']).toLowerCase() == (locName ?? '').toLowerCase());
  final lang = languages.where((l) => str(l['languageName']).toLowerCase() == (langName ?? '').toLowerCase());
  return (
    locationId: loc.isEmpty ? null : strOrNull(loc.first['_id']),
    languageId: lang.isEmpty ? null : strOrNull(lang.first['_id']),
  );
}

/// The visitor's chosen city/language — the website keeps these in the
/// `location_name` / `language_name` (+ id) cookies.
class LocLang {
  const LocLang(this.location, this.language);
  final String location;
  final String language;
}

class LocLangNotifier extends Notifier<LocLang> {
  @override
  LocLang build() => LocLang(
        Cookies.get('location_name') ?? defaultLocationName,
        Cookies.get('language_name') ?? defaultLanguageName,
      );

  /// Mirrors UpperSection's cookie sync once ids are known.
  void select({String? location, String? language, String? locationId, String? languageId}) {
    if (location != null) Cookies.set('location_name', location);
    if (language != null) Cookies.set('language_name', language);
    if (locationId != null) Cookies.set('location', locationId);
    if (languageId != null) Cookies.set('language', languageId);
    state = LocLang(location?.toLowerCase() ?? state.location, language?.toLowerCase() ?? state.language);
  }
}

final locLangProvider = NotifierProvider<LocLangNotifier, LocLang>(LocLangNotifier.new);

/// hooks/useV2GlobalData.js — `/pooja-global/home-v2` with a 6-hour cache.
final v2GlobalDataProvider = FutureProvider<Json>((ref) async {
  const cacheKey = 'v2_global_data_cache';
  const cacheMs = 6 * 60 * 60 * 1000;
  final location = Cookies.get('location') ?? Cookies.get('location_name') ?? defaultLocationName;
  final language = Cookies.get('language') ?? Cookies.get('language_name') ?? '';
  final key = '${cacheKey}_${location}_$language';
  final cached = Cookies.prefs.getString(key);
  if (cached != null) {
    try {
      final c = obj(jsonDecode(cached));
      if (DateTime.now().millisecondsSinceEpoch - intOf(c['timestamp']) < cacheMs) {
        return obj(c['payload']);
      }
    } catch (_) {}
  }
  final res = await BmpApi.homeV2(location: location, language: language);
  final payload = obj(obj(res.data)['body']);
  Cookies.prefs.setString(
    key,
    jsonEncode({'timestamp': DateTime.now().millisecondsSinceEpoch, 'payload': payload}),
  );
  return payload;
});

/// The homepage's own `getStaticProps` call (no cache, no loc/lang).
final homepageDataProvider = FutureProvider<Json>((ref) async {
  final res = await BmpApi.homeV2();
  return obj(obj(res.data)['body']);
});

/// Signed-in user (`getUserDetails` → `/auth`), or null when signed out.
class AuthNotifier extends AsyncNotifier<Json?> {
  @override
  Future<Json?> build() async {
    final token = Cookies.get('accessToken');
    if (token == null || token.isEmpty) return null;
    try {
      final res = await BmpApi.userDetails(token);
      if (res.statusCode == 200) return obj(obj(res.data)['body']);
    } catch (_) {
      // Offline or server down: keep the session rather than signing out.
      return const <String, dynamic>{};
    }
    return null;
  }

  String? get token => Cookies.get('accessToken');

  void setToken(String token) {
    Cookies.set('accessToken', token);
    ref.invalidateSelf();
  }

  Future<void> refresh() async => ref.invalidateSelf();

  void logout() {
    Cookies.remove('accessToken');
    state = const AsyncData(null);
  }
}

final authProvider = AsyncNotifierProvider<AuthNotifier, Json?>(AuthNotifier.new);

/// Whether the app may show signed-in screens: a stored token whose user is
/// not a guest (userType 3). While the user is (re)loading the token alone
/// counts: a refresh keeps the previous value, which right after sign-in is
/// the signed-out `null` and would bounce the user back to /auth.
bool isSignedIn(AsyncValue<Json?> auth) {
  final token = Cookies.get('accessToken');
  if (token == null || token.isEmpty) return false;
  if (auth.isLoading || !auth.hasValue) return true;
  final user = auth.value;
  return user != null && intOf(user['userType']) != 3;
}

/// `checkUserDetailsIfCompleteOrNot`.
bool isUserDetailsComplete(Json? u) =>
    u != null && str(u['email']).isNotEmpty && str(u['phone']).isNotEmpty;

/// The guest flow (`handleGuestLoginFlow`) — a throwaway account so carts
/// can be created before OTP.
Future<bool> guestLogin(WidgetRef ref) async {
  try {
    final res = await BmpApi.guestLogin();
    final d = obj(res.data);
    if (res.statusCode == 201 && intOf(d['statusCode']) == 200) {
      final token = str(pick(d, ['body', 'accessToken']));
      Cookies.set('accessToken', token);
      return true;
    }
  } catch (_) {}
  return false;
}
