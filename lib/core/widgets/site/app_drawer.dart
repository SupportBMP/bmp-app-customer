import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../features/festival/festival_widgets.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../utils/json.dart';
import '../../utils/launch.dart';
import '../../utils/nav.dart';
import '../brand_icons.dart';
import '../native.dart';
import '../site_image.dart';
import 'preferences_sheet.dart';

/// Homepage sections the drawer's "Explore" group jumps to (navbar.menuItems).
const _exploreLinks = [
  (LucideIcons.zap, 'Insta Book', 'self-booking'),
  (LucideIcons.layoutGrid, 'Categories', 'categories'),
  (LucideIcons.star, 'Reviews', 'testimonials'),
  (LucideIcons.circleHelp, 'FAQ', 'faq'),
];

const _accountLinks = [
  (LucideIcons.user, 'My Profile', '/user/profile'),
  (LucideIcons.shoppingBag, 'My Orders', '/user/orders'),
  (LucideIcons.shoppingCart, 'My Cart', '/user/cart'),
  (LucideIcons.heart, 'Wishlist', '/user/Wishlist'),
  (LucideIcons.mapPin, 'Saved Addresses', '/user/address'),
];

const _infoLinks = [
  (LucideIcons.info, 'About Us', '/about-us'),
  (LucideIcons.bookOpen, 'Blogs', '/vidya'),
  (LucideIcons.mail, 'Contact Us', '/contact-us'),
  (LucideIcons.shieldCheck, 'Privacy Policy', '/privacy-policy'),
  (LucideIcons.fileText, 'Terms & Conditions', '/terms-and-conditions'),
];

String displayName(Json? user) =>
    strOrNull(user?['userName']) ?? strOrNull(user?['name']) ?? 'Welcome';

String _cap(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

/// Opens the app's navigation drawer: a Material drawer sliding in from the
/// start (or [fromEnd]) edge on Android, a full-height grouped sheet on iOS.
/// City / language / category choices go to the callbacks when given (the
/// listing page filters in place), otherwise to the matching listing route.
Future<void> openAppDrawer(
  BuildContext context, {
  bool fromEnd = false,
  String? city,
  String? language,
  ValueChanged<String>? onCity,
  ValueChanged<String>? onLanguage,
  ValueChanged<String>? onCategory,
}) {
  Widget content(BuildContext sheetContext) => _DrawerContent(
        pageContext: context,
        sheetContext: sheetContext,
        city: city,
        language: language,
        onCity: onCity,
        onLanguage: onLanguage,
        onCategory: onCategory,
      );

  if (useCupertino(context)) {
    return showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => Container(
        height: MediaQuery.sizeOf(ctx).height * .92,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: CupertinoColors.systemGroupedBackground.resolveFrom(ctx),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        ),
        child: content(ctx),
      ),
    );
  }

  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 250),
    transitionBuilder: (ctx, a, _, child) => SlideTransition(
      position: Tween(begin: Offset(fromEnd ? 1 : -1, 0), end: Offset.zero)
          .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic)),
      child: child,
    ),
    pageBuilder: (ctx, _, _) {
      const r = Radius.circular(16);
      return Align(
        alignment: fromEnd ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          // Swipe back toward the edge to close, like Scaffold drawers.
          onHorizontalDragEnd: (d) {
            final v = d.primaryVelocity ?? 0;
            if (fromEnd ? v > 300 : v < -300) Navigator.of(ctx).pop();
          },
          child: Drawer(
            width: (MediaQuery.sizeOf(ctx).width * .86).clamp(0.0, 360.0),
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: fromEnd ? const BorderRadius.horizontal(left: r) : const BorderRadius.horizontal(right: r),
            ),
            child: content(ctx),
          ),
        ),
      );
    },
  );
}

class _DrawerContent extends ConsumerWidget {
  const _DrawerContent({
    required this.pageContext,
    required this.sheetContext,
    this.city,
    this.language,
    this.onCity,
    this.onLanguage,
    this.onCategory,
  });

