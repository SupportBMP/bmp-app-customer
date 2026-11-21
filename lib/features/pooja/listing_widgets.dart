import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/format.dart';
import '../../core/utils/json.dart';
import '../../core/utils/nav.dart';
import '../../core/api/bmp_api.dart';
import '../../core/config.dart';
import '../../core/storage/cookies.dart';
import '../../core/utils/launch.dart';
import '../../core/widgets/toast.dart';
import '../../core/widgets/form_fields.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/site_image.dart';
import '../../core/widgets/native.dart';
import '../../core/widgets/ui.dart';
import '../festival/festival_state.dart';
import '../festival/festival_widgets.dart';
import '../festival/ornaments.dart';

// ---------------------------------------------------------------------------
// PoojaImageBoxComponent.jsx (mobile: no hover actions, image contained)
// ---------------------------------------------------------------------------

class PoojaCard extends StatelessWidget {
  const PoojaCard({super.key, required this.pooja, required this.onTap, this.language, this.location});
  final Json pooja;
  final VoidCallback onTap;

  /// The current route's language/location, used for the share link.
  final String? language;
  final String? location;

  static const _ornaments = ['/icons/Group6903.svg', '/icons/Group6899.svg'];

  @override
  Widget build(BuildContext context) {
    final media = objList(pooja['media']);
    final image = media.isNotEmpty ? strOrNull(media.first['mediaUrl']) : null;
    final price = pooja['price'];
    // Same swirl for a pooja every time (seeded by its slug, as on the web).
    final ornament = _ornaments[swirlHash(str(pooja['slug'], str(pooja['_id']))) % _ornaments.length];
    final ornamentStyle = ornament == _ornaments[0] ? const EdgeInsets.only(top: 0) : const EdgeInsets.only(top: 19, bottom: 65);

    return Semantics(
      link: true,
      label: '${str(pooja['name'])}${truthy(price) ? ', packages from ₹${formatAmountPutComma(price)}' : ''}',
      child: PressScale(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [
                        BoxShadow(color: Color(0x1A000000), blurRadius: 6, offset: Offset(0, 4), spreadRadius: -1),
                        BoxShadow(color: Color(0x1A000000), blurRadius: 4, offset: Offset(0, 2), spreadRadius: -2),
                      ],
                    ),
                    child: Stack(fit: StackFit.expand, children: [
                      SiteImage(image ?? '/images/aigenerated/Deities.jpeg', fit: BoxFit.contain, placeholderColor: Colors.white),
                      Positioned(
                        right: 6,
                        bottom: 6,
                        child: Column(children: [
                          _CardAction(
                            icon: LucideIcons.heart,
                            label: 'Add to wishlist',
                            pop: true,
                            onTap: () => addPoojaToWishlist(pooja),
                          ),
                          const SizedBox(height: 6),
                          _CardAction(icon: LucideIcons.share2, label: 'Share on WhatsApp', onTap: _share),
                        ]),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  str(pooja['name']),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.poppins(size: 16, weight: FontWeight.w600, color: AppColors.bluntRed, height: 1.25),
                ),
                const SizedBox(height: 8),
                Text(
                  truthy(price) ? 'Packages Starting From' : 'Price On Request',
                  style: AppText.poppins(size: 12, weight: FontWeight.w500, color: AppColors.gray600),
                ),
                if (truthy(price))
                  Text(
                    '₹ ${formatAmountPutComma(price)}',
                    style: AppText.poppins(size: 16, weight: FontWeight.w700, color: AppColors.bluntRed),
                  ),
                const SizedBox(height: 12),
              ],
            ),
            Positioned(
              top: -20,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: SizedBox(
                  height: 48,
                  child: OverflowBox(
                    maxHeight: 96,
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: ornamentStyle,
                      child: SiteImage(
                        ornament,
                        width: 96,
                        height: 96 - ornamentStyle.vertical,
                        fit: BoxFit.contain,
                        placeholderColor: Colors.transparent,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Falls back to the current route's language/location (the web card used
  /// to share /undefined/undefined/pooja/…).
  void _share() {
    final lang = strOrNull(pooja['linkLanguage']) ?? language;
    final loc = strOrNull(pooja['linkLocation']) ?? location;
    final slug = str(pooja['slug']);
    final path = lang != null && loc != null && lang.isNotEmpty && loc.isNotEmpty
        ? '/${lang.toLowerCase()}/${loc.toLowerCase()}/pooja/$slug'
        : '/pooja/$slug';
    openExternal(
      'https://wa.me/?text=${Uri.encodeComponent('Hi, I am planning to book this puja ${AppConfig.siteUrl}$path. Please respond to me on whatsapp here')}',
    );
  }
}

/// PoojaRandomDesignImageComponent `hashOf`: `(h * 31 + code) >>> 0`, from 7.
int swirlHash(String seed) {
  var h = 7;
  for (final c in seed.codeUnits) {
    h = (h * 31 + c) & 0xFFFFFFFF;
  }
  return h;
}

Future<void> addPoojaToWishlist(Json pooja) async {
  if (Cookies.get('accessToken') == null) {
    Toast.show('You are not logged in. Please login to add items to wishlist ');
    return;
  }
  try {
    final r = await BmpApi.addToWishlist({'poojaId': pooja['_id']});
    final d = obj(r.data);
    if (r.statusCode == 201 && intOf(d['statusCode']) == 200) {
      Toast.success(str(d['message']));
    } else {
      Toast.show(str(d['error']));
    }
  } catch (_) {
    Toast.error('Error fetching wishlist API');
  }
}

/// Wishlist / share bubble on the card image — always visible (they were
/// hover-only on the web, so phone users never saw them). The heart pops.
class _CardAction extends StatefulWidget {
  const _CardAction({required this.icon, required this.label, required this.onTap, this.pop = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool pop;

  @override
  State<_CardAction> createState() => _CardActionState();
}

class _CardActionState extends State<_CardAction> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: widget.label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (widget.pop && !reduceMotion(context)) _c.forward(from: 0);
            widget.onTap();
          },
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xE6FFFFFF),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Color(0x26000000), blurRadius: 6, offset: Offset(0, 2))],
            ),
            child: ScaleTransition(
              scale: TweenSequence([
                TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35), weight: 40),
                TweenSequenceItem(tween: Tween(begin: 1.35, end: 1.0), weight: 60),
              ]).animate(CurvedAnimation(parent: _c, curve: Curves.easeOut)),
              child: Icon(widget.icon, size: 16, color: AppColors.bluntRed),
            ),
          ),
        ),
      );
}

