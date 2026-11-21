import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api/api_client.dart';
import '../../core/config.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/format.dart';
import '../../core/utils/json.dart';
import '../../core/widgets/site/site_page.dart';
import '../../core/widgets/toast.dart';
import '../../core/widgets/ui.dart';
import '../festival/festival_state.dart';
import '../festival/festival_widgets.dart';
import '../../core/utils/launch.dart';
import '../../core/widgets/motion.dart';
import 'listing_decor.dart';
import 'listing_widgets.dart';

/// pages/[language]/[location]/pooja/index.jsx, and with [categorySlug]
/// pages/[language]/[location]/category/[slug].jsx (same page, category fixed).
class PoojaListingPage extends ConsumerStatefulWidget {
  const PoojaListingPage({super.key, required this.language, required this.location, this.categorySlug});
  final String language;
  final String location;
  final String? categorySlug;

  @override
  ConsumerState<PoojaListingPage> createState() => _PoojaListingPageState();
}

class _PoojaListingPageState extends ConsumerState<PoojaListingPage> {
  static const _recordsPerPage = 12;
  final _filters = ListingFilters();

  /// What the API query is built from: chips and the slider update [_filters]
  /// (and the screen) at once; this copy follows 350 ms after the last change.
  ListingFilters _committed = ListingFilters();
  Timer? _commitTimer;
  static const _filterDebounce = Duration(milliseconds: 350);

  /// Bumped when a new result set lands, so the grid entrance replays.
  int _generation = 0;
  final _scroll = ScrollController();
  List<Json> _items = [];
  bool _loading = true;
  bool _loadingMore = false;
  int _currentPage = 1;
  int _totalItems = 0;
  String? _lastQuery;
  bool _isSearch = false;
  bool _listView = fxSessionFlags.contains(poojaListViewSessionKey);
  Timer? _debounce;
  String _debouncedSearch = '';