  final BuildContext pageContext;
  final BuildContext sheetContext;
  final String? city;
  final String? language;
  final ValueChanged<String>? onCity;
  final ValueChanged<String>? onLanguage;
  final ValueChanged<String>? onCategory;

  /// Closes the drawer, then runs [action] against the page underneath.
  void _then(void Function(BuildContext page) action) {
    Navigator.of(sheetContext).pop();
    if (pageContext.mounted) action(pageContext);
  }

  void _explore(String section) => _then((page) {
        final anchors = SectionAnchors.maybeOf(page);
        if (GoRouterState.of(page).uri.path == '/' && anchors != null) {
          anchors.scrollTo(section);
        } else {
          page.go('/?section=$section');
        }
      });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ios = useCupertino(context);
    final user = ref.watch(authProvider).value;
    final exp = useFestival(ref, 'home');
    final categories = objList((ref.watch(v2GlobalDataProvider).value ?? const {})['generalCategories']);
    final locations = ref.watch(locationsProvider).value ?? const [];
    final langs = ref.watch(languagesProvider).value ?? const [];
    final ll = ref.watch(locLangProvider);
    final cities = filterVisibleLocations(locations).map((l) => str(l['locationName'])).toList();
    final languages = langs.map((l) => str(l['languageName'])).toList();
    final curCity = city ?? ll.location;
    final curLang = language ?? ll.language;

    String match(String v, List<String> items) => items.firstWhere((i) => i.toLowerCase() == v.toLowerCase(), orElse: () => _cap(v));

    Future<void> editPreferences({bool focusLanguage = false}) async {
      final v = await showPreferencesSheet(context,
          city: match(curCity, cities), language: match(curLang, languages), focusLanguage: focusLanguage);
      if (v == null) return;
      final cityChanged = v.city.toLowerCase() != curCity.toLowerCase();
      final langChanged = v.language.toLowerCase() != curLang.toLowerCase();
      ref.read(locLangProvider.notifier).select(location: v.city, language: v.language);
      _then((page) {
        if (cityChanged && onCity != null) onCity!(v.city);
        if (langChanged && onLanguage != null) onLanguage!(v.language);
        if ((cityChanged && onCity == null) || (langChanged && onLanguage == null)) {
          page.push('/${v.language.toLowerCase()}/${v.city.toLowerCase()}/pooja');
        }
      });
    }

    void openCategory(Json cat) => _then((page) => onCategory != null
        ? onCategory!(str(cat['slug']))
        : page.push('/${curLang.toLowerCase()}/${curCity.toLowerCase()}/category/${str(cat['slug'])}'));

    Future<void> logout() async {
      if (await confirmLogout(context)) _then((_) => ref.read(authProvider.notifier).logout());
    }

    final groups = <_Group>[
      _Group('Explore', [
        for (final l in _exploreLinks) _Item(l.$1, l.$2, onTap: () => _explore(l.$3)),
      ]),
      _Group('Preferences', [
        _Item(LucideIcons.mapPin, 'City', value: _cap(curCity), onTap: editPreferences),
        _Item(LucideIcons.globe, 'Language', value: _cap(curLang), onTap: () => editPreferences(focusLanguage: true)),
      ]),
      if (user != null)
        _Group('My Account', [
          for (final l in _accountLinks) _Item(l.$1, l.$2, onTap: () => _then((page) => page.push(l.$3))),
        ]),
      _Group('Help & Support', [
        _Item(LucideIcons.phoneCall, 'Call 9869 92 92 92', onTap: () => _then((_) => callPhone())),
        _Item(LucideIcons.messageCircle, 'Chat on WhatsApp',
            leading: const WhatsAppIcon(size: 20, color: AppColors.whatsapp),
            onTap: () => _then((page) => openWhatsApp(
                "Hi! I'd like to chat with a Puja Advisor about booking a ceremony.\n\n${pageReference(GoRouterState.of(page).uri.toString())}"))),
      ]),
      _Group('More', [
        for (final l in _infoLinks) _Item(l.$1, l.$2, onTap: () => _then((page) => page.push(l.$3))),
      ]),
      if (user != null) _Group('', [_Item(LucideIcons.logOut, 'Log out', destructive: true, onTap: logout)]),
    ];