/// List-view row of [PoojaCard]: thumbnail left, name and price right.
class PoojaListTile extends StatelessWidget {
  const PoojaListTile({super.key, required this.pooja, required this.onTap});
  final Json pooja;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final media = objList(pooja['media']);
    final image = media.isNotEmpty ? strOrNull(media.first['mediaUrl']) : null;
    final price = pooja['price'];
    return PressScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.o(.1)),
          boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 6, offset: Offset(0, 2))],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 96,
                height: 96,
                child: SiteImage(image ?? '/images/aigenerated/Deities.jpeg', fit: BoxFit.contain, placeholderColor: Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    str(pooja['name']),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.poppins(size: 15, weight: FontWeight.w600, color: AppColors.bluntRed, height: 1.25),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    truthy(price) ? 'Packages Starting From' : 'Price On Request',
                    style: AppText.poppins(size: 12, weight: FontWeight.w500, color: AppColors.gray600),
                  ),
                  if (truthy(price))
                    Text(
                      '₹ ${formatAmountPutComma(price)}',
                      style: AppText.poppins(size: 16, weight: FontWeight.w700, color: AppColors.bluntRed),
                    ),
                ],
              ),
            ),
            const Icon(LucideIcons.chevronRight, size: 18, color: AppColors.mutedForeground),
          ],
        ),
      ),
    );
  }
}

