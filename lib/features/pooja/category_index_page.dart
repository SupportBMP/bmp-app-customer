import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api/api_client.dart';
import '../../core/config.dart';
import '../../core/state/app_state.dart';
import '../../core/storage/cookies.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/json.dart';
import '../../core/widgets/native.dart';
import '../../core/widgets/site/site_page.dart';
import '../../core/widgets/site_image.dart';
import '../../core/widgets/toast.dart';
import 'listing_widgets.dart';

/// pages/[language]/[location]/category/index.jsx
class CategoryIndexPage extends ConsumerStatefulWidget {
  const CategoryIndexPage({super.key, required this.language, required this.location});
  final String language;
  final String location;

  @override
  ConsumerState<CategoryIndexPage> createState() => _CategoryIndexPageState();
}

class _CategoryIndexPageState extends ConsumerState<CategoryIndexPage> {
  static const _recordsPerPage = 8;
  List<Json> _items = [];
  int _currentPage = 1;
  String? _languageId = Cookies.get('language');
  String? _locationId = Cookies.get('location');
  String? _selectedLanguage = Cookies.get('language_name');
  String? _selectedLocation = Cookies.get('location_name');
  String? _fetchedKey;

  Future<void> _fetch(List<Json> locations, List<Json> languages) async {
    final ids = findLocLangIds(locations, languages, Cookies.get('location_name') ?? defaultLocationName, Cookies.get('language_name'));
    final location = _locationId ?? ids.locationId ?? Cookies.get('location');
    final language = _languageId ?? ids.languageId ?? Cookies.get('language');
    final key = '$location|$language';
    if (key == _fetchedKey) return;
    _fetchedKey = key;
    try {
      final url = AppConfig.api(
        '/categories/subcategories?language=${widget.language}&location=${widget.location}'
        '&location=$location&language=$language&categorynin=65ad2804f3a62e0d9d50a0c2&status=active',
      );
      final res = await ApiClient.instance.get(url);
      final d = obj(res.data);
      if (intOf(d['statusCode']) == 200) {
        setState(() => _items = objList(d['body']));
      } else {
        Toast.error('No Matching Category Found--from/category');
      }
    } catch (_) {
      Toast.error('Error fetching category items:');
    }
  }

  @override
  Widget build(BuildContext context) {
    final locations = ref.watch(locationsProvider).value ?? const <Json>[];
    final languages = ref.watch(languagesProvider).value ?? const <Json>[];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fetch(locations, languages);
    });
    final visible = filterVisibleLocations(locations);
    final start = (_currentPage - 1) * _recordsPerPage;
    final current = _items.skip(start).take(_recordsPerPage).toList();
    final nPages = (_items.length / _recordsPerPage).ceil();

    return SitePage(
      pageType: 'category',
      city: widget.location,
      language: widget.language,
      children: [
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _FilterDropdown(
                heading: 'Languages',
                selected: _selectedLanguage,
                options: languages.map((l) => (str(l['_id']), str(l['languageName']))).toList(),
                onSelect: (o) => setState(() {
                  _selectedLanguage = o.$2;
                  _languageId = o.$1;
                }),
              ),
              const SizedBox(width: 16),
              _FilterDropdown(
                heading: 'Locations',
                selected: _selectedLocation,
                options: visible.map((l) => (str(l['_id']), str(l['locationName']))).toList(),
                onSelect: (o) => setState(() {
                  _selectedLocation = o.$2;
                  _locationId = o.$1;
                }),
              ),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: LayoutBuilder(builder: (context, c) {
            final w = (c.maxWidth - 12) / 2;
            return Wrap(
              spacing: 12,
              runSpacing: 24,
              children: [
                for (final cat in current)
                  SizedBox(
                    width: w,
                    child: _CategoryCard(
                      category: cat,
                      onTap: () => context.push(
                        '/${Cookies.get('language_name')}/${Cookies.get('location_name')}/category/${str(cat['slug'])}',
                      ),
                    ),
                  ),
              ],
            );
          }),
        ),
        PaginationBar(nPages: nPages, currentPage: _currentPage, onPageChange: (p) => setState(() => _currentPage = p)),
      ],
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({required this.heading, required this.selected, required this.options, required this.onSelect});
  final String heading;
  final String? selected;
  final List<(String, String)> options;
  final ValueChanged<(String, String)> onSelect;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final v = await showNativePicker<(String, String)>(
          context,
          title: heading,
          options: options,
          labelOf: (o) => o.$2,
          selected: options.where((o) => o.$2 == selected).firstOrNull,
        );
        if (v != null) onSelect(v);
      },
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.gray300),
          boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 2, offset: Offset(0, 1))],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(selected ?? heading, style: AppText.poppins(size: 14, weight: FontWeight.w600, color: AppColors.gray600)),
          const SizedBox(width: 6),
          const Icon(LucideIcons.chevronDown, size: 20, color: AppColors.gray400),
        ]),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category, required this.onTap});
  final Json category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final image = strOrNull(category['imageLink']);
    return Stack(clipBehavior: Clip.none, children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (image != null)
          GestureDetector(
            onTap: onTap,
            child: AspectRatio(
              aspectRatio: 37 / 53,
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 6, offset: Offset(0, 4), spreadRadius: -1)],
                ),
                child: SiteImage(image),
              ),
            ),
          )
        else
          Container(
            width: 64,
            height: 64,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(color: const Color(0xFF4ADE80), borderRadius: BorderRadius.circular(8)),
            child: const SiteImage('/images/aigenerated/Deities.jpeg'),
          ),
        const SizedBox(height: 8),
        Text(
          str(category['subCategoryName']),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: AppText.poppins(size: 14, color: AppColors.defaultText, height: 18 / 14),
        ),
        const SizedBox(height: 20),
      ]),
      Positioned(
        top: -20,
        left: 0,
        right: 0,
        child: IgnorePointer(
          child: Center(
            child: SiteImage(
              (str(category['_id']).hashCode).isEven ? '/icons/Group6903.svg' : '/icons/Group6899.svg',
              width: 96,
              height: 48,
              fit: BoxFit.contain,
              placeholderColor: Colors.transparent,
            ),
          ),
        ),
      ),
    ]);
  }
}