    final campaign = exp == null ? null : _CampaignCard(experience: exp, onTap: () {
      final href = str(exp.fxCampaign['landingHref']);
      _then((page) => goHref(page, href));
    });

    final header = _Header(
      user: user,
      onAccount: () => _then((page) => page.push(user == null ? '/auth' : '/user/profile')),
    );

    return ios
        ? _CupertinoBody(
            header: header,
            campaign: campaign,
            groups: groups,
            categories: categories,
            onCategory: openCategory,
            onClose: () => Navigator.of(sheetContext).pop(),
          )
        : _MaterialBody(header: header, campaign: campaign, groups: groups, categories: categories, onCategory: openCategory);
  }
}

/// The native "Log out?" confirmation; true when the user confirms.
Future<bool> confirmLogout(BuildContext context) async {
  final ok = await showAdaptiveDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog.adaptive(
      title: const Text('Log out?'),
      content: const Text('You will need to sign in again with your phone number.'),
      actions: [
        adaptiveDialogAction(ctx, 'Cancel', () => Navigator.of(ctx).pop(false)),
        adaptiveDialogAction(ctx, 'Log out', () => Navigator.of(ctx).pop(true), destructive: true),
      ],
    ),
  );
  return ok == true;
}

/// A platform-styled action for [AlertDialog.adaptive].
Widget adaptiveDialogAction(BuildContext context, String label, VoidCallback onPressed, {bool destructive = false}) {
  if (useCupertino(context)) {
    return CupertinoDialogAction(isDestructiveAction: destructive, onPressed: onPressed, child: Text(label));
  }
  return TextButton(
    onPressed: onPressed,
    style: destructive ? TextButton.styleFrom(foregroundColor: AppColors.destructive) : null,
    child: Text(label),
  );
}

class _Group {
  const _Group(this.title, this.items);
  final String title;
  final List<_Item> items;
}

class _Item {
  const _Item(this.icon, this.title, {required this.onTap, this.value, this.leading, this.destructive = false});
  final IconData icon;
  final String title;
  final String? value;
  final Widget? leading;
  final bool destructive;
  final VoidCallback onTap;
}

class _Header extends StatelessWidget {
  const _Header({required this.user, required this.onAccount});
  final Json? user;
  final VoidCallback onAccount;

  @override
  Widget build(BuildContext context) {
    final u = user;
    final image = strOrNull(u?['profileImage']);
    final sub = u == null ? 'Sign in to book and track your pujas' : (strOrNull(u['phone']) ?? strOrNull(u['email']) ?? '');
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: SizedBox(
          width: 132,
          height: 44,
          child: SiteImage('/images/bmp.png', fit: BoxFit.contain, alignment: Alignment.centerLeft, placeholderColor: Colors.transparent),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Material(
          color: AppColors.primary.withValues(alpha: .06),
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onAccount,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primary.withValues(alpha: .12),
                  // The icon stays underneath so a slow or broken photo still shows something.
                  child: Stack(alignment: Alignment.center, children: [
                    const Icon(LucideIcons.user, color: AppColors.primary),
                    if (image != null) ClipOval(child: SiteImage(image, width: 48, height: 48, fit: BoxFit.cover, placeholderColor: Colors.transparent)),
                  ]),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(u == null ? 'Login / Sign Up' : displayName(u),
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(size: 16, weight: FontWeight.w700)),
                    if (sub.isNotEmpty)
                      Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(size: 13, color: AppColors.mutedForeground)),
                  ]),
                ),
                const Icon(LucideIcons.chevronRight, size: 18, color: AppColors.mutedForeground),
              ]),
            ),
          ),
        ),
      ),
    ]);
  }
}