/// List-view placeholder matching [PoojaListTile].
class PoojaListShimmer extends StatelessWidget {
  const PoojaListShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    Widget bar(double h, double widthFactor) => FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: Alignment.centerLeft,
      child: Container(
        height: h,
        decoration: BoxDecoration(color: AppColors.gray200, borderRadius: BorderRadius.circular(6)),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gray200),
      ),
      child: Row(
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(color: AppColors.gray200, borderRadius: BorderRadius.circular(8)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [bar(16, .9), const SizedBox(height: 10), bar(12, .5), const SizedBox(height: 8), bar(16, .35)],
            ),
          ),
        ],
      ),
    );
  }
}

/// AnimationComponent/Shimmer.jsx
class PoojaShimmer extends StatefulWidget {
  const PoojaShimmer({super.key});
  @override
  State<PoojaShimmer> createState() => _PoojaShimmerState();
}

class _PoojaShimmerState extends State<PoojaShimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget bar(double h, double widthFactor, double top) => Padding(
      padding: EdgeInsets.only(top: top),
      child: FractionallySizedBox(
        widthFactor: widthFactor,
        alignment: Alignment.centerLeft,
        child: Container(
          height: h,
          decoration: BoxDecoration(color: AppColors.gray200, borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) => Opacity(opacity: .5 + .5 * (1 - (math.sin(_c.value * math.pi * 2) + 1) / 4), child: child),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 400,
            decoration: BoxDecoration(color: AppColors.gray200, borderRadius: BorderRadius.circular(8)),
          ),
          bar(20, 1, 32),
          bar(20, .5, 12),
          bar(20, .25, 20),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// pagination/Pagination.jsx (mobile icon buttons)
// ---------------------------------------------------------------------------

class PaginationBar extends StatelessWidget {
  const PaginationBar({super.key, required this.nPages, required this.currentPage, required this.onPageChange});
  final int nPages;
  final int currentPage;
  final ValueChanged<int> onPageChange;

  List<Object> _pages() {
    const showMax = 5;
    if (nPages <= showMax) return [for (var i = 1; i <= nPages; i++) i];
    final pages = <Object>[1];
    var start = math.max(2, currentPage - 1);
    var end = math.min(nPages - 1, currentPage + 1);
    if (currentPage <= 3) {
      end = 4;
    } else if (currentPage >= nPages - 2) {
      start = nPages - 3;
    }
    if (start > 2) pages.add('e1');
    for (var i = start; i <= end; i++) {
      pages.add(i);
    }
    if (end < nPages - 1) pages.add('e2');
    pages.add(nPages);
    return pages;
  }

  void _go(int p) {
    if (p < 1 || p > nPages || p == currentPage) return;
    onPageChange(p);
  }

  @override
  Widget build(BuildContext context) {
    if (nPages <= 1) return const SizedBox.shrink();
    Widget square({required Widget child, required VoidCallback? onTap, bool active = false}) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: AppButton(
        size: BtnSize.icon,
        height: 36,
        radius: 8,
        variant: active ? BtnVariant.primary : BtnVariant.outline,
        borderColor: active ? null : AppColors.primary.o(.1),
        shadow: active ? const [BoxShadow(color: Color(0x1A000000), blurRadius: 6, offset: Offset(0, 4))] : null,
        onPressed: onTap,
        child: child,
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          square(onTap: currentPage == 1 ? null : () => _go(currentPage - 1), child: const Icon(LucideIcons.chevronLeft, size: 16)),
          const SizedBox(width: 8),
          for (final p in _pages())
            if (p is String)
              const SizedBox(width: 36, height: 36, child: Icon(LucideIcons.ellipsis, size: 16, color: AppColors.mutedForeground))
            else
              Transform.scale(
                scale: p == currentPage ? 1.05 : 1,
                child: square(
                  active: p == currentPage,
                  onTap: () => _go(p as int),
                  child: Text('$p', style: AppText.body(size: 14, weight: FontWeight.w500)),
                ),
              ),
          const SizedBox(width: 8),
          square(onTap: currentPage == nPages ? null : () => _go(currentPage + 1), child: const Icon(LucideIcons.chevronRight, size: 16)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// v2/FilterBar.jsx (mobile) + FilterDrawer + FilterSidebar + ActiveFilters
// ---------------------------------------------------------------------------

const sortOptions = [
  ('popular', 'Popular'),
  ('price-asc', 'Price: Low → High'),
  ('price-desc', 'Price: High → Low'),
  ('name-asc', 'Name: A → Z'),
];

class ListingFilters {
  ListingFilters({
    this.categories = const [],
    this.priceRange = const RangeValues(501, 110000),
    this.durations = const [],
    this.sortBy = 'popular',
    this.search = '',
  });

  List<String> categories;
  RangeValues priceRange;
  List<String> durations;
  String sortBy;
  String search;

  bool get hasPriceFilter => priceRange.start > 3500 || priceRange.end < 21000;

  ListingFilters copy() => ListingFilters(
        categories: [...categories],
        priceRange: priceRange,
        durations: [...durations],
        sortBy: sortBy,
        search: search,
      );
  int get activeCount => categories.length + durations.length + (hasPriceFilter ? 1 : 0);
}

class FilterBar extends StatelessWidget {
  const FilterBar({
    super.key,
    required this.categories,
    required this.filters,
    required this.onCategoryToggle,
    required this.onPriceChange,
    required this.onSortChange,
    required this.onClearAll,
  });

  final List<Json> categories;
  final ListingFilters filters;
  final ValueChanged<String> onCategoryToggle;
  final ValueChanged<RangeValues> onPriceChange;
  final ValueChanged<String> onSortChange;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    final current = sortOptions.firstWhere((s) => s.$1 == filters.sortBy, orElse: () => sortOptions.first);
    final count = filters.activeCount;
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.primary.o(.1))),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            AppButton(
              variant: BtnVariant.outline,
              size: BtnSize.sm,
              borderColor: AppColors.primary.o(.2),
              onPressed: () => _openDrawer(context),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.slidersHorizontal, size: 16),
                  const SizedBox(width: 8),
                  Text('Filters', style: AppText.body(size: 14, weight: FontWeight.w500)),
                  if (count > 0) ...[const SizedBox(width: 8), _countBadge(count)],
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () async {
                final v = await showNativePicker<(String, String)>(
                  context,
                  title: 'Sort by',
                  options: sortOptions,
                  labelOf: (o) => o.$2,
                  selected: current,
                );
                if (v != null) onSortChange(v.$1);
              },
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.primary.o(.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Sort: ${current.$2}', style: AppText.body(size: 14, weight: FontWeight.w500)),
                    const SizedBox(width: 6),
                    Icon(LucideIcons.chevronDown, size: 14, color: AppColors.foreground.o(.6)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _countBadge(int n) => Container(
    width: 20,
    height: 20,
    alignment: Alignment.center,
    decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
    child: Text('$n', style: AppText.body(size: 12, color: Colors.white)),
  );

  void _openDrawer(BuildContext context) {
    showSideSheet(
      context,
      fromLeft: true,
      width: 384,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          Widget om([double size = 16]) => Opacity(
            opacity: .6,
            child: Text(
              'ॐ',
              style: TextStyle(fontFamily: 'serif', fontSize: size, color: AppColors.primary),
            ),
          );
          Widget section(String title, Widget child) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  om(14),
                  const SizedBox(width: 6),
                  Text(title, style: AppText.body(size: 14, weight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),
              child,
            ],
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                child: Text('Filters', style: AppText.body(size: 18, weight: FontWeight.w600)),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          om(),
                          const SizedBox(width: 8),
                          Text('Filters', style: AppText.heading(size: 18, weight: FontWeight.w600)),
                          const Spacer(),
                          GestureDetector(
                            onTap: () {
                              onClearAll();
                              setLocal(() {});
                            },
                            child: Text(
                              'Clear all',
                              style: AppText.body(size: 12, color: AppColors.mutedForeground, decoration: TextDecoration.underline),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      section(
                        'Categories',
                        Column(
                          children: [
                            for (final cat in categories)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    onCategoryToggle(str(cat['slug']));
                                    setLocal(() {});
                                  },
                                  child: Row(
                                    children: [
                                      AppCheckbox(
                                        value: filters.categories.contains(str(cat['slug'])),
                                        onChanged: (_) {
                                          onCategoryToggle(str(cat['slug']));
                                          setLocal(() {});
                                        },
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          str(cat['subCategoryName']),
                                          style: AppText.body(size: 14, color: AppColors.mutedForeground),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      section(
                        'Price Range',
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Column(
                            children: [
                              SliderTheme(
                                data: SliderTheme.of(ctx).copyWith(
                                  activeTrackColor: AppColors.primary,
                                  inactiveTrackColor: AppColors.secondary,
                                  thumbColor: AppColors.background,
                                  overlayColor: AppColors.primary.o(.1),
                                  trackHeight: 8,
                                  rangeThumbShape: const _RingThumb(),
                                ),
                                child: RangeSlider(
                                  min: 3500,
                                  max: 21000,
                                  divisions: 35,
                                  values: RangeValues(
                                    filters.priceRange.start.clamp(3500, 21000),
                                    filters.priceRange.end.clamp(3500, 21000),
                                  ),
                                  onChanged: (v) {
                                    onPriceChange(v);
                                    setLocal(() {});
                                  },
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  _minMax('MIN', filters.priceRange.start, CrossAxisAlignment.start),
                                  const Spacer(),
                                  _minMax('MAX', filters.priceRange.end, CrossAxisAlignment.end),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: AppButton(expand: true, label: 'Show Results', onPressed: () => Navigator.of(ctx).pop()),
              ),
            ],
          );
        },
      ),
    );
  }

  static Widget _minMax(String label, double v, CrossAxisAlignment a) => Column(
    crossAxisAlignment: a,
    children: [
      Opacity(
        opacity: .6,
        child: Text(
          label,
          style: AppText.body(size: 10, weight: FontWeight.w700, color: AppColors.mutedForeground),
        ),
      ),
      Text('₹${formatIndianNumber(v.round())}', style: AppText.body(size: 10, weight: FontWeight.w700)),
    ],
  );
}

/// shadcn Slider thumb: white circle with a 2px primary ring.
class _RingThumb extends RangeSliderThumbShape {
  const _RingThumb();

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(20, 20);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    bool isDiscrete = false,
    bool isEnabled = false,
    bool? isOnTop,
    TextDirection? textDirection,
    required SliderThemeData sliderTheme,
    Thumb? thumb,
    bool? isPressed,
  }) {
    final c = context.canvas;
    c.drawCircle(center, 10, Paint()..color = AppColors.background);
    c.drawCircle(
      center,
      9,
      Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }
}

class ActiveFilters extends StatelessWidget {
  const ActiveFilters({
    super.key,
    required this.filters,
    required this.onClearSearch,
    required this.onRemoveCategory,
    required this.onRemoveDuration,
    required this.onResetPrice,
    required this.onClearAll,
  });

  final ListingFilters filters;
  final VoidCallback onClearSearch;
  final ValueChanged<String> onRemoveCategory;
  final ValueChanged<String> onRemoveDuration;
  final VoidCallback onResetPrice;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    final f = filters;
    final hasAny = f.search.trim().isNotEmpty || f.categories.isNotEmpty || f.durations.isNotEmpty || f.hasPriceFilter;
    if (!hasAny) return const SizedBox.shrink();
    Widget chip(String label, VoidCallback onTap) => GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primary.o(.1),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.primary.o(.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: AppText.body(size: 12, color: AppColors.primary)),
            const SizedBox(width: 4),
            const Icon(LucideIcons.x, size: 12, color: AppColors.primary),
          ],
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (f.search.trim().isNotEmpty) chip('"${f.search}"', onClearSearch),
          for (final c in f.categories) chip(c, () => onRemoveCategory(c)),
          for (final d in f.durations) chip(d, () => onRemoveDuration(d)),
          if (f.hasPriceFilter)
            chip('₹${formatIndianNumber(f.priceRange.start.round())} – ₹${formatIndianNumber(f.priceRange.end.round())}', onResetPrice),
          GestureDetector(
            onTap: onClearAll,
            child: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                'Clear all',
                style: AppText.body(size: 12, color: AppColors.mutedForeground, decoration: TextDecoration.underline),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// festival/FestivalCollection.jsx
// ---------------------------------------------------------------------------

/// Collapsed by default to a ~64px bar (diya, title + option count,
/// "From ₹…" + subtitle, 3 thumbnails, Show/Hide chevron); opening it reveals
/// the cards with a smooth height animation, cards rising in one after
/// another. A light shine sweeps the bar once. The open/closed choice is
/// remembered per campaign. [hidden] tucks it away entirely (search or
/// filters active). On phones "See all" lives inside the opened panel.
class FestivalCollection extends StatefulWidget {
  const FestivalCollection({super.key, required this.experience, required this.slotKey, this.hidden = false});
  final Json? experience;
  final String slotKey;
  final bool hidden;

  @override
  State<FestivalCollection> createState() => _FestivalCollectionState();
}

class _FestivalCollectionState extends State<FestivalCollection> with SingleTickerProviderStateMixin {
  bool _open = false;
  String? _loadedFor;
  late final AnimationController _shine = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  String? get _campaignId => widget.experience == null ? null : strOrNull(pick(widget.experience, ['primaryCampaign', 'id']));

  void _restore() {
    final id = _campaignId;
    if (id == null || id == _loadedFor) return;
    _loadedFor = id;
    _open = Cookies.prefs.getString('fx_rail_open_$id') == '1';
    if (!reduceMotion(context)) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) _shine.forward(from: 0);
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _restore();
  }

  @override
  void didUpdateWidget(covariant FestivalCollection oldWidget) {
    super.didUpdateWidget(oldWidget);
    _restore();
  }

  @override
  void dispose() {
    _shine.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _open = !_open);
    final id = _campaignId;
    if (id != null) Cookies.prefs.setString('fx_rail_open_$id', _open ? '1' : '0');
  }

  @override
  Widget build(BuildContext context) {
    final exp = widget.experience;
    final all = exp == null ? const <Json>[] : objList(exp['poojas']);
    final poojas = all.take(4).toList();
    if (exp == null || poojas.isEmpty || widget.hidden || exp['primaryCampaign'] == null) return const SizedBox.shrink();
    final campaign = exp.fxCampaign;
    final t = exp.fxTheme;
    final activeDay = exp['activeDay'] is Map ? obj(exp['activeDay']) : null;
    final subtitle = activeDay != null
        ? '${str(activeDay['label'])} · ${str(activeDay['name'])}'
        : (strOrNull(pick(exp, ['copy', 'eyebrow'])) ?? str(campaign['name']));
    final prices = all.map((p) => num.tryParse('${p['startingPrice'] ?? ''}') ?? 0).where((n) => n > 0).toList()..sort();
    final fromPrice = prices.isEmpty ? null : prices.first;
    final uniqueCount = all.map((p) => '${str(p['slug'])}|${str(p['linkLocation'])}|${str(p['linkLanguage'])}').toSet().length;
    final thumbs = poojas.where((p) => strOrNull(p['image']) != null).take(3).toList();
    final cardWidth = math.min(MediaQuery.sizeOf(context).width * .62, 240.0);
    final wide = MediaQuery.sizeOf(context).width >= 640;
    final dur = reduceMotion(context) ? Duration.zero : const Duration(milliseconds: 500);

    Widget seeAll() => GestureDetector(
          onTap: () => goHref(context, str(campaign['landingHref'])),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(color: t.accent, borderRadius: BorderRadius.circular(999)),
            child: Text('See all', style: AppText.sans(size: 12, weight: FontWeight.w700, color: t.accentFg)),
          ),
        );

    final cards = <Widget>[
      for (var i = 0; i < poojas.length; i++)
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: SizedBox(
            width: cardWidth,
            child: _open
                ? RiseIn(
                    delay: Duration(milliseconds: 80 * i),
                    child: FestivalPoojaCard(experience: exp, pooja: poojas[i], slotKey: widget.slotKey, compact: true),
                  )
                : FestivalPoojaCard(experience: exp, pooja: poojas[i], slotKey: widget.slotKey, compact: true),
          ),
        ),
      SizedBox(
        width: cardWidth,
        child: RiseIn(
          key: ValueKey('cb$_open'),
          delay: Duration(milliseconds: 80 * poojas.length),
          child: GestureDetector(
            onTap: () => openFestivalCallback(context, exp, slot: '${widget.slotKey}.callback'),
            child: Container(
              constraints: const BoxConstraints(minHeight: 180),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: t.accent.o(.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: t.accent.o(.7)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(LucideIcons.phoneCall, size: 28, color: t.accent),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text("Can't decide?", style: AppText.heading(size: 16, color: t.fg)),
                    const SizedBox(height: 4),
                    Text('A pandit will call you in 10 min and suggest the right puja.', style: AppText.sans(size: 12, color: t.muted)),
                  ]),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: t.accent, borderRadius: BorderRadius.circular(999)),
                    child: Text('Get a call back', style: AppText.sans(size: 12, weight: FontWeight.w700, color: t.accentFg)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ];

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [t.bg, const Color(0xFF5C1820)]),
      ),
      child: Stack(children: [
        Positioned(
          right: -80,
          top: -96,
          child: Container(
            width: 256,
            height: 256,
            decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [t.bg2.o(.6), t.bg2.o(0)])),
          ),
        ),
        // One-off shine sweep across the bar.
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _shine,
              builder: (_, _) {
                if (!_shine.isAnimating) return const SizedBox.shrink();
                final v = Curves.easeOut.transform(_shine.value);
                return FractionallySizedBox(
                  alignment: Alignment(-1.6 + 3.2 * v, 0),
                  widthFactor: .33,
                  child: Transform(
                    transform: Matrix4.skewX(-.2),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [Colors.white.o(0), Colors.white.o(.15), Colors.white.o(0)]),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: Row(children: [
              Expanded(
                child: Semantics(
                  button: true,
                  expanded: _open,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _toggle,
                    child: Row(children: [
                      const DiyaIcon(size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text.rich(
                            TextSpan(children: [
                              TextSpan(text: festivalPoojaHeading(exp)),
                              TextSpan(
                                text: '  · $uniqueCount options',
                                style: AppText.sans(size: 12, weight: FontWeight.w600, color: t.muted),
                              ),
                            ]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.heading(size: 16, weight: FontWeight.w700, color: t.fg),
                          ),
                          Text(
                            [if (fromPrice != null) 'From ₹${formatIndianNumber(fromPrice.round())}', subtitle].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.sans(size: 12, color: t.muted),
                          ),
                        ]),
                      ),
                      if (thumbs.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 28.0 + 18 * (thumbs.length - 1),
                          height: 28,
                          child: Stack(children: [
                            for (var i = 0; i < thumbs.length; i++)
                              Positioned(
                                left: 18.0 * i,
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  clipBehavior: Clip.antiAlias,
                                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: t.bg, width: 2)),
                                  child: SiteImage(str(thumbs[i]['image']), fit: BoxFit.cover),
                                ),
                              ),
                          ]),
                        ),
                      ],
                      const SizedBox(width: 6),
                      if (wide) Text(_open ? 'Hide' : 'Show', style: AppText.sans(size: 12, weight: FontWeight.w600, color: t.fg)),
                      AnimatedRotation(
                        turns: _open ? .5 : 0,
                        duration: const Duration(milliseconds: 300),
                        child: Icon(LucideIcons.chevronDown, size: 18, color: t.fg),
                      ),
                    ]),
                  ),
                ),
              ),
              if (wide) ...[const SizedBox(width: 10), seeAll()],
            ]),
          ),
          AnimatedSize(
            duration: dur,
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: !_open
                ? const SizedBox(width: double.infinity)
                : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    SizedBox(
                      height: 260,
                      child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: cards),
                    ),
                    if (!wide)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Align(alignment: Alignment.centerLeft, child: seeAll()),
                      ),
                    const SizedBox(height: 16),
                  ]),
          ),
        ]),
      ]),
    );
  }
}

/// Keeps festival_state's [buildPoojaHref] reachable from listing callers.
String festivalHref(Json p, String lang, String loc) => buildPoojaHref(p, lang, loc);
