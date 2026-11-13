import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../api/bmp_api.dart';
import '../../state/app_state.dart';
import '../../storage/cookies.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../utils/json.dart';
import '../../utils/launch.dart';
import '../brand_icons.dart';
import '../site_image.dart';
import 'preferences_sheet.dart';
import '../ui.dart';

const _recentKey = 'recent_pooja_searches';
const _suggestions = ['Satyanarayan', 'Griha Pravesh', 'Rudrabhishek', 'Navagraha', 'Ganesh', 'Lakshmi'];

/// Opens the full-screen pooja search for [city]/[language] (the native
/// replacement for UpperSection's inline dropdown).
Future<void> openPoojaSearch(BuildContext context, {required String city, required String language}) {
  HapticFeedback.selectionClick();
  return Navigator.of(context).push(PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 220),
    reverseTransitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (_, _, _) => _SearchScreen(city: city, language: language, pageContext: context),
    transitionsBuilder: (_, a, _, child) => FadeTransition(
      opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
      child: SlideTransition(
        position: Tween(begin: const Offset(0, .03), end: Offset.zero).animate(CurvedAnimation(parent: a, curve: Curves.easeOut)),
        child: child,
      ),
    ),
  ));
}

class _SearchScreen extends ConsumerStatefulWidget {
  const _SearchScreen({required this.city, required this.language, required this.pageContext});
  final String city;
  final String language;
  final BuildContext pageContext;

  @override
  ConsumerState<_SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<_SearchScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  List<Json> _results = [];
  bool _searching = false;
  String _searched = '';
  List<String> _recent = Cookies.prefs.getStringList(_recentKey) ?? [];