/// The running festival campaign (GlobalFestivalStrip's link), themed.
class _CampaignCard extends StatelessWidget {
  const _CampaignCard({required this.experience, required this.onTap});
  final Json experience;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = experience.fxTheme;
    final c = experience.fxCampaign;
    final name = strOrNull(c['festivalName']) ?? str(c['name']);
    final sub = strOrNull(pick(experience, ['copy', 'strip'])) ?? 'Bookings are open';
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Material(
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(gradient: LinearGradient(colors: [t.bg, t.bg2])),
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: t.accent.withValues(alpha: .18), shape: BoxShape.circle),
                alignment: Alignment.center,
                child: const Text('🪔', style: TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('CURRENT CAMPAIGN', style: AppText.body(size: 10, weight: FontWeight.w700, color: t.accent, letterSpacing: 1)),
                  Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(size: 16, weight: FontWeight.w700, color: t.fg)),
                  Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(size: 12, color: t.muted)),
                ]),
              ),
              Icon(LucideIcons.chevronRight, size: 18, color: t.accent),
            ]),
          ),
        ),
      ),
    );
  }
}

class _MaterialBody extends StatelessWidget {
  const _MaterialBody({required this.header, required this.campaign, required this.groups, required this.categories, required this.onCategory});
  final Widget header;
  final Widget? campaign;
  final List<_Group> groups;
  final List<Json> categories;
  final ValueChanged<Json> onCategory;

  Widget _tile(_Item i) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: ListTile(
          shape: const StadiumBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          leading: i.leading ?? Icon(i.icon, size: 22, color: i.destructive ? AppColors.destructive : AppColors.foreground.withValues(alpha: .75)),
          title: Text(i.title,
              style: AppText.body(size: 15, weight: FontWeight.w500, color: i.destructive ? AppColors.destructive : AppColors.foreground)),
          trailing: i.value == null
              ? null
              : Text(i.value!, style: AppText.body(size: 14, weight: FontWeight.w600, color: AppColors.primary)),
          onTap: i.onTap,
        ),
      );

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(28, 16, 28, 4),
        child: Text(t, style: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.mutedForeground)),
      );

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(padding: const EdgeInsets.only(bottom: 16), children: [
        header,
        ?campaign,
        for (final (gi, g) in groups.indexed) ...[
          if (gi > 0) const Padding(padding: EdgeInsets.fromLTRB(28, 8, 28, 0), child: Divider(height: 1)),
          if (g.title.isNotEmpty) _section(g.title) else const SizedBox(height: 8),
          for (final i in g.items) _tile(i),
          // Categories expand under Explore, like a nested drawer group.
          if (gi == 0 && categories.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  // A stadium's radius grows with the open list and would clip the header.
                  shape: const RoundedRectangleBorder(),
                  collapsedShape: const StadiumBorder(),
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                  leading: Icon(LucideIcons.listTree, size: 22, color: AppColors.foreground.withValues(alpha: .75)),
                  title: Text('Browse by category', style: AppText.body(size: 15, weight: FontWeight.w500)),
                  childrenPadding: const EdgeInsets.only(left: 40),
                  children: [
                    for (final c in categories)
                      ListTile(
                        dense: true,
                        shape: const StadiumBorder(),
                        title: Text(str(c['subCategoryName']), style: AppText.body(size: 14)),
                        onTap: () => onCategory(c),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ]),
    );
  }
}

class _CupertinoBody extends StatelessWidget {
  const _CupertinoBody({
    required this.header,
    required this.campaign,
    required this.groups,
    required this.categories,
    required this.onCategory,
    required this.onClose,
  });
  final Widget header;
  final Widget? campaign;
  final List<_Group> groups;
  final List<Json> categories;
  final ValueChanged<Json> onCategory;
  final VoidCallback onClose;

  Widget _iconBox(_Item i) => Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: i.destructive ? CupertinoColors.systemRed : AppColors.primary,
          borderRadius: BorderRadius.circular(7),
        ),
        alignment: Alignment.center,
        child: i.leading != null ? const WhatsAppIcon(size: 17) : Icon(i.icon, size: 17, color: CupertinoColors.white),
      );

  @override
  Widget build(BuildContext context) {
    final sections = <Widget>[
      for (final (gi, g) in groups.indexed) ...[
        CupertinoListSection.insetGrouped(
          header: g.title.isEmpty ? null : Text(g.title.toUpperCase()),
          children: [
            for (final i in g.items)
              CupertinoListTile.notched(
                leading: _iconBox(i),
                title: Text(i.title, style: TextStyle(color: i.destructive ? CupertinoColors.systemRed : null)),
                additionalInfo: i.value == null ? null : Text(i.value!),
                trailing: i.destructive ? null : const CupertinoListTileChevron(),
                onTap: i.onTap,
              ),
          ],
        ),
        if (gi == 0 && categories.isNotEmpty)
          CupertinoListSection.insetGrouped(
            header: const Text('BROWSE BY CATEGORY'),
            children: [
              for (final c in categories)
                CupertinoListTile.notched(
                  title: Text(str(c['subCategoryName'])),
                  trailing: const CupertinoListTileChevron(),
                  onTap: () => onCategory(c),
                ),
            ],
          ),
      ],
    ];
    return Column(children: [
      Align(
        alignment: Alignment.centerRight,
        child: CupertinoButton(onPressed: onClose, child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w600))),
      ),
      Expanded(
        child: Material(
          type: MaterialType.transparency,
          child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [header, ?campaign, ...sections]),
        ),
      ),
    ]);
  }
}

