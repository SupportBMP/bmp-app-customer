import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/state/app_state.dart';
import '../../core/storage/cookies.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/json.dart';
import '../../core/utils/nav.dart';
import '../../core/widgets/site/upper_section.dart';
import '../festival/festival_widgets.dart';
import '../festival/ornaments.dart';
import 'home_sections_a.dart';
import 'home_sections_b.dart';
import 'home_sections_c.dart';

/// data/homepage-v2.json, bundled like the website imports it.
final homepageV2JsonProvider = FutureProvider<Json>((ref) async {
  final raw = await rootBundle.loadString('assets/data/homepage-v2.json');
  return obj(jsonDecode(raw));
});

/// pages/index.jsx
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key, this.section});

  /// A homepage section to scroll to once loaded (`/?section=faq`).
  final String? section;

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _scroll = ScrollController();
  ExitIntentController? _exit;
  String? _scrolledTo;

  @override
  void didUpdateWidget(HomePage old) {
    super.didUpdateWidget(old);
    if (old.section != widget.section) _scrolledTo = null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final redirect = Cookies.get('redirectUrl');
      if (redirect != null && redirect.isNotEmpty) {
        Cookies.remove('redirectUrl');
        if (mounted) context.push(redirect);
      }
    });
  }

  @override
  void dispose() {
    _exit?.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final json = ref.watch(homepageV2JsonProvider).value;
    if (json == null) return const Scaffold(backgroundColor: AppColors.background);
    final data = ref.watch(homepageDataProvider).value ?? const <String, dynamic>{};
    final exp = useFestival(ref, 'home');

    return SectionAnchors(
      child: Builder(
        builder: (context) {
          _exit ??= ExitIntentController(context: context, scroll: _scroll, data: obj(json['exitPopup']))..start();
          final section = widget.section;
          if (section != null && _scrolledTo != section && ref.read(homepageDataProvider).hasValue) {
            _scrolledTo = section;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) SectionAnchors.maybeOf(context)?.scrollTo(section);
            });
          }
          final media = obj(json['media']);
          final partners = obj(json['partners']);

          final page = CustomScrollView(
            controller: _scroll,
            slivers: [
              SliverToBoxAdapter(child: GlobalFestivalStrip(experience: exp)),
              const PinnedHeaderSliver(child: UpperSection()),
              SliverList.list(
                children: [
                  HeroSection(heroData: obj(json['hero']), experience: exp),
                  FestivalHero(experience: exp),
                  OurPromiseStrip(data: obj(json['promise']), topPadding: 0),
                  const OrnamentalDivider(),
                  SelfBookingSection(data: obj(json['selfBooking'])),
                  CategoriesSection(categories: objList(data['generalCategories']), data: obj(json['categories'])),
                  CredibilityStrip(label: str(media['label']), items: objList(media['items'])),
                  NeedHelpStrip(data: obj(json['helpStrip'])),
                  TrustSection(testimonials: objList(data['testimonials']), data: obj(json['trust'])),
                  FeaturedPriestsSection(data: obj(json['featuredPriests'])),
                  const OrnamentalDivider(),
                  EnquiryFormSection(data: obj(json['enquiry'])),
                  CredibilityStrip(label: str(partners['label']), items: objList(partners['items'])),
                  const OrnamentalDivider(),
                  FaqSection(items: objList(data['faq'])),
                  FinalCtaSection(data: obj(json['finalCta'])),
                  const SizedBox(height: 24),
                ],
              ),
            ],
          );

          return Scaffold(
            backgroundColor: AppColors.background,
            body: Listener(
              onPointerDown: (_) => _exit?.onActivity(),
              child: SafeArea(
                bottom: false,
                child: FestivalNudges(
                  experience: exp,
                  pageType: 'home',
                  scrollController: _scroll,
                  child: Stack(
                    children: [
                      page,
                      Positioned(left: 16, bottom: 8, child: LiveBookingFeed(latestOrders: objList(data['latestOrders']))),
                    ],
                  ),
                ),
              ),
            ),
            bottomNavigationBar: StickyMobileCta(data: obj(json['stickyMobile']), scrollController: _scroll),
          );
        },
      ),
    );
  }
}