  @override
  void initState() {
    super.initState();
    _search.addListener(_onChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onChanged() {
    setState(() {});
    _debounce?.cancel();
    final q = _search.text.trim();
    if (q.length < 3) {
      setState(() {
        _results = [];
        _searching = false;
        _searched = '';
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 400), () => _perform(q));
  }

  Future<void> _perform(String q) async {
    final ids = findLocLangIds(
      ref.read(locationsProvider).value ?? const [],
      ref.read(languagesProvider).value ?? const [],
      widget.city,
      widget.language,
    );
    List<Json> results;
    try {
      final res = await BmpApi.searchPooja(q, ids.locationId, ids.languageId);
      final d = obj(res.data);
      results = str(d['status']) == 'True' ? objList(d['body']) : [];
    } catch (_) {
      results = [];
    }
    if (!mounted || _search.text.trim() != q) return;
    setState(() {
      _results = results;
      _searching = false;
      _searched = q;
    });
  }

  void _remember(String q) {
    final list = [q, ..._recent.where((r) => r.toLowerCase() != q.toLowerCase())].take(6).toList();
    Cookies.prefs.setStringList(_recentKey, list);
    _recent = list;
  }

  void _setQuery(String q) {
    _search.text = q;
    _search.selection = TextSelection.collapsed(offset: q.length);
  }

  void _open(String path) {
    if (_search.text.trim().length >= 3) _remember(_search.text.trim());
    Navigator.of(context).pop();
    if (widget.pageContext.mounted) widget.pageContext.push(path);
  }

  String get _base => '/${widget.language.toLowerCase()}/${widget.city.toLowerCase()}';

  @override
  Widget build(BuildContext context) {
    final q = _search.text.trim();
    final categories = objList((ref.watch(v2GlobalDataProvider).value ?? const {})['generalCategories']);

    Widget body;
    if (q.length < 3) {
      body = ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
        if (_recent.isNotEmpty) ...[
          _Heading('Recent searches', action: 'Clear', onAction: () {
            Cookies.prefs.remove(_recentKey);
            setState(() => _recent = []);
          }),
          for (final r in _recent)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(LucideIcons.history, size: 18, color: AppColors.mutedForeground),
              title: Text(r, style: AppText.body(size: 15)),
              trailing: const Icon(LucideIcons.arrowUpLeft, size: 16, color: AppColors.mutedForeground),
              onTap: () => _setQuery(r),
            ),
          const SizedBox(height: 16),
        ],
        const _Heading('Popular searches'),
        const SizedBox(height: 4),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final s in _suggestions)
            ActionChip(
              avatar: const Icon(LucideIcons.trendingUp, size: 14, color: AppColors.primary),
              label: Text(s),
              labelStyle: AppText.body(size: 13, weight: FontWeight.w500),
              backgroundColor: Colors.white,
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              onPressed: () => _setQuery(s),
            ),
        ]),
        if (categories.isNotEmpty) ...[
          const SizedBox(height: 24),
          const _Heading('Browse by category'),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: .85,
            children: [
              for (final c in categories.take(9))
                _CategoryTile(cat: c, onTap: () => _open('$_base/category/${str(c['slug'])}')),
            ],
          ),
        ],
      ]);
    } else if (_searching && _results.isEmpty) {
      body = const AppSpinner();
    } else if (_results.isEmpty && _searched.isNotEmpty) {
      body = _NoResults(query: q);
    } else {
      body = ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _results.length,
        separatorBuilder: (_, _) => const Divider(height: 1, indent: 84),
        itemBuilder: (_, i) {
          final r = _results[i];
          final media = strOrNull(pick(r, ['media', 0, 'mediaUrl']));
          return InkWell(
            onTap: () => _open('$_base/pooja/${str(r['slug'])}'),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(children: [
                Container(
                  width: 56,
                  height: 56,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(color: AppColors.primary.o(.05), borderRadius: BorderRadius.circular(12)),
                  child: media != null ? SiteImage(media) : Icon(LucideIcons.flame, size: 20, color: AppColors.primary.o(.5)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(str(r['name']), maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.body(size: 15, weight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('${capitalizeWords(widget.language)} · ${capitalizeWords(widget.city)}',
                        style: AppText.body(size: 12, color: AppColors.mutedForeground)),
                  ]),
                ),
                const Icon(LucideIcons.chevronRight, size: 18, color: AppColors.mutedForeground),
              ]),
            ),
          );
        },
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, size: 22),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Container(
          height: 44,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(color: AppColors.muted, borderRadius: BorderRadius.circular(999)),
          child: Row(children: [
            const SizedBox(width: 14),
            const Icon(LucideIcons.search, size: 18, color: AppColors.mutedForeground),
            Expanded(
              child: TextField(
                controller: _search,
                autofocus: true,
                textInputAction: TextInputAction.search,
                style: AppText.body(size: 15),
                cursorColor: AppColors.primary,
                onSubmitted: (v) {
                  if (v.trim().length >= 3) setState(() => _remember(v.trim()));
                },
                decoration: InputDecoration(
                  hintText: 'Search pujas, e.g. Griha Pravesh',
                  filled: false,
                  isDense: true,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  hintStyle: AppText.body(size: 15, color: AppColors.mutedForeground),
                ),
              ),
            ),
            if (_search.text.isNotEmpty)
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(LucideIcons.x, size: 18, color: AppColors.mutedForeground),
                onPressed: _search.clear,
              ),
          ]),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(36),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(children: [
              const Icon(LucideIcons.mapPin, size: 14, color: AppColors.primary),
              const SizedBox(width: 6),
              Text('Searching in ', style: AppText.body(size: 13, color: AppColors.mutedForeground)),
              Text('${capitalizeWords(widget.city)} · ${capitalizeWords(widget.language)}',
                  style: AppText.body(size: 13, weight: FontWeight.w700, color: AppColors.primary)),
            ]),
          ),
        ),
      ),
      body: body,
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text, {this.action, this.onAction});
  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 36,
        child: Row(children: [
          Expanded(child: Text(text, style: AppText.body(size: 14, weight: FontWeight.w700))),
          if (action != null)
            TextButton(
              onPressed: onAction,
              child: Text(action!, style: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.primary)),
            ),
        ]),
      );
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.cat, required this.onTap});
  final Json cat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SiteImage(strOrNull(cat['imageLink'])),
            ),
          ),
          const SizedBox(height: 6),
          Text(str(cat['subCategoryName']),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppText.body(size: 12, weight: FontWeight.w600)),
        ]),
      );
}

class _NoResults extends StatelessWidget {
  const _NoResults({required this.query});
  final String query;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(32, 48, 32, 24),
        child: Column(children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: AppColors.primary.o(.06), shape: BoxShape.circle),
            child: const Icon(LucideIcons.searchX, size: 30, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text('No pujas match “$query”', textAlign: TextAlign.center, style: AppText.body(size: 17, weight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('Try a different spelling, or tell our Puja advisor what you need and we’ll arrange it.',
              textAlign: TextAlign.center, style: AppText.body(size: 14, color: AppColors.mutedForeground)),
          const SizedBox(height: 20),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.whatsapp,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: () => openWhatsApp('Hi! I was looking for "$query" on the app. Can you help me book it?'),
            icon: const WhatsAppIcon(size: 16, color: Colors.white),
            label: Text('Ask on WhatsApp', style: AppText.body(size: 14, weight: FontWeight.w700, color: Colors.white)),
          ),
        ]),
      );
}
