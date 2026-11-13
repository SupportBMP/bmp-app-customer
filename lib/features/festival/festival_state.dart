import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../../core/state/app_state.dart';
import '../../core/storage/cookies.dart';
import '../../core/utils/json.dart';
import '../../core/utils/leads.dart';

/// Port of lib/festivalExperience.js + FestivalExperienceContext.jsx.
///
/// Pages ask for the experience of their own `pageType`; "quiet" pages
/// (booking, account, auth, enquiry, thank-you) never show festival surfaces,
/// matching the website's QUIET_PREFIXES — those screens simply don't read it.

String? _clean(String? v) =>
    v == null || v.isEmpty ? null : v.toLowerCase().replaceAll(RegExp(r'%20|\s+'), '-');

class FxKey {
  const FxKey(this.pageType, [this.location, this.language]);
  final String pageType;
  final String? location;
  final String? language;

  @override
  bool operator ==(Object other) =>
      other is FxKey && other.pageType == pageType && other.location == location && other.language == language;

  @override
  int get hashCode => Object.hash(pageType, location, language);
}

/// `fetchFestivalExperience` — fails soft to null (evergreen site).
final festivalExperienceProvider = FutureProvider.family<Json?, FxKey>((ref, key) async {
  try {
    final params = <String, String>{'pageType': key.pageType};
    final loc = _clean(key.location ?? Cookies.get('location_name'));
    final lang = _clean(key.language ?? Cookies.get('language_name'));
    if (loc != null) params['location'] = loc;
    if (lang != null) params['language'] = lang;
    final uri = Uri.parse(AppConfig.api('festival-experience/resolve')).replace(queryParameters: params);
    final res = await Dio(BaseOptions(receiveTimeout: const Duration(milliseconds: 2500)))
        .getUri(uri);
    final body = obj(res.data)['body'];
    return body is Map ? obj(body) : null;
  } catch (_) {
    return null;
  }
});

/// `fetchFestivalLanding`.
final festivalLandingProvider = FutureProvider.family<Json?, String>((ref, slug) async {
  try {
    final params = <String, String>{};
    final loc = _clean(Cookies.get('location_name'));
    final lang = _clean(Cookies.get('language_name'));
    if (loc != null) params['location'] = loc;
    if (lang != null) params['language'] = lang;
    final uri = Uri.parse(AppConfig.api('festival-experience/landing/${Uri.encodeComponent(slug)}'))
        .replace(queryParameters: params.isEmpty ? null : params);
    final res = await Dio(BaseOptions(receiveTimeout: const Duration(seconds: 5))).getUri(uri);
    final body = obj(res.data)['body'];
    return body is Map ? obj(body) : null;
  } catch (_) {
    return null;
  }
});

/// `useFestivalLocLang` — the city/language used for pooja links.
({String location, String language}) festivalLocLang(WidgetRef ref, {String? location, String? language}) {
  final ll = ref.watch(locLangProvider);
  String norm(String s) => s.toLowerCase().replaceAll(RegExp(r'\s+'), '-');
  return (
    location: norm(location ?? ll.location),
    language: norm(language ?? ll.language),
  );
}

/// `buildPoojaHref`.
String buildPoojaHref(Json pooja, String fallbackLanguage, String fallbackLocation) {
  final language = strOrNull(pooja['linkLanguage']) ?? fallbackLanguage;
  final location = strOrNull(pooja['linkLocation']) ?? fallbackLocation;
  return '/$language/$location/pooja/${str(pooja['slug'])}';
}

/// commons/festivalExperience/designPresets.js — the `utsav` preset.
class FxTheme {
  const FxTheme({
    required this.bg,
    required this.bg2,
    required this.fg,
    required this.muted,
    required this.accent,
    required this.accentFg,
    required this.border,
    required this.card,
    required this.day,
  });

  final Color bg;
  final Color bg2;
  final Color fg;
  final Color muted;
  final Color accent;
  final Color accentFg;
  final Color border;
  final Color card;
  final Color day;

  /// `hsl(355 70% 28%)` — the strip's middle gradient stop.
  static const stripMid = Color(0xFF79151E);

  static FxTheme of(String? preset, [String? dayColor]) => FxTheme(
        bg: const Color(0xFF4A1116),
        bg2: const Color(0xFFB3400F),
        fg: const Color(0xFFFBF7EF),
        muted: const Color(0xFFDDCBB0),
        accent: const Color(0xFFF6BB31),
        accentFg: const Color(0xFF421014),
        border: const Color(0xFFDDAC3C),
        card: const Color(0xFF5C1F24),
        day: parseHexColor(dayColor) ?? const Color(0xFF8A1C23),
      );
}

Color? parseHexColor(String? hex) {
  if (hex == null) return null;
  var h = hex.trim().replaceFirst('#', '');
  if (h.length == 3) h = h.split('').map((c) => '$c$c').join();
  if (h.length != 6) return null;
  final v = int.tryParse(h, radix: 16);
  return v == null ? null : Color(0xFF000000 | v);
}

// ---- leadCtas.jsx ----------------------------------------------------------

const leadPhone = '9869929292';
const leadPhoneLabel = '9869 92 92 92';