/// The avatar menu on inner pages (UserMenu.jsx): a native account sheet.
Future<void> showAccountSheet(BuildContext context, WidgetRef ref) async {
  final user = ref.read(authProvider).value;
  void go(BuildContext ctx, String path) {
    Navigator.of(ctx).pop();
    context.push(path);
  }

  Future<void> logout(BuildContext ctx) async {
    Navigator.of(ctx).pop();
    if (await confirmLogout(context)) ref.read(authProvider.notifier).logout();
  }

  if (useCupertino(context)) {
    return showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(displayName(user)),
        message: Text(strOrNull(user?['phone']) ?? ''),
        actions: [
          for (final l in _accountLinks) CupertinoActionSheetAction(onPressed: () => go(ctx, l.$3), child: Text(l.$2)),
          CupertinoActionSheetAction(isDestructiveAction: true, onPressed: () => logout(ctx), child: const Text('Log out')),
        ],
        cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
      ),
    );
  }

  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    builder: (ctx) => SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 24),
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: .12),
          // Same as the drawer header: the icon stays underneath so a slow or
          // broken photo still shows something.
          child: Stack(alignment: Alignment.center, children: [
            const Icon(LucideIcons.user, color: AppColors.primary),
            if (strOrNull(user?['profileImage']) != null)
              ClipOval(
                child: SiteImage(str(user?['profileImage']), width: 40, height: 40, fit: BoxFit.cover, placeholderColor: Colors.transparent),
              ),
          ]),
        ),
        title: Text(displayName(user), style: AppText.body(size: 16, weight: FontWeight.w700)),
        subtitle: Text(strOrNull(user?['phone']) ?? strOrNull(user?['email']) ?? ''),
      ),
      const Divider(height: 1),
      for (final l in _accountLinks)
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 24),
          leading: Icon(l.$1),
          title: Text(l.$2, style: AppText.body(size: 15, weight: FontWeight.w500)),
          onTap: () => go(ctx, l.$3),
        ),
      const Divider(height: 1),
      ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 24),
        leading: const Icon(LucideIcons.logOut, color: AppColors.destructive),
        title: Text('Log out', style: AppText.body(size: 15, weight: FontWeight.w500, color: AppColors.destructive)),
        onTap: () => logout(ctx),
      ),
      const SizedBox(height: 8),
    ])),
  );
}
