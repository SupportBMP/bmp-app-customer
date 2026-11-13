import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../api/bmp_api.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../utils/json.dart';
import '../toast.dart';
import '../ui.dart';

String capitalizeWords(String s) =>
    s.split(' ').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');

/// The city + language the visitor picked in [showPreferencesSheet].
typedef LocLangChoice = ({String city, String language});

/// One sheet for both choices that shape the pooja listing: the city (with
/// "use my location") and the language the pandit performs in. Resolves with
/// the new pair, or null when dismissed or nothing changed.
Future<LocLangChoice?> showPreferencesSheet(
  BuildContext context, {
  required String city,
  required String language,
  bool focusLanguage = false,
}) {
  HapticFeedback.selectionClick();
  return showModalBottomSheet<LocLangChoice>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _PreferencesSheet(city: city, language: language, focusLanguage: focusLanguage),
  );
}

class _PreferencesSheet extends ConsumerStatefulWidget {
  const _PreferencesSheet({required this.city, required this.language, required this.focusLanguage});
  final String city;
  final String language;
  final bool focusLanguage;

  @override
  ConsumerState<_PreferencesSheet> createState() => _PreferencesSheetState();
}

class _PreferencesSheetState extends ConsumerState<_PreferencesSheet> {
  late String _city = widget.city;
  late String _language = widget.language;
  bool _locating = false;
  final _languageKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (widget.focusLanguage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _languageKey.currentContext;
        if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 250));
      });
    }
  }

  bool _same(String a, String b) => a.toLowerCase() == b.toLowerCase();

  Future<void> _useMyLocation(List<String> cities) async {
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) throw 'Turn on location services to detect your city';
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        throw 'Location permission is needed to detect your city';
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 15)),
      );
      final r = await BmpApi.geoLocation(p.latitude, p.longitude);
      final name = str(pick(obj(r.data), ['body', 0, 'locationName']));
      final match = cities.where((c) => _same(c, name));
      if (match.isEmpty) throw "We don't serve your area yet. Pick the nearest city below.";
      HapticFeedback.selectionClick();
      setState(() => _city = match.first);
      Toast.success('Found you in ${capitalizeWords(match.first)}');
    } catch (e) {
      Toast.error(e is String ? e : "Couldn't detect your location");
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locations = ref.watch(locationsProvider).value ?? const [];
    final langs = ref.watch(languagesProvider).value ?? const [];
    final cities = filterVisibleLocations(locations).map((l) => str(l['locationName'])).toList();
    final languages = langs.map((l) => str(l['languageName'])).toList();
    final changed = !_same(_city, widget.city) || !_same(_language, widget.language);

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .85),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
          child: Text('Your puja preferences', style: AppText.body(size: 20, weight: FontWeight.w700)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: Text('We’ll show pujas and pandits available for you.',
              style: AppText.body(size: 14, color: AppColors.mutedForeground)),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const _SectionLabel(icon: LucideIcons.mapPin, text: 'City'),
              const SizedBox(height: 12),
              Material(
                color: AppColors.primary.o(.05),
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _locating ? null : () => _useMyLocation(cities),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(children: [
                      _locating
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                          : const Icon(LucideIcons.locateFixed, size: 18, color: AppColors.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(_locating ? 'Detecting your city…' : 'Use my current location',
                            style: AppText.body(size: 14, weight: FontWeight.w600, color: AppColors.primary)),
                      ),
                      const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.primary),
                    ]),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _ChoiceGrid(
                options: cities,
                selected: _city,
                iconOf: (c) => _same(c, 'e-pooja') ? LucideIcons.video : LucideIcons.building2,
                onSelect: (c) => setState(() => _city = c),
              ),
              const SizedBox(height: 24),
              _SectionLabel(key: _languageKey, icon: LucideIcons.languages, text: 'Puja language'),
              const SizedBox(height: 4),
              Text('The pandit will perform your puja in this language.',
                  style: AppText.body(size: 12, color: AppColors.mutedForeground)),
              const SizedBox(height: 12),
              _ChoiceGrid(
                options: languages,
                selected: _language,
                onSelect: (l) => setState(() => _language = l),
              ),
            ]),
          ),
        ),
        Container(
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
          padding: EdgeInsets.fromLTRB(24, 12, 24, 12 + MediaQuery.paddingOf(context).bottom),
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () => Navigator.of(context).pop(changed ? (city: _city, language: _language) : null),
            child: Text(
              changed ? 'Show pujas in ${capitalizeWords(_city)} · ${capitalizeWords(_language)}' : 'Done',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.body(size: 15, weight: FontWeight.w700, color: Colors.white),
            ),
          ),
        ),
      ]),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({super.key, required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 16, color: AppColors.mutedForeground),
        const SizedBox(width: 8),
        Text(text.toUpperCase(),
            style: AppText.body(size: 12, weight: FontWeight.w700, color: AppColors.mutedForeground, letterSpacing: .8)),
      ]);
}

/// A two-column grid of selectable tiles with a check on the chosen one.
class _ChoiceGrid extends StatelessWidget {
  const _ChoiceGrid({required this.options, required this.selected, required this.onSelect, this.iconOf});
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelect;
  final IconData Function(String)? iconOf;

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: AppSpinner(size: 36),
      );
    }
    return LayoutBuilder(builder: (context, c) {
      final w = (c.maxWidth - 10) / 2;
      return Wrap(spacing: 10, runSpacing: 10, children: [
        for (final o in options)
          SizedBox(width: w, child: _tile(o, o.toLowerCase() == selected.toLowerCase())),
      ]);
    });
  }

  Widget _tile(String o, bool on) => AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: on ? AppColors.primary.o(.06) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: on ? AppColors.primary : AppColors.border, width: on ? 1.5 : 1),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              HapticFeedback.selectionClick();
              onSelect(o);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
              child: Row(children: [
                if (iconOf != null) ...[
                  Icon(iconOf!(o), size: 16, color: on ? AppColors.primary : AppColors.mutedForeground),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(capitalizeWords(o),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body(
                          size: 14, weight: on ? FontWeight.w700 : FontWeight.w500, color: on ? AppColors.primary : AppColors.foreground)),
                ),
                if (on) const Icon(LucideIcons.circleCheck, size: 16, color: AppColors.primary),
              ]),
            ),
          ),
        ),
      );
}