  bool get _hasMore => !_isSearch && _items.length < _totalItems;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _commitTimer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.hasClients && _scroll.position.extentAfter < 900) _loadMore();
  }

  void _setListView(bool list) {
    if (list == _listView) return;
    list ? fxSessionFlags.add(poojaListViewSessionKey) : fxSessionFlags.remove(poojaListViewSessionKey);
    setState(() => _listView = list);
  }

  /// The query without its page, so a filter change can be told from paging.
  String _buildQuery(String languageId, String locationId) {
    final search = _debouncedSearch.trim();
    if (search.isNotEmpty) {
      return '/pooja/find?t=${Uri.encodeComponent(search)}&language=$languageId&location=$locationId&p=false';
    }
    final q = <String>[
      'pageSize=$_recordsPerPage',
      'sort=${_committed.sortBy.replaceFirst('-', '_')}',
      'projection=PLP',
      'minPrice=${_committed.priceRange.start.round()}',
      'maxPrice=${_committed.priceRange.end.round()}',
      if (widget.categorySlug != null) 'category=${Uri.encodeQueryComponent(widget.categorySlug!)}',
      for (final c in _committed.categories)
        if (c != widget.categorySlug) 'category=${Uri.encodeQueryComponent(c)}',
      'language=$languageId',
      'location=$locationId',
    ];
    return '/pooja?${q.join('&')}';
  }

  Future<void> _fetch(String? languageId, String? locationId) async {
    if (languageId == null || locationId == null) {
      if (_lastQuery == '' && !_loading) return;
      _lastQuery = '';
      setState(() {
        _loading = false;
        _items = [];
        _totalItems = 0;
      });
      return;
    }
    final query = _buildQuery(languageId, locationId);
    if (query == _lastQuery) return;
    _lastQuery = query;
    _isSearch = _debouncedSearch.trim().isNotEmpty;
    _currentPage = 1;
    setState(() {
      _loading = true;
      _loadingMore = false;
    });
    final page = await _request(query, 1);
    if (!mounted || query != _lastQuery) return;
    if (page == null) _lastQuery = null;
    setState(() {
      _items = page?.items ?? [];
      _totalItems = page?.total ?? 0;
      _loading = false;
      _generation++;
    });
    if (page != null) _checkFill();
  }

  /// Keeps paging while the loaded results don't fill the screen yet.
  void _checkFill() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onScroll();
      });

  /// Infinite scroll: fetches the next page when the list nears its end.
  Future<void> _loadMore() async {
    final query = _lastQuery;
    if (_loading || _loadingMore || !_hasMore || query == null || query.isEmpty) return;
    setState(() => _loadingMore = true);
    final next = _currentPage + 1;
    final page = await _request(query, next);
    if (!mounted || query != _lastQuery) return;
    setState(() {
      _loadingMore = false;
      if (page == null) return;
      _currentPage = next;
      _items = [..._items, ...page.items];
      // Stop paging if the server runs dry before totalCount says so.
      if (page.items.isEmpty) _totalItems = _items.length;
    });
    // A failed page waits for the next scroll instead of retrying at once.
    if (page != null) _checkFill();
  }

  /// Returns the page's items and the total count, or null on a network error.
  Future<({List<Json> items, int total})?> _request(String query, int page) async {
    final url = AppConfig.api(_isSearch ? query : '$query&page=${page - 1}');
    try {
      final res = await ApiClient.instance.get(url);
      final d = obj(res.data);
      if (intOf(d['statusCode']) == 200) {
        final items = objList(d['body']);
        return (items: items, total: _isSearch ? items.length : intOf(d['totalCount']));
      }
      if (page == 1) Toast.error('No Matching Pooja Found!');
      return (items: const <Json>[], total: 0);
    } catch (_) {
      Toast.error('Error fetching pooja items. Please try again.');
      return null;
    }
  }

  /// Updates the screen now; the fetch waits [_filterDebounce] after the
  /// last change (two quick chip taps or a slider drag = one request).
  /// [instant] skips the wait (Clear all).
  void _changed({bool instant = false}) {
    _commitTimer?.cancel();
    if (instant) {
      _committed = _filters.copy();
      setState(() {});
      return;
    }
    setState(() {});
    _commitTimer = Timer(_filterDebounce, () {
      if (mounted) setState(() => _committed = _filters.copy());
    });
  }

  void _toggleCategory(String c) {
    _filters.categories =
        _filters.categories.contains(c) ? (_filters.categories.toList()..remove(c)) : [..._filters.categories, c];
    _changed();
  }

  void _clearAll() {
    _filters
      ..categories = []
      ..durations = []
      ..priceRange = const RangeValues(3500, 21000)
      ..search = ''
      ..sortBy = 'popular';
    _debouncedSearch = '';
    _changed(instant: true);
  }

  void _open(Json p) =>
      context.push('/${widget.language.toLowerCase()}/${widget.location.toLowerCase()}/pooja/${str(p['slug'])}');

  /// Trust band goes after the first 8 cards when there are more than 10.
  static const _trustAfter = 8;
  bool get _showTrustBand => _totalItems > 10 && _items.length > _trustAfter;
  int get _rows => (_items.length / 2).ceil();

  Widget _trustBand() => Padding(
        padding: const EdgeInsets.only(bottom: 32),
        child: Reveal(
          child: TrustBand(
            language: widget.language,
            location: widget.location,
            pageReference: pageReference('/${widget.language.toLowerCase()}/${widget.location.toLowerCase()}/pooja'),
          ),
        ),
      );

  /// First 8 cards fade and rise in a quick stagger (45 ms apart); later ones
  /// rise as they scroll into view. Replays for every new result set.
  Widget _entrance(int index, Widget child) => index < 8
      ? RiseIn(key: ValueKey('g$_generation-$index'), delay: Duration(milliseconds: 45 * index), child: child)
      : Reveal(key: ValueKey('g$_generation-$index'), child: child);

  @override
  Widget build(BuildContext context) {
    final locations = ref.watch(locationsProvider);
    final languages = ref.watch(languagesProvider);
    final categories = objList((ref.watch(v2GlobalDataProvider).value ?? const {})['generalCategories']);
    final listsReady = locations.hasValue && languages.hasValue;
    final ids = findLocLangIds(locations.value ?? const [], languages.value ?? const [], widget.location, widget.language);
    if (listsReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fetch(ids.languageId, ids.locationId);
      });
    }
    final isCategory = widget.categorySlug != null;
    final pageType = isCategory ? 'category' : 'listing';
    final exp = useFestival(ref, pageType, location: widget.location, language: widget.language);

    final crumbs = [
      widget.location.replaceAll('-', ' '),
      widget.language.replaceAll('-', ' '),
      if (isCategory) widget.categorySlug!.replaceAll('-', ' '),
      'Pooja Services',
    ].join(' / ');

    const pad = EdgeInsets.symmetric(horizontal: 32);
    return SitePage(
      pageType: pageType,
      city: widget.location,
      language: widget.language,
      scrollController: _scroll,
      bottomBar: const StickyMobileContact(),
      slivers: [
        SliverToBoxAdapter(
          child: ListingHeaderBand(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Padding(
                padding: pad.copyWith(top: 16, bottom: 8),
                child: Text(crumbs.toUpperCase(), style: AppText.body(size: 12, color: AppColors.mutedForeground, letterSpacing: .3)),
              ),
              Padding(
                padding: pad.copyWith(bottom: 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Semantics(
                    header: true,
                    child: Text(
                      cssCapitalize(
                        '${isCategory ? widget.categorySlug!.replaceAll('-', ' ') : widget.language.replaceAll('-', ' ')} Pooja Services in ${widget.location.replaceAll('-', ' ')}',
                      ),
                      style: AppText.heading(size: 20),
                    ),
                  ),
                  const SizedBox(height: 2),
                  CountUpText(
                    value: _totalItems,
                    builder: (n) => 'Showing $n sacred rituals available',
                    style: AppText.body(size: 14, color: AppColors.mutedForeground),
                  ),
                ]),
              ),
              if (!isCategory)
                CategoryChips(categories: categories, selected: _filters.categories, onToggle: _toggleCategory),
            ]),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: pad,
            child: FilterBar(
              categories: categories,
              filters: _filters,
              onCategoryToggle: _toggleCategory,
              onPriceChange: (v) {
                _filters.priceRange = v;
                _changed();
              },
              onSortChange: (v) {
                if (_filters.sortBy == v) return;
                _filters.sortBy = v;
                _changed();
              },
              onClearAll: _clearAll,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: pad,
            child: ActiveFilters(
              filters: _filters,
              onClearSearch: () {
                _filters.search = '';
                _debouncedSearch = '';
                _changed();
              },
              onRemoveCategory: (c) {
                _filters.categories = _filters.categories.toList()..remove(c);
                _changed();
              },
              onRemoveDuration: (d) {
                _filters.durations = _filters.durations.toList()..remove(d);
                _changed();
              },
              onResetPrice: () {
                _filters.priceRange = const RangeValues(3500, 21000);
                _changed(instant: true);
              },
              onClearAll: _clearAll,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: pad.copyWith(top: 8),
            child: FestivalCollection(
              experience: exp,
              slotKey: isCategory ? 'category.context' : 'listing.collection',
              hidden: _filters.search.trim().isNotEmpty || _filters.categories.isNotEmpty || _filters.durations.isNotEmpty,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: pad.copyWith(top: 16),
            child: _ViewToggle(listView: _listView, onChanged: _setListView),
          ),
        ),
        SliverPadding(
          padding: pad.copyWith(top: _listView ? 16 : 16 + 20, bottom: 16),
          sliver: _loading
              ? SliverToBoxAdapter(
                  child: Column(children: [
                    for (var i = 0; i < 6; i++)
                      _listView
                          ? const Padding(padding: EdgeInsets.only(bottom: 12), child: PoojaListShimmer())
                          : const Padding(
                              padding: EdgeInsets.only(bottom: 12),
                              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Expanded(child: PoojaShimmer()),
                                SizedBox(width: 12),
                                Expanded(child: PoojaShimmer()),
                              ]),
                            ),
                  ]),
                )
              : _items.isEmpty
                  ? SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Text('No pooja items found for the selected criteria',
                            textAlign: TextAlign.center, style: AppText.body()),
                      ),
                    )
                  : _listView
                      ? SliverList.builder(
                          itemCount: _items.length + (_showTrustBand ? 1 : 0),
                          itemBuilder: (_, i) {
                            if (_showTrustBand && i == _trustAfter) return _trustBand();
                            final k = _showTrustBand && i > _trustAfter ? i - 1 : i;
                            return _entrance(
                              k,
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: PoojaListTile(pooja: _items[k], onTap: () => _open(_items[k])),
                              ),
                            );
                          },
                        )
                      : SliverList.builder(
                          itemCount: _rows + (_showTrustBand ? 1 : 0),
                          itemBuilder: (_, row) {
                            const bandRow = _trustAfter ~/ 2;
                            if (_showTrustBand && row == bandRow) return _trustBand();
                            final r = _showTrustBand && row > bandRow ? row - 1 : row;
                            return _PoojaGridRow(
                              items: _items,
                              row: r,
                              onTap: _open,
                              language: widget.language,
                              location: widget.location,
                              wrap: _entrance,
                            );
                          },
                        ),
        ),
        if (!_loading && _hasMore)
          const SliverToBoxAdapter(
            child: Padding(padding: EdgeInsets.only(top: 8, bottom: 24), child: AppSpinner(size: 40)),
          ),
      ],
    );
  }
}