/// "Navratri" + "navratri-2026" → "NAV26".
String campaignCodeOf(Json? campaign) {
  if (campaign == null) return 'FEST';
  final year = RegExp(r'(\d{4})').firstMatch(str(campaign['slug']))?.group(1) ?? '';
  final name = str(campaign['festivalName'], 'FEST').replaceAll(RegExp('[^a-z]', caseSensitive: false), '');
  return '${name.substring(0, name.length < 3 ? name.length : 3).toUpperCase()}${year.length >= 2 ? year.substring(2) : ''}';
}

const placementCodes = {
  'home.hero': 'HH',
  'home.hero.card': 'HC',
  'home.hero.consult': 'HQ',
  'home.next': 'HN',
  'listing.collection.card': 'LC',
  'listing.collection.callback': 'LQ',
  'category.context.card': 'CC',
  'category.context.callback': 'CQ',
  'pdp.related.card': 'PC',
  'nudge.popup': 'NP',
  'nudge.toast': 'NT',
  'festival.sticky': 'FS',
  'festival.inline': 'FI',
  'festival.exit': 'FX',
  'festival.guidance': 'FG',
  'festival.final': 'FF',
};

String placementCodeOf(String slot) => placementCodes[slot.replaceAll(RegExp(r'\.success$'), '')] ?? 'WEB';

String leadRefOf(Json? campaign, String slot) => '${campaignCodeOf(campaign)}-${placementCodeOf(slot)}';

String festivalWaLink({Json? campaign, required String slot, String? pooja, String? city, String? intent}) {
  final festival = strOrNull(campaign?['festivalName']);
  final subject = pooja != null ? '$pooja for ${festival ?? 'the festival'}' : 'a ${festival ?? 'festival'} puja';
  final ask = intent ?? "I'd like help with $subject";
  final cityLine = city != null && city.isNotEmpty ? '\nCity: ${titleCase(city)}' : '';
  final msg = 'Namaste BookMyPooja 🙏 $ask.$cityLine\n\nRef: ${leadRefOf(campaign, slot)}';
  return 'https://wa.me/${AppConfig.whatsappNumber}?text=${Uri.encodeComponent(msg)}';
}

String festivalTodayLine(Json exp) {
  final activeDay = exp['activeDay'];
  final phase = str(exp['phase']);
  final firstDay = exp['firstDay'];
  if (activeDay is Map) {
    final d = obj(activeDay);
    final colorName = strOrNull(d['colorName']);
    return colorName != null ? '${str(d['name'])} · colour of the day: $colorName' : str(d['name']);
  }
  if (phase == 'teaser' && firstDay is Map) {
    return 'Begins ${str(firstDay['shortDate'])} · ${str(firstDay['name'])}';
  }
  if (phase == 'afterglow') return 'All days complete';
  return str(pick(exp, ['primaryCampaign', 'name']));
}

String festivalPoojaHeading(Json exp) {
  final activeDay = exp['activeDay'];
  if (str(exp['mappingSource']) == 'child' && activeDay is Map) {
    return 'For ${str(activeDay['name']).split(' · ').first}';
  }
  return '${str(pick(exp, ['primaryCampaign', 'festivalName']))} pujas';
}

/// IST calendar date used for the nudge frequency caps.
String istDate() =>
    DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30)).toIso8601String().substring(0, 10);

/// Session-scoped flags (the website's sessionStorage). Persisted so a
/// session survives the app being closed and reopened; it ends after
/// [SessionFlags.timeout] away from the app.
final fxSessionFlags = SessionFlags._();

class SessionFlags with WidgetsBindingObserver {
  SessionFlags._();

  static const timeout = Duration(minutes: 30);
  static const _flagsKey = 'bmp_session_flags';
  static const _seenKey = 'bmp_session_last_seen';

  Set<String>? _flags;

  Set<String> get _current {
    if (_flags == null) {
      WidgetsBinding.instance.addObserver(this);
      _flags = _load();
    }
    return _flags!;
  }

  bool contains(String key) => _current.contains(key);

  void add(String key) {
    if (_current.add(key)) Cookies.prefs.setStringList(_flagsKey, _current.toList());
  }

  void remove(String key) {
    if (_current.remove(key)) Cookies.prefs.setStringList(_flagsKey, _current.toList());
  }

  /// Restores the stored flags unless the last session has expired.
  Set<String> _load() {
    final prefs = Cookies.prefs;
    final seen = prefs.getInt(_seenKey);
    final now = DateTime.now().millisecondsSinceEpoch;
    final expired = seen == null || now - seen > timeout.inMilliseconds;
    if (expired) prefs.remove(_flagsKey);
    _touch();
    return expired ? <String>{} : {...?prefs.getStringList(_flagsKey)};
  }

  void _touch() => Cookies.prefs.setInt(_seenKey, DateTime.now().millisecondsSinceEpoch);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _touch();
    } else if (state == AppLifecycleState.resumed) {
      _flags = _load();
    }
  }
}

const exitIntentSessionKey = 'bmpo_exit_shown';

/// Set while the pooja listing is in list view (grid is the default).
const poojaListViewSessionKey = 'bmp_pooja_list_view';
