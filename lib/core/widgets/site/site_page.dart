import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../features/festival/festival_widgets.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../utils/launch.dart';
import '../../utils/nav.dart';
import '../brand_icons.dart';
import '../site_image.dart';
import 'upper_section.dart';
import 'user_menu.dart';
import '../ui.dart';

/// components/layout/V2CommonLayout.jsx — festival strip, sticky
/// UpperSection and page content (no footer in the app); plus the "Have Questions?" bar on
/// /user routes and FestivalNudges on eligible pages.
class SitePage extends ConsumerStatefulWidget {
  const SitePage({
    super.key,
    this.children,
    this.slivers,
    this.pageType,
    this.city,
    this.language,
    this.onCityChange,
    this.onLanguageChange,
    this.onCategorySelect,
    this.hideNav = false,
    this.isUserRoute = false,
    this.bottomBar,
    this.overlay,
    this.background = AppColors.background,
    this.scrollController,
    this.loading = false,
  }) : assert(children != null || slivers != null);

  final List<Widget>? children;
  final List<Widget>? slivers;

  /// Festival page type (`home`, `listing`, `category`, `pdp`, `festival`,
  /// `other`); null on the website's quiet routes.
  final String? pageType;
  final String? city;
  final String? language;
  final ValueChanged<String>? onCityChange;
  final ValueChanged<String>? onLanguageChange;
  final ValueChanged<String>? onCategorySelect;
  final bool hideNav;
  final bool isUserRoute;
  final Widget? bottomBar;
  final Widget? overlay;
  final Color background;
  final ScrollController? scrollController;
  final bool loading;

  @override
  ConsumerState<SitePage> createState() => _SitePageState();
}

class _SitePageState extends ConsumerState<SitePage> {
  late final ScrollController _scroll = widget.scrollController ?? ScrollController();

  @override
  void dispose() {
    if (widget.scrollController == null) _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pageType = widget.pageType;
    final exp = pageType == null
        ? null
        : useFestival(ref, pageType, location: widget.city, language: widget.language);

    final slivers = <Widget>[
      if (!widget.hideNav) ...[
        SliverToBoxAdapter(child: GlobalFestivalStrip(experience: exp, onFestivalPage: pageType == 'festival')),
        PinnedHeaderSliver(
          child: UpperSection(
            city: widget.city,
            language: widget.language,
            onCityChange: widget.onCityChange,
            onLanguageChange: widget.onLanguageChange,
            onCategorySelect: widget.onCategorySelect,
          ),
        ),
      ],
      if (widget.slivers != null)
        ...widget.slivers!
      else
        SliverList.list(children: widget.children!),
      const SliverToBoxAdapter(child: SizedBox(height: 24)),
    ];

    Widget body = CustomScrollView(controller: _scroll, slivers: slivers);
    if (widget.loading) {
      body = Stack(children: [
        Opacity(opacity: .3, child: IgnorePointer(child: body)),
        Positioned.fill(
          child: Container(
            color: Colors.white.o(.7),
            alignment: const Alignment(0, -.6),
            child: const AppSpinner(),
          ),
        ),
      ]);
    }
    if (pageType != null && exp != null) {
      body = FestivalNudges(experience: exp, pageType: pageType, scrollController: _scroll, child: body);
    }
    if (widget.overlay != null) {
      body = Stack(children: [body, widget.overlay!]);
    }

    return SectionAnchors(
      child: Scaffold(
        backgroundColor: widget.background,
        body: SafeArea(bottom: false, child: body),
        bottomNavigationBar: widget.bottomBar ?? (widget.isUserRoute ? const UserRouteHelpBar() : null),
      ),
    );
  }
}

/// The sticky "Have Questions?" bar V2CommonLayout shows on /user routes.
class UserRouteHelpBar extends StatelessWidget {
  const UserRouteHelpBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [BoxShadow(color: Color(0x1A000000), blurRadius: 6, offset: Offset(0, -2))],
      ),
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.paddingOf(context).bottom),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Have Questions?', style: AppText.body(size: 14, weight: FontWeight.w700, color: AppColors.primary)),
                Text('Reach out to Puja Seva team',
                    style: AppText.body(size: 10, weight: FontWeight.w500, color: AppColors.mutedForeground)),
              ],
            ),
          ),
          _pill(
            color: AppColors.blue600,
            radius: 12,
            onTap: () => callPhone(),
            icon: const Icon(LucideIcons.phone, size: 14, color: Colors.white),
            label: 'Call',
          ),
          const SizedBox(width: 8),
          _pill(
            color: AppColors.whatsappBrand,
            radius: 12,
            onTap: () => openWhatsApp(
              "Hi! I'd like to chat with a Puja Advisor about a ceremony.\n\n${pageReference(currentPath(context))}",
            ),
            icon: const SiteImage('/icons/whatsapp.svg', width: 14, height: 14, placeholderColor: Colors.transparent),
            label: 'WhatsApp',
          ),
        ],
      ),
    );
  }
}

Widget _pill({
  required Color color,
  required double radius,
  required VoidCallback onTap,
  required Widget icon,
  required String label,
  double height = 36,
}) =>
    Material(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            icon,
            const SizedBox(width: 8),
            Text(label, style: AppText.body(size: 11, weight: FontWeight.w700, color: Colors.white)),
          ]),
        ),
      ),
    );

/// components/v2/StickyMobileContact.jsx (PDP bottom bar).
class StickyMobileContact extends StatelessWidget {
  const StickyMobileContact({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.o(.95),
        border: const Border(top: BorderSide(color: AppColors.gray100)),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 30, offset: Offset(0, -8))],
      ),
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.paddingOf(context).bottom),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Have Questions?',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body(size: 13, weight: FontWeight.w700, color: AppColors.bluntRed, height: 1.25)),
                const SizedBox(height: 2),
                Text('Reach out to Puja Seva team',
                    style: AppText.body(size: 10, weight: FontWeight.w500, color: AppColors.gray500, height: 1.25)),
              ],
            ),
          ),
          _pill(
            color: AppColors.blue600,
            radius: 999,
            onTap: () => callPhone(),
            icon: const Icon(Icons.phone, size: 14, color: Colors.white),
            label: 'Call',
          ),
          const SizedBox(width: 8),
          _pill(
            color: AppColors.whatsappBrand,
            radius: 999,
            onTap: () => openWhatsApp('Hi, I have a question about a puja.\n\n${pageReference(currentPath(context))}'),
            icon: const WhatsAppIcon(size: 14),
            label: 'WhatsApp',
          ),
        ],
      ),
    );
  }
}

/// pages/404.jsx-style fallback used by the router.
class NotFoundBody extends StatelessWidget {
  const NotFoundBody({super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
        child: Column(children: [
          Text('404', style: AppText.heading(size: 48, color: AppColors.primary)),
          const SizedBox(height: 12),
          Text('Page not found', style: AppText.body(size: 18, weight: FontWeight.w600)),
          const SizedBox(height: 24),
          TextButton(onPressed: () => context.go('/'), child: const Text('Go Home')),
        ]),
      );
}