/// One row of `grid grid-cols-2 gap-3` with natural row heights.
class _PoojaGridRow extends StatelessWidget {
  const _PoojaGridRow({
    required this.items,
    required this.row,
    required this.onTap,
    required this.language,
    required this.location,
    required this.wrap,
  });
  final List<Json> items;
  final int row;
  final ValueChanged<Json> onTap;
  final String language;
  final String location;
  final Widget Function(int index, Widget child) wrap;

  @override
  Widget build(BuildContext context) {
    final i = row * 2;
    Widget card(int k) => wrap(k, PoojaCard(pooja: items[k], onTap: () => onTap(items[k]), language: language, location: location));
    return Padding(
      padding: const EdgeInsets.only(bottom: 12 + 20),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: card(i)),
        const SizedBox(width: 12),
        Expanded(child: i + 1 < items.length ? card(i + 1) : const SizedBox()),
      ]),
    );
  }
}

/// Grid / list switch above the results.
class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.listView, required this.onChanged});
  final bool listView;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget option(IconData icon, String label, bool selected, bool value) => GestureDetector(
          onTap: () => onChanged(value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 16, color: selected ? Colors.white : AppColors.mutedForeground),
              const SizedBox(width: 6),
              Text(label,
                  style: AppText.body(size: 13, weight: FontWeight.w500, color: selected ? Colors.white : AppColors.mutedForeground)),
            ]),
          ),
        );
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.primary.o(.2)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          option(LucideIcons.layoutGrid, 'Grid', !listView, false),
          option(LucideIcons.list, 'List', listView, true),
        ]),
      ),
    );
  }
}
