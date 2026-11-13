import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../utils/json.dart';
import '../site_image.dart';
import 'app_drawer.dart';
import 'preferences_sheet.dart';
import 'search_screen.dart';
import 'user_menu.dart';

/// The app's navbar on every page: menu, logo and account on top, then a
/// search pill (opens the full-screen search) and a city · language chip
/// (opens the preferences sheet).
///
/// [city]/[language] override the saved choice (pages under
/// `/[language]/[location]` pass their route params, like `router.query`).
class UpperSection extends ConsumerStatefulWidget {
  const UpperSection({
    super.key,
    this.city,
    this.language,
    this.onCityChange,
    this.onLanguageChange,
    this.onCategorySelect,
  });

  final String? city;
  final String? language;
  final ValueChanged<String>? onCityChange;
  final ValueChanged<String>? onLanguageChange;
  final ValueChanged<String>? onCategorySelect;

  @override
  ConsumerState<UpperSection> createState() => _UpperSectionState();
}

class _UpperSectionState extends ConsumerState<UpperSection> {
  String _normalize(String value, List<String> items) =>
      items.firstWhere((i) => i.toLowerCase() == value.toLowerCase(), orElse: () => value);

  ({String city, String language, String? locationId, String? languageId}) _resolve() {
    final locations = ref.watch(locationsProvider).value ?? const [];
    final langs = ref.watch(languagesProvider).value ?? const [];
    final ll = ref.watch(locLangProvider);
    final cities = filterVisibleLocations(locations).map((l) => str(l['locationName'])).toList();
    final languages = langs.map((l) => str(l['languageName'])).toList();
    final city = _normalize(widget.city ?? ll.location, cities);
    final language = _normalize(widget.language ?? ll.language, languages);
    final ids = findLocLangIds(locations, langs, city, language);
    return (city: city, language: language, locationId: ids.locationId, languageId: ids.languageId);
  }

  void _goCity(String city, String language) {
    if (widget.onCityChange != null) {
      widget.onCityChange!(city);
    } else {
      _goListing(city, language);
    }
  }

  void _goLanguage(String language, String city) {
    if (widget.onLanguageChange != null) {
      widget.onLanguageChange!(language);
    } else {
      _goListing(city, language);
    }
  }

  /// Opens the listing for the pair; a listing page (route params passed in)
  /// is replaced rather than stacked.
  void _goListing(String city, String language) {
    final path = '/${language.toLowerCase()}/${city.toLowerCase()}/pooja';
    if (widget.city != null) {
      context.pushReplacement(path);
    } else {
      context.push(path);
    }
  }

  Future<void> _editPreferences(String city, String language, {bool focusLanguage = false}) async {
    final v = await showPreferencesSheet(context, city: city, language: language, focusLanguage: focusLanguage);
    if (v == null || !mounted) return;
    ref.read(locLangProvider.notifier).select(location: v.city, language: v.language);
    final cityChanged = v.city.toLowerCase() != city.toLowerCase();
    final langChanged = v.language.toLowerCase() != language.toLowerCase();
    if (cityChanged && langChanged && widget.onCityChange == null && widget.onLanguageChange == null) {
      _goListing(v.city, v.language);
    } else {
      if (langChanged) _goLanguage(v.language, v.city);
      if (cityChanged) _goCity(v.city, v.language);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _resolve();
    // Sync the saved choice once ids are known (UpperSection's cookie effect).
    if (r.locationId != null || r.languageId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final ll = ref.read(locLangProvider);
        if (ll.location != r.city.toLowerCase() || ll.language != r.language.toLowerCase()) {
          ref.read(locLangProvider.notifier).select(
                location: r.city,
                language: r.language,
                locationId: r.locationId,
                languageId: r.languageId,
              );
        }
      });
    }

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: AppColors.border)),
        boxShadow: [BoxShadow(color: Color(0x0D000000), blurRadius: 2, offset: Offset(0, 1))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Menu',
                  onPressed: () => openAppDrawer(
                    context,
                    city: r.city,
                    language: r.language,
                    onCity: (c) => _goCity(c, r.language),
                    onLanguage: (l) => _goLanguage(l, r.city),
                    onCategory: widget.onCategorySelect,
                  ),
                  icon: const Icon(LucideIcons.menu, size: 22, color: AppColors.foreground),
                ),
                Expanded(
                  child: Center(
                    child: GestureDetector(
                      onTap: () => context.go('/'),
                      child: const SiteImage('/images/bmp.png', height: 40, fit: BoxFit.contain, placeholderColor: Colors.transparent),
                    ),
                  ),
                ),
                const UserMenu(),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Expanded(child: _searchPill(r.city, r.language)),
                const SizedBox(width: 10),
                _placeChip(r.city, r.language),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchPill(String city, String language) => Material(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => openPoojaSearch(context, city: city, language: language),
          child: Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.border.o(.7)),
            ),
            child: Row(children: [
              const Icon(LucideIcons.search, size: 18, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Search pujas…',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body(size: 14, color: AppColors.mutedForeground)),
              ),
            ]),
          ),
        ),
      );

  Widget _placeChip(String city, String language) => Material(
        color: AppColors.primary.o(.06),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _editPreferences(city, language),
          child: Container(
            height: 46,
            constraints: const BoxConstraints(maxWidth: 136),
            padding: const EdgeInsets.only(left: 10, right: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.o(.15)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(LucideIcons.mapPin, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Flexible(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(city.isEmpty ? 'Select city' : capitalizeWords(city),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body(size: 13, weight: FontWeight.w700, height: 1.15)),
                    Text(language.isEmpty ? 'Language' : capitalizeWords(language),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body(size: 11, color: AppColors.mutedForeground, height: 1.2)),
                  ],
                ),
              ),
              const SizedBox(width: 2),
              const Icon(LucideIcons.chevronDown, size: 14, color: AppColors.mutedForeground),
            ]),
          ),
        ),
      );
}
