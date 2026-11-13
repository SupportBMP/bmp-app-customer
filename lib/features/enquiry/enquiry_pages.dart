import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api/bmp_api.dart';
import '../../core/config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/json.dart';
import '../../core/utils/launch.dart';
import '../../core/utils/leads.dart';
import '../../core/utils/nav.dart';
import '../../core/widgets/brand_icons.dart';
import '../../core/widgets/site/user_menu.dart';
import '../../core/widgets/site_image.dart';
import '../../core/widgets/ui.dart';
import '../../core/widgets/native.dart';

// Tailwind shades used only on the enquiry pages.
const _bluntRed = Color(0xFF8A1C23);
const _gold = Color(0xFF9B7C1D);
const _peach = Color(0xFFFEEDD5);
const _cream = Color(0xFFFEF8F2);
const _wa = Color(0xFF1DA851);
const _yellow50 = Color(0xFFFEFCE8);
const _yellow200 = Color(0xFFFEF08A);
const _yellow700 = Color(0xFFA16207);
const _yellow800 = Color(0xFF854D0E);
const _orange100 = Color(0xFFFFEDD5);
const _green200 = Color(0xFFBBF7D0);
const _purple100 = Color(0xFFF3E8FF);
const _purple500 = Color(0xFFA855F7);

final _jsonAsset = FutureProvider.family<Json, String>(
  (ref, name) async => obj(jsonDecode(await rootBundle.loadString('assets/data/$name.json'))),
);

final _sampleReviews = FutureProvider<List<Json>>(
  (ref) async => objList(jsonDecode(await rootBundle.loadString('assets/data/google_sample_reviews.json'))),
);

/// pages/enquiry/*.jsx. [dataFile] is the `data/*.json` a variant reads its
/// hero heading/subHeading from; the index page passes none and shows the
/// category selector.
class EnquiryPage extends ConsumerWidget {
  const EnquiryPage({super.key, this.dataFile});
  final String? dataFile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(_jsonAsset('enquiry-default')).value;
    final page = dataFile == null ? null : ref.watch(_jsonAsset(dataFile!)).value;
    if (data == null || (dataFile != null && page == null)) {
      return const Scaffold(backgroundColor: Colors.white, body: AppSpinner());
    }
    final hero = obj(page?['hero']);
    return EnquiryHomePage(
      enquiryData: data,
      headline: strOrNull(hero['heading']),
      subHeadline: strOrNull(hero['subHeading']),
      hideCategorySelector: dataFile != null,
    );
  }
}

/// components/EnquiryContainer/enquiry.jsx — no site header/footer
/// (`isEnquiryRoute` in _app).
class EnquiryHomePage extends StatefulWidget {
  const EnquiryHomePage({
    super.key,
    required this.enquiryData,
    this.headline,
    this.subHeadline,
    this.hideCategorySelector = false,
    this.languageSlug,
  });

  final Json enquiryData;
  final String? headline;
  final String? subHeadline;
  final bool hideCategorySelector;
  final String? languageSlug;

  @override
  State<EnquiryHomePage> createState() => _EnquiryHomePageState();
}

class _EnquiryHomePageState extends State<EnquiryHomePage> {
  @override
  Widget build(BuildContext context) {
    final d = widget.enquiryData;
    return SectionAnchors(
      child: Builder(builder: (context) {
        void scrollToBooking() => SectionAnchors.maybeOf(context)?.scrollTo('booking-form');
        return Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            bottom: false,
            child: Stack(children: [
              Column(children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      _HeroSection(
                        headline: widget.headline,
                        subHeadline: widget.subHeadline,
                        ctaText: strOrNull(obj(d['hero'])['ctaText']),
                        onBook: scrollToBooking,
                      ),
                      if (!widget.hideCategorySelector) _CategorySelector(data: obj(d['categories']), onBook: scrollToBooking),
                      _TrustSection(data: obj(d['trust'])),
                      _VideoTestimonials(data: obj(d['videoTestimonials']), onBook: scrollToBooking),
                      _TestimonialSection(data: obj(d['testimonials'])),
                      Anchor('booking-form', child: _BookingForm(data: obj(d['booking']), languageSlug: widget.languageSlug)),
                      _FaqSection(data: obj(d['faq'])),
                      _FinalCta(data: obj(d['cta']), onBook: scrollToBooking),
                    ]),
                  ),
                ),
                // BookingForm's mobile sticky reminder bar.
                _StickyReminderBar(onBook: scrollToBooking),
              ]),
              const _FloatingEdgeCta(),
            ]),
          ),
        );
      }),
    );
  }
}

void _openAdvisorWhatsApp(BuildContext context, String text) =>
    openWhatsApp('$text\n\n${pageReference(currentPath(context))}');

Widget _sectionTitle(String title, String subtitle, {double gap = 16, Color subColor = AppColors.gray600}) => Padding(
      padding: const EdgeInsets.only(bottom: 48),
      child: Column(children: [
        Text(title, textAlign: TextAlign.center, style: AppText.sans(size: 30, weight: FontWeight.w700, color: _bluntRed, height: 36 / 30)),
        SizedBox(height: gap),
        Text(subtitle, textAlign: TextAlign.center, style: AppText.sans(size: 18, color: subColor, height: 28 / 18)),
      ]),
    );

class _WaButton extends StatelessWidget {
  const _WaButton({required this.label, required this.onTap, this.icon = true, this.radius = 8, this.fontSize = 16, this.expand = false});
  final bool expand;
  final String label;
  final VoidCallback onTap;
  final bool icon;
  final double radius;
  final double fontSize;

  @override
  Widget build(BuildContext context) => Tap(
        onTap: onTap,
        radius: radius,
        child: Container(
          width: expand ? double.infinity : null,
          alignment: expand ? Alignment.center : null,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: _wa,
            borderRadius: BorderRadius.circular(radius),
            boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 6, offset: Offset(0, 4))],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
            if (icon) ...[const WhatsAppIcon(size: 20), const SizedBox(width: 12)],
            Flexible(child: Text(label, textAlign: TextAlign.center, style: AppText.sans(size: fontSize, weight: FontWeight.w500, color: Colors.white))),
          ]),
        ),
      );
}

class _RedButton extends StatelessWidget {
  const _RedButton({
    required this.label,
    required this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    this.fontSize = 16,
    this.radius = 8,
    this.expand = false,
  });
  final bool expand;
  final String label;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final double fontSize;
  final double radius;

  @override
  Widget build(BuildContext context) => Tap(
        onTap: onTap,
        radius: radius,
        child: Container(
          width: expand ? double.infinity : null,
          alignment: expand ? Alignment.center : null,
          padding: padding,
          decoration: BoxDecoration(
            color: _bluntRed,
            borderRadius: BorderRadius.circular(radius),
            boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 15, offset: Offset(0, 10))],
          ),
          child: Text(label, textAlign: TextAlign.center, style: AppText.sans(size: fontSize, weight: FontWeight.w500, color: Colors.white)),
        ),
      );
}

// ---------------------------------------------------------------------------
// EnquiryHeroSection.jsx + PoojaStyleContainer.jsx
// ---------------------------------------------------------------------------

class _HeroSection extends StatelessWidget {
  const _HeroSection({this.headline, this.subHeadline, this.ctaText, required this.onBook});
  final String? headline;
  final String? subHeadline;
  final String? ctaText;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    final utmTerm = GoRouterState.of(context).uri.queryParameters['utm_term'];
    final h2 = AppText.sans(size: 20, weight: FontWeight.w600, color: _bluntRed, height: 1.375);
    return Container(
      color: _peach,
      constraints: BoxConstraints(minHeight: MediaQuery.sizeOf(context).height),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
      child: Column(children: [
        GestureDetector(
          onTap: () => context.go('/'),
          child: const SizedBox(width: 160, height: 64, child: SiteImage('/images/bmp.png', fit: BoxFit.contain, placeholderColor: Colors.transparent)),
        ),
        const SizedBox(height: 24),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 0; i < 5; i++) const Icon(Icons.star_rounded, size: 16, color: _yellow700),
          const SizedBox(width: 8),
          Text('4.8★ Google Rated', style: AppText.sans(size: 14, weight: FontWeight.w500, color: _yellow700)),
        ]),
        const SizedBox(height: 24),
        if (utmTerm != null && utmTerm.isNotEmpty) ...[
          Text(utmTerm,
              textAlign: TextAlign.center,
              style: AppText.sans(size: 30, weight: FontWeight.w800, color: const Color(0xFF701417), height: 1.25, letterSpacing: -0.75)),
          const SizedBox(height: 12),
        ],
        if (headline != null)
          Text(headline!, textAlign: TextAlign.center, style: h2)
        else
          Text.rich(
            TextSpan(children: [
              const TextSpan(text: 'Worried About Doing the Puja Right? Let Us Handle Everything –\n'),
              TextSpan(text: ' the Right Way.', style: h2.copyWith(color: _gold)),
            ]),
            textAlign: TextAlign.center,
            style: h2,
          ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 576),
          child: Text(
            subHeadline ?? 'From pandit to samagri to rituals – Book Any Puja With Peace of Mind. 100% Vedic. 100% Hassle-Free.',
            textAlign: TextAlign.center,
            style: AppText.sans(size: 16, color: AppColors.gray700, height: 1.625),
          ),
        ),
        const SizedBox(height: 24),
        for (final f in const ['Certified Pandits (All languages)', 'All Inclusive Packages', 'Online & At-Home Options'])
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(LucideIcons.check, size: 16, color: AppColors.green600),
              const SizedBox(width: 8),
              Text(f, style: AppText.sans(size: 12, weight: FontWeight.w500)),
            ]),
          ),
        const SizedBox(height: 12),
        _RedButton(label: ctaText ?? 'Book Your Puja', onTap: onBook, expand: true),
        const SizedBox(height: 12),
        _WaButton(
          label: 'Chat with Puja Seva Team',
          expand: true,
          onTap: () => _openAdvisorWhatsApp(context, "Hi! I'd like to chat with a Puja Advisor about booking a ceremony."),
        ),
        const SizedBox(height: 16),
        _PujaStyleAccordion(onBook: onBook),
      ]),
    );
  }
}

class _PujaStyleAccordion extends StatefulWidget {
  const _PujaStyleAccordion({required this.onBook});
  final VoidCallback onBook;

  @override
  State<_PujaStyleAccordion> createState() => _PujaStyleAccordionState();
}

class _PujaStyleAccordionState extends State<_PujaStyleAccordion> {
  String? _active;

  static const _south = [
    ('Kannada Purohits', 'Traditional Karnataka style rituals'),
    ('Telugu Poojari', 'Authentic Andhra Pradesh traditions'),
    ('Tamil Vadhyars', 'Classical Tamil Nadu ceremonies'),
    ('Malayalam Pandit', 'Kerala temple style worship'),
  ];
  static const _north = [
    ('Hindi North Indian Pandits', 'Traditional Vedic rituals'),
    ('Marathi Gurujis', 'Maharashtra cultural traditions'),
    ('Gujarati Pandits', 'Gujarat regional ceremonies'),
    ('Marwari Pandits', 'Rajasthani traditional worship'),
    ('Bengali Pandits', 'Bengal cultural rituals'),
  ];

  Widget _style(String key, String title, String sub, String image, List<(String, String)> options) {
    final open = _active == key;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      GestureDetector(
        onTap: () => setState(() => _active = open ? null : key),
        child: Container(
          height: 192,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 15, offset: Offset(0, 10))],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(fit: StackFit.expand, children: [
            SiteImage(image, fit: BoxFit.cover),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Color(0x80000000), Colors.transparent, Colors.transparent]),
              ),
            ),
            Positioned(
              left: 16,
              bottom: 16,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(title, style: AppText.sans(size: 18, weight: FontWeight.w600, color: Colors.white)),
                  const SizedBox(width: 8),
                  Icon(open ? LucideIcons.chevronUp : LucideIcons.chevronDown, size: 20, color: Colors.white),
                ]),
                Text(sub, style: AppText.sans(size: 14, color: Colors.white.o(.9))),
              ]),
            ),
          ]),
        ),
      ),
      AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: !open
            ? const SizedBox(width: double.infinity)
            : Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
                  boxShadow: [BoxShadow(color: Color(0x1A000000), blurRadius: 15, offset: Offset(0, 10))],
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  for (final o in options)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.orange50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _orange100),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(o.$1, style: AppText.sans(size: 14, weight: FontWeight.w500, color: AppColors.gray800)),
                        const SizedBox(height: 4),
                        Text(o.$2, style: AppText.sans(size: 12, color: AppColors.gray600)),
                      ]),
                    ),
                  const SizedBox(height: 8),
                  _RedButton(label: 'Book Now - $title', onTap: widget.onBook, fontSize: 14, radius: 6, expand: true),
                ]),
              ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 576),
        child: Column(children: [
          _style('south', 'South Indian Style', 'Classical Temple Traditions', '/images/hero_banner_2.jpg', _south),
          const SizedBox(height: 16),
          _style('north', 'North Indian Style', 'Traditional Vedic Rituals', '/images/hero_banner.jpg', _north),
        ]),
      );
}

// ---------------------------------------------------------------------------
// CategorySelector.jsx
// ---------------------------------------------------------------------------

class _CategorySelector extends StatelessWidget {
  const _CategorySelector({required this.data, required this.onBook});
  final Json data;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();
    final help = obj(data['helpSection']);
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _sectionTitle(str(data['title']), str(data['subtitle'])),
        for (final c in objList(data['items']))
          Container(
            margin: const EdgeInsets.only(bottom: 24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _cream,
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 6, offset: Offset(0, 4))],
            ),
            child: Column(children: [
              SiteImage(str(c['icon']), width: 64, height: 64, fit: BoxFit.contain, placeholderColor: Colors.transparent),
              const SizedBox(height: 16),
              Text(str(c['title']), textAlign: TextAlign.center, style: AppText.sans(size: 18, weight: FontWeight.w600, color: _bluntRed)),
              const SizedBox(height: 8),
              Text(str(c['description']), textAlign: TextAlign.center, style: AppText.sans(size: 14, color: AppColors.gray600)),
              const SizedBox(height: 8),
              Text(str(c['benefit']),
                  textAlign: TextAlign.center,
                  style: AppText.sans(size: 12, weight: FontWeight.w500, color: _gold).copyWith(fontStyle: FontStyle.italic)),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: onBook,
                child: Text('Book Now →',
                    style: AppText.sans(size: 16, weight: FontWeight.w500, color: _bluntRed)
                        .copyWith(decoration: TextDecoration.underline, decorationColor: _bluntRed)),
              ),
            ]),
          ),
        if (help.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: _cream, borderRadius: BorderRadius.circular(8)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(str(help['title']), textAlign: TextAlign.center, style: AppText.sans(size: 16, weight: FontWeight.w700, color: _bluntRed)),
              const SizedBox(height: 8),
              Text(str(help['subtitle']), textAlign: TextAlign.center, style: AppText.sans(size: 16, color: AppColors.gray600)),
              const SizedBox(height: 16),
              Tap(
                onTap: () => callPhone(str(help['phone'])),
                radius: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.blue600,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 6, offset: Offset(0, 4))],
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(LucideIcons.phone, size: 16, color: Colors.white),
                    const SizedBox(width: 8),
                    Text('Call: \n${str(help['phoneDisplay'])}',
                        style: AppText.sans(size: 16, weight: FontWeight.w500, color: Colors.white)),
                  ]),
                ),
              ),
              const SizedBox(height: 16),
              _WaButton(
                label: str(help['ctaText']),
                onTap: () => _openAdvisorWhatsApp(context, "Hi! I'd like to chat with a Puja Advisor about booking a ceremony."),
              ),
            ]),
          ),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// TrustSection.jsx
// ---------------------------------------------------------------------------

class _TrustSection extends StatelessWidget {
  const _TrustSection({required this.data});
  final Json data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();
    final items = objList(data['items']);
    return Container(
      color: _cream,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
      child: Column(children: [
        Text(str(data['title']), textAlign: TextAlign.center, style: AppText.sans(size: 30, weight: FontWeight.w700, color: _bluntRed, height: 36 / 30)),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(color: _yellow50, borderRadius: BorderRadius.circular(999)),
          child: Text(str(data['rating']), style: AppText.sans(size: 16, weight: FontWeight.w500, color: _yellow800)),
        ),
        const SizedBox(height: 48),
        for (var i = 0; i < items.length; i += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (var j = i; j < i + 2; j++) ...[
                if (j > i) const SizedBox(width: 24),
                Expanded(
                  child: j >= items.length
                      ? const SizedBox.shrink()
                      : Column(children: [
                          Text(str(items[j]['icon']), style: const TextStyle(fontSize: 30, height: 36 / 30)),
                          const SizedBox(height: 12),
                          Text(str(items[j]['title']),
                              textAlign: TextAlign.center, style: AppText.sans(size: 16, weight: FontWeight.w600, color: _bluntRed)),
                          const SizedBox(height: 4),
                          Text(str(items[j]['subtitle']), textAlign: TextAlign.center, style: AppText.sans(size: 14, color: AppColors.gray500)),
                        ]),
                ),
              ],
            ]),
          ),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// VideoTestimonials.jsx — playback opens the video externally.
// ---------------------------------------------------------------------------

class _VideoTestimonials extends StatelessWidget {
  const _VideoTestimonials({required this.data, required this.onBook});
  final Json data;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();
    return Container(
      color: _cream,
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 48),
            child: Column(children: [
              Text(str(data['title']), textAlign: TextAlign.center, style: AppText.sans(size: 30, weight: FontWeight.w700, color: _bluntRed, height: 36 / 30)),
              const SizedBox(height: 12),
              Text(str(data['subtitle']), textAlign: TextAlign.center, style: AppText.sans(size: 16, color: AppColors.gray600)),
            ]),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(32, 0, 32, 16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final v in objList(data['items'])) ...[
              GestureDetector(
                onTap: () => openExternal(str(v['videoUrl'])),
                child: Container(
                  width: 288,
                  margin: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 15, offset: Offset(0, 10))],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SizedBox(
                      height: 176,
                      child: Stack(fit: StackFit.expand, children: [
                        SiteImage(str(v['thumbnail']), fit: BoxFit.cover),
                        Container(
                          color: const Color(0x4D000000),
                          alignment: Alignment.center,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                            child: const Icon(Icons.play_arrow_rounded, size: 32, color: _bluntRed),
                          ),
                        ),
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: const Color(0xB3000000), borderRadius: BorderRadius.circular(4)),
                            child: Text(str(v['duration']), style: AppText.sans(size: 12, color: Colors.white)),
                          ),
                        ),
                      ]),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(str(v['name']), style: AppText.sans(size: 16, weight: FontWeight.w600, color: _bluntRed)),
                        Text('${str(v['location'])} • ${str(v['pujaType'])}', style: AppText.sans(size: 14, color: AppColors.gray500)),
                      ]),
                    ),
                  ]),
                ),
              ),
            ],
          ]),
        ),
        const SizedBox(height: 40),
        _RedButton(
          label: str(data['ctaText']),
          onTap: onBook,
          radius: 6,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// TestimonialSection.jsx + GoogleReviews.jsx
// ---------------------------------------------------------------------------

class _TestimonialSection extends ConsumerWidget {
  const _TestimonialSection({required this.data});
  final Json data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (data.isEmpty) return const SizedBox.shrink();
    final reviews = data['reviews'] != null ? objList(data['reviews']) : (ref.watch(_sampleReviews).value ?? const <Json>[]);
    final small = AppText.sans(size: 14, color: AppColors.gray600);
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _sectionTitle(str(data['title']), str(data['subtitle'])),
        _GoogleReviews(reviews: reviews),
        const SizedBox(height: 32),
        Text.rich(
          TextSpan(children: [
            const TextSpan(text: 'Join thousands of blessed families •'),
            TextSpan(text: ' ${str(data['statText'])}', style: small.copyWith(color: _yellow700, fontWeight: FontWeight.w600)),
          ]),
          textAlign: TextAlign.center,
          style: small,
        ),
        const SizedBox(height: 32),
        Text.rich(
          TextSpan(children: [
            const TextSpan(text: 'Check all of our '),
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: GestureDetector(
                onTap: () => openExternal(str(data['googleReviewsLink'])),
                child: Text('Google Reviews',
                    style: small.copyWith(fontWeight: FontWeight.w600, decoration: TextDecoration.underline, decorationColor: AppColors.gray600)),
              ),
            ),
          ]),
          textAlign: TextAlign.center,
          style: small,
        ),
      ]),
    );
  }
}

class _GoogleReviews extends StatelessWidget {
  const _GoogleReviews({required this.reviews});
  final List<Json> reviews;

  static String _initials(String name) =>
      name.split(' ').where((n) => n.isNotEmpty).map((n) => n[0]).join().toUpperCase();

  static String _date(String iso) {
    final d = DateTime.tryParse(iso);
    return d == null ? '' : DateFormat('dd/MM/yyyy').format(d.toLocal());
  }

  static Widget _stars(int rating) => Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < 5; i++)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Icon(i < rating ? Icons.star_rounded : Icons.star_border_rounded, size: 16, color: i < rating ? AppColors.yellow400 : AppColors.gray300),
          ),
      ]);

  static Widget _avatar(String name, double size) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: const BoxDecoration(color: AppColors.blue500, shape: BoxShape.circle),
        child: Text(_initials(name), style: AppText.sans(size: size > 40 ? 16 : 14, weight: FontWeight.w500, color: Colors.white)),
      );

  void _openModal(BuildContext context, Json r) {
    final name = str(obj(r['authorAttribution'])['displayName']);
    showAppDialog(
      context,
      padding: EdgeInsets.zero,
      radius: 8,
      maxWidth: 672,
      showClose: false,
      builder: (ctx) => ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * .8),
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.gray200))),
              child: Row(children: [
                _avatar(name, 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name, style: AppText.sans(size: 16, weight: FontWeight.w500, color: AppColors.gray900)),
                    Text(str(r['relativePublishTimeDescription']), style: AppText.sans(size: 14, color: AppColors.gray500)),
                  ]),
                ),
                IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(LucideIcons.x, size: 20, color: AppColors.gray400)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _stars(intOf(r['rating'])),
                const SizedBox(height: 16),
                Text(str(obj(r['text'])['text']), style: AppText.sans(size: 16, color: AppColors.gray700, height: 1.625)),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.only(top: 16),
                  decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.gray200))),
                  alignment: Alignment.centerRight,
                  child: Text(_date(str(r['publishTime'])), style: AppText.sans(size: 12, color: AppColors.gray400)),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.only(bottom: 8),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.gray200))),
        child: Text('Google Reviews', style: AppText.sans(size: 18, weight: FontWeight.w500, color: AppColors.gray900)),
      ),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final r in reviews) ...[
            Builder(builder: (context) {
              final name = str(obj(r['authorAttribution'])['displayName']);
              final text = str(obj(r['text'])['text']);
              final body = AppText.sans(size: 14, color: AppColors.gray700, height: 1.625);
              return Container(
                width: 320,
                height: 216,
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.gray200),
                  boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 2, offset: Offset(0, 1))],
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    _avatar(name, 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(name, style: AppText.sans(size: 14, weight: FontWeight.w500, color: AppColors.gray900)),
                        Text(str(r['relativePublishTimeDescription']), style: AppText.sans(size: 12, color: AppColors.gray500)),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  _stars(intOf(r['rating'])),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(text: text.length <= 100 ? text : '${text.substring(0, 100)}...'),
                        if (text.length > 100)
                          WidgetSpan(
                            child: GestureDetector(
                              onTap: () => _openModal(context, r),
                              child: Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: Text('Read more', style: body.copyWith(color: AppColors.blue600, fontWeight: FontWeight.w500)),
                              ),
                            ),
                          ),
                      ]),
                      style: body,
                      overflow: TextOverflow.fade,
                    ),
                  ),
                  Row(children: [
                    const Icon(LucideIcons.calendar, size: 12, color: AppColors.gray500),
                    const SizedBox(width: 4),
                    Text('  ${_date(str(r['publishTime']))}', style: AppText.sans(size: 12, color: AppColors.gray500)),
                  ]),
                ]),
              );
            }),
          ],
        ]),
      ),
      const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (var i = 0; i < reviews.length; i++)
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: const BoxDecoration(color: AppColors.gray300, shape: BoxShape.circle),
          ),
      ]),
    ]);
  }
}

// ---------------------------------------------------------------------------
// BookingForm.jsx
// ---------------------------------------------------------------------------

const _pujaTypes = [
  ('griha-pravesh', 'Griha Pravesh (Housewarming)'),
  ('satyanarayan', 'Satyanarayan Puja'),
  ('ganesh', 'Ganesh Puja'),
  ('navgraha', 'Navagraha Puja'),
  ('mahamrityunjaya', 'Mahamrityunjay Jaap'),
  ('office', 'Office/Business Puja'),
  ('lakshmi', 'Lakshmi Puja'),
  ('vastu', 'Vastu Shanti'),
  ('shashtipoorthi', 'Shashtipoorthi'),
  ('other', 'Other (mention in notes)'),
];

class _BookingForm extends StatefulWidget {
  const _BookingForm({required this.data, this.languageSlug});
  final Json data;
  final String? languageSlug;

  @override
  State<_BookingForm> createState() => _BookingFormState();
}

class _BookingFormState extends State<_BookingForm> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _city = TextEditingController();
  final _notes = TextEditingController();
  String? _area;
  String? _language;
  String? _pujaType;
  String _dateSelection = '';
  DateTime? _date;
  bool _antiConfusion = false;
  bool _submitting = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _city.dispose();
    _notes.dispose();
    super.dispose();
  }

  List<String> get _locations => list(widget.data['locations']).map((e) => '$e').toList();

  String get _cityValue => _locations.isNotEmpty ? (_area ?? '') : _city.text;

  bool get _valid =>
      _name.text.isNotEmpty &&
      _phone.text.isNotEmpty &&
      _cityValue.isNotEmpty &&
      _language != null &&
      _pujaType != null &&
      (_dateSelection == 'auspicious' || (_dateSelection == 'manual' && _date != null)) &&
      _antiConfusion;

  void _reset() {
    _name.clear();
    _phone.clear();
    _city.clear();
    _notes.clear();
    _area = null;
    _language = null;
    _pujaType = null;
    _dateSelection = '';
    _date = null;
    _antiConfusion = false;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = await showNativeDatePicker(context, initialDate: _date ?? today, firstDate: today, lastDate: DateTime(now.year + 2));
    if (d != null) setState(() => _date = d);
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    final date = _date == null ? '' : DateFormat('yyyy-MM-dd').format(_date!);
    final form = <String, dynamic>{
      'name': _name.text,
      'phone': _phone.text,
      'city': _cityValue,
      'language': _language ?? '',
      'pujaType': _pujaType ?? '',
      'date': date,
      'dateSelection': _dateSelection,
      'notes': _notes.text,
      'antiConfusion': _antiConfusion,
      'enquiry': 'Language: $_language - Puja Type: $_pujaType - Pooja Selected Date: $date - Enquiry: ${_notes.text}',
    };
    final router = GoRouter.of(context);
    final path = currentPath(context);
    try {
      final payload = createCrmLeadEnquiryBody(form);
      final enquired = str(payload['pooja-enquired']);
      final city = str(payload[crmLeadsFieldMap['city']]);
      final slug = widget.languageSlug;
      await BmpApi.postGlobalLeadCapture({
        ...payload,
        crmLeadsFieldMap['pujaType']!: enquired.isEmpty ? '' : enquired[0].toUpperCase() + enquired.substring(1),
        'source': 'Enquiry Form',
        'webPageLink': '${AppConfig.siteUrl}$path',
        crmLeadsFieldMap['city']!: slug != null && slug.isNotEmpty ? '${slug.toUpperCase()}: $city' : city,
      });
      _reset();
      router.push('/thank-you');
    } catch (_) {
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            content: const Text('Something went wrong. Please try again.'),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _input(TextEditingController c, String hint, {TextInputType? type, int lines = 1}) => TextField(
        controller: c,
        enabled: !_submitting,
        keyboardType: type,
        maxLines: lines,
        minLines: lines,
        onChanged: (_) => setState(() {}),
        style: AppText.sans(size: 16),
        decoration: _decoration(hint),
      );

  InputDecoration _decoration(String hint) {
    final border = OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.gray300));
    return InputDecoration(
      hintText: hint,
      hintStyle: AppText.sans(size: 16, color: AppColors.gray400),
      isDense: true,
      contentPadding: const EdgeInsets.all(12),
      border: border,
      enabledBorder: border,
      disabledBorder: border,
      focusedBorder: border.copyWith(borderSide: const BorderSide(color: _bluntRed, width: 2)),
    );
  }

  Widget _select(String placeholder, String? value, List<(String, String)> options, ValueChanged<String> onChanged) => GestureDetector(
        onTap: _submitting
            ? null
            : () async {
                final v = await showPickerSheet<(String, String)>(
                  context,
                  title: placeholder,
                  options: options,
                  labelOf: (o) => o.$2,
                  selected: options.where((o) => o.$1 == value).firstOrNull,
                );
                if (v != null) setState(() => onChanged(v.$1));
              },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.gray300),
          ),
          child: Row(children: [
            Expanded(
              child: Text(
                value == null ? placeholder : options.firstWhere((o) => o.$1 == value, orElse: () => (value, value)).$2,
                style: AppText.sans(size: 16, color: AppColors.gray900),
              ),
            ),
            const Icon(LucideIcons.chevronDown, size: 16, color: AppColors.gray600),
          ]),
        ),
      );

  Widget _radio(String value, String label) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _submitting
            ? null
            : () {
                setState(() {
                  _dateSelection = value;
                  _date = null;
                });
                if (value == 'manual') Future.delayed(const Duration(milliseconds: 100), _pickDate);
              },
        child: Row(children: [
          Container(
            width: 16,
            height: 16,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _dateSelection == value ? _bluntRed : AppColors.gray300, width: _dateSelection == value ? 5 : 1),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: AppText.sans(size: 16, weight: FontWeight.w500, color: AppColors.gray700))),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final languages = list(d['languages']).map((e) => '$e').toList();
    final langOptions = (languages.isEmpty ? const ['Hindi', 'English'] : languages).map((l) => (l, l)).toList();
    return Container(
      color: _peach,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(strOrNull(d['title']) ?? 'Book Your Puja in 2 Minutes',
            textAlign: TextAlign.center, style: AppText.sans(size: 30, weight: FontWeight.w700, color: _bluntRed, height: 36 / 30)),
        const SizedBox(height: 16),
        Text(strOrNull(d['subtitle']) ?? 'Simple. Fast. Blessed.',
            textAlign: TextAlign.center, style: AppText.sans(size: 18, color: AppColors.gray700)),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 3, offset: Offset(0, 1))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _input(_name, 'Your Name *'),
            const Gap(16),
            _input(_phone, 'Phone (WhatsApp) *', type: TextInputType.phone),
            const Gap(16),
            if (_locations.isNotEmpty)
              _select('Select Your Area *', _area, _locations.map((l) => (l, l)).toList(), (v) => _area = v)
            else
              _input(_city, 'Your City *'),
            const Gap(16),
            _select('Select Language Preference *', _language, langOptions, (v) => _language = v),
            const Gap(16),
            _select('Select Puja Type *', _pujaType, _pujaTypes, (v) => _pujaType = v),
            const Gap(16),
            Text('Do you have a specific date in mind for your puja? *',
                style: AppText.sans(size: 14, weight: FontWeight.w500, color: AppColors.gray700)),
            const Gap(24),
            _radio('manual', '📅 Yes, I want to select a specific date'),
            const Gap(12),
            _radio('auspicious', '🌟 No, I need help finding the most auspicious date'),
            if (_dateSelection == 'manual') ...[
              const Gap(12),
              GestureDetector(
                onTap: _submitting ? null : _pickDate,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.gray300)),
                  child: Row(children: [
                    Expanded(
                      child: Text(_date == null ? 'dd/mm/yyyy' : DateFormat('dd/MM/yyyy').format(_date!),
                          style: AppText.sans(size: 16, color: _date == null ? AppColors.gray400 : AppColors.gray900)),
                    ),
                    const Icon(LucideIcons.calendar, size: 16, color: AppColors.gray600),
                  ]),
                ),
              ),
            ],
            if (_dateSelection == 'auspicious') ...[
              const Gap(12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.green50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _green200),
                ),
                child: Row(children: [
                  const Text('✅', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text("Great choice! We'll suggest the most auspicious dates for your puja.",
                        style: AppText.sans(size: 16, weight: FontWeight.w500, color: AppColors.green700)),
                  ),
                ]),
              ),
            ],
            const Gap(16),
            _input(_notes, 'Additional Information (Optional)', lines: 3),
            const Gap(16),
            GestureDetector(
              onTap: _submitting ? null : () => setState(() => _antiConfusion = !_antiConfusion),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _yellow50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _yellow200),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: _antiConfusion ? _bluntRed : Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: _antiConfusion ? _bluntRed : AppColors.gray300),
                      ),
                      child: _antiConfusion ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('I understand this is an enquiry. A coordinator will call to confirm details.',
                        style: AppText.sans(size: 14, weight: FontWeight.w500, color: AppColors.gray700)),
                  ),
                ]),
              ),
            ),
            const Gap(16),
            Opacity(
              opacity: _submitting || !_valid ? .5 : 1,
              child: Tap(
                onTap: _submitting || !_valid ? null : _submit,
                radius: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: _bluntRed,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 15, offset: Offset(0, 10))],
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    if (_submitting) ...[
                      const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                      const SizedBox(width: 8),
                    ],
                    Text(_submitting ? 'Submitting...' : 'Request a Callback',
                        style: AppText.sans(size: 18, weight: FontWeight.w500, color: Colors.white)),
                  ]),
                ),
              ),
            ),
            const Gap(16),
            Text("We'll call within 2 hours • Transparent and Hassle free packages to choose from",
                textAlign: TextAlign.center, style: AppText.sans(size: 14, color: AppColors.gray600)),
          ]),
        ),
      ]),
    );
  }
}

class _StickyReminderBar extends StatelessWidget {
  const _StickyReminderBar({required this.onBook});
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.paddingOf(context).bottom),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.gray200)),
          boxShadow: [BoxShadow(color: Color(0x1A000000), blurRadius: 6, offset: Offset(0, -2))],
        ),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('Ready to book your puja?', style: AppText.sans(size: 14, weight: FontWeight.w500, color: _bluntRed)),
              Text('2 minutes • Convenient Packages', style: AppText.sans(size: 12, color: AppColors.gray500)),
            ]),
          ),
          Tap(
            onTap: () => callPhone('+919869929292'),
            radius: 6,
            child: Container(
              constraints: const BoxConstraints(minWidth: 80),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: AppColors.blue600, borderRadius: BorderRadius.circular(6)),
              child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(LucideIcons.phone, size: 16, color: Colors.white),
                const SizedBox(width: 4),
                Text('Call', style: AppText.sans(size: 14, weight: FontWeight.w500, color: Colors.white)),
              ]),
            ),
          ),
          const SizedBox(width: 8),
          Tap(
            onTap: onBook,
            radius: 6,
            child: Container(
              constraints: const BoxConstraints(minWidth: 100),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: _bluntRed, borderRadius: BorderRadius.circular(6)),
              child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(LucideIcons.calendar, size: 16, color: Colors.white),
                const SizedBox(width: 8),
                Text('Book', style: AppText.sans(size: 14, weight: FontWeight.w500, color: Colors.white)),
              ]),
            ),
          ),
        ]),
      );
}

// ---------------------------------------------------------------------------
// FAQSection.jsx
// ---------------------------------------------------------------------------

class _FaqSection extends StatefulWidget {
  const _FaqSection({required this.data});
  final Json data;

  @override
  State<_FaqSection> createState() => _FaqSectionState();
}

class _FaqSectionState extends State<_FaqSection> {
  int? _open;

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    if (d.isEmpty) return const SizedBox.shrink();
    final items = objList(d['items']);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _sectionTitle(str(d['title']), str(d['subtitle'])),
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _open = _open == i ? null : i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.gray200))),
                  child: Row(children: [
                    Expanded(
                      child: Text(str(items[i]['question']),
                          style: AppText.sans(size: 16, weight: FontWeight.w500, color: _bluntRed, height: 1.625)),
                    ),
                    Icon(_open == i ? LucideIcons.chevronUp : LucideIcons.chevronDown, size: 20, color: _bluntRed),
                  ]),
                ),
              ),
              if (_open == i)
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 16),
                  child: Text(str(items[i]['answer']), style: AppText.sans(size: 14, color: AppColors.gray600, height: 1.625)),
                ),
            ]),
          ),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// FinalCTA.jsx
// ---------------------------------------------------------------------------

class _FinalCta extends StatelessWidget {
  const _FinalCta({required this.data, required this.onBook});
  final Json data;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();
    const pad = EdgeInsets.symmetric(horizontal: 32, vertical: 16);
    return Container(
      color: _peach,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(children: [
        Text(str(data['title']), textAlign: TextAlign.center, style: AppText.sans(size: 24, weight: FontWeight.w700, color: _bluntRed, height: 1.25)),
        const SizedBox(height: 24),
        Text(str(data['subtitle']), textAlign: TextAlign.center, style: AppText.sans(size: 18, color: AppColors.gray700, height: 1.625)),
        const SizedBox(height: 48),
        Wrap(alignment: WrapAlignment.center, spacing: 16, runSpacing: 16, children: [
          _RedButton(label: str(data['buttonText']), onTap: onBook, padding: pad, fontSize: 18, radius: 6),
          _WaButton(
            label: str(data['whatsappText']),
            icon: false,
            radius: 6,
            fontSize: 18,
            onTap: () => _openAdvisorWhatsApp(context, "Hi! I'm ready to book my puja. Can you help me with the next steps?"),
          ),
        ]),
        const SizedBox(height: 32),
        Wrap(alignment: WrapAlignment.center, spacing: 24, runSpacing: 8, children: [
          for (final f in list(data['features']))
            Row(mainAxisSize: MainAxisSize.min, children: [
              Text('✓', style: AppText.sans(size: 14, color: AppColors.green500)),
              const SizedBox(width: 8),
              Flexible(child: Text('$f', style: AppText.sans(size: 14, color: AppColors.gray600))),
            ]),
        ]),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// CommonComponent/FloatingDirectBookingCTA.jsx
// ---------------------------------------------------------------------------

class _FloatingEdgeCta extends StatefulWidget {
  const _FloatingEdgeCta();

  @override
  State<_FloatingEdgeCta> createState() => _FloatingEdgeCtaState();
}

class _FloatingEdgeCtaState extends State<_FloatingEdgeCta> with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _slide;

  static const _gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.bluntRed, AppColors.orange600, Color(0xFFDC2626)],
  );

  @override
  void initState() {
    super.initState();
    _slide = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) _slide.forward();
    });
  }

  @override
  void dispose() {
    _slide.dispose();
    super.dispose();
  }

  Widget _feature(IconData icon, String label) => Column(children: [
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(color: AppColors.orange50, shape: BoxShape.circle),
          child: Icon(icon, size: 20, color: AppColors.bluntRed),
        ),
        const SizedBox(height: 4),
        Text(label, style: AppText.sans(size: 12, weight: FontWeight.w500, color: AppColors.bluntRed)),
      ]);

  @override
  Widget build(BuildContext context) {
    final slide = Tween(begin: const Offset(1, 0), end: Offset.zero).animate(CurvedAnimation(parent: _slide, curve: Curves.easeOut));
    final panel = _expanded
        ? Container(
            width: 256,
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.horizontal(left: Radius.circular(16)),
              boxShadow: [
                BoxShadow(color: Color(0x4D000000), blurRadius: 60, offset: Offset(0, 20)),
                BoxShadow(color: Color(0x33F97316), blurRadius: 40),
              ],
            ),
            child: Stack(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                const SizedBox(height: 4),
                ShaderMask(
                  shaderCallback: (r) => const LinearGradient(colors: [AppColors.bluntRed, Color(0xFFDC2626)]).createShader(r),
                  child: Text('Pooja Packages', style: AppText.sans(size: 18, weight: FontWeight.w700, color: Colors.white)),
                ),
                const SizedBox(height: 12),
                Text('Book your personalized pooja experience online with ease.',
                    style: AppText.sans(size: 12, color: AppColors.gray600, height: 1.625)),
                const SizedBox(height: 16),
                Tap(
                  onTap: () {
                    setState(() => _expanded = false);
                    context.go('/');
                  },
                  radius: 12,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: _gradient,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 15, offset: Offset(0, 10))],
                    ),
                    child: Text('View All Packages →',
                        textAlign: TextAlign.center, style: AppText.sans(size: 14, weight: FontWeight.w600, color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _feature(LucideIcons.users, 'Expert'),
                  const SizedBox(width: 16),
                  _feature(LucideIcons.calendar, 'Quick'),
                  const SizedBox(width: 16),
                  _feature(LucideIcons.badgeCheck, 'Trusted'),
                ]),
              ]),
              Positioned(
                top: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () => setState(() => _expanded = false),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(color: AppColors.gray100, shape: BoxShape.circle),
                    child: const Icon(LucideIcons.x, size: 16, color: AppColors.gray600),
                  ),
                ),
              ),
            ]),
          )
        : GestureDetector(
            onTap: () => setState(() => _expanded = true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
              decoration: const BoxDecoration(
                gradient: _gradient,
                borderRadius: BorderRadius.horizontal(left: Radius.circular(16)),
                boxShadow: [
                  BoxShadow(color: Color(0x66F97316), blurRadius: 40, offset: Offset(0, 10)),
                  BoxShadow(color: Color(0x4DEF4444), blurRadius: 20),
                ],
              ),
              // writing-mode: vertical-rl
              child: RotatedBox(
                quarterTurns: 1,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('Explore All Packages & Prices', style: AppText.sans(size: 14, weight: FontWeight.w700, color: Colors.white)),
                  const SizedBox(width: 8),
                  const Text('✨', style: TextStyle(fontSize: 14)),
                ]),
              ),
            ),
          );
    return Stack(children: [
      if (_expanded)
        Positioned.fill(
          child: GestureDetector(onTap: () => setState(() => _expanded = false), child: const ColoredBox(color: Color(0x33000000))),
        ),
      Align(alignment: Alignment.centerRight, child: SlideTransition(position: slide, child: panel)),
    ]);
  }
}

// ---------------------------------------------------------------------------
// pages/thank-you/index.jsx and pages/enquiry/thank-you.jsx (identical apart
// from the "Explore More Services" link target).
// ---------------------------------------------------------------------------

class ThankYouPage extends StatelessWidget {
  const ThankYouPage({super.key});

  Widget _step(String n, String title, String body) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.only(top: 4),
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: AppColors.blue100, shape: BoxShape.circle),
            child: Text(n, style: AppText.sans(size: 14, weight: FontWeight.w700, color: AppColors.blue600)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: AppText.sans(size: 16, weight: FontWeight.w600, color: AppColors.gray800)),
              Text(body, style: AppText.sans(size: 14, color: AppColors.gray600)),
            ]),
          ),
        ]),
      );

  Widget _feature(Color bg, Color fg, IconData icon, String title, String body) => Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Icon(icon, size: 32, color: fg),
          ),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center, style: AppText.sans(size: 16, weight: FontWeight.w700, color: AppColors.gray800)),
          const SizedBox(height: 8),
          Text(body, textAlign: TextAlign.center, style: AppText.sans(size: 14, color: AppColors.gray600)),
        ]),
      );

  static const _card = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.all(Radius.circular(12)),
    boxShadow: [BoxShadow(color: Color(0x1A000000), blurRadius: 15, offset: Offset(0, 10))],
  );

  @override
  Widget build(BuildContext context) {
    final h2 = AppText.sans(size: 24, weight: FontWeight.w700, color: _bluntRed, height: 32 / 24);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.orange50, Color(0xFFFEF2F2), _yellow50],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 48),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Thank You! ✅', textAlign: TextAlign.center, style: AppText.sans(size: 30, weight: FontWeight.w700, color: _bluntRed)),
              const SizedBox(height: 16),
              Text('Enquiry Received Successfully!', textAlign: TextAlign.center, style: h2),
              const SizedBox(height: 16),
              Text('This is not a booking confirmation yet***', textAlign: TextAlign.center, style: AppText.sans(size: 16, color: Colors.black)),
              const SizedBox(height: 16),
              Text(
                'We have received your puja enquiry successfully. Our experienced team will contact you shortly to discuss all the details and make the perfect arrangements for your spiritual ceremony.',
                textAlign: TextAlign.center,
                style: AppText.sans(size: 20, color: AppColors.gray700, height: 1.625),
              ),
              const SizedBox(height: 48),
              Container(
                padding: const EdgeInsets.all(32),
                decoration: _card,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    const Icon(LucideIcons.clock, size: 24, color: _bluntRed),
                    const SizedBox(width: 12),
                    Text('What Happens Next?', style: h2),
                  ]),
                  const SizedBox(height: 24),
                  _step('1', 'Our Team is Reviewing Your Requirement',
                      'We are checking the details you submitted to understand exactly what you need.'),
                  _step('2', 'Call Within 30-60 Minutes', 'You will receive a call within 30-60 minutes (9 AM - 9 PM).'),
                  _step('3', 'Finalize Priest & Price on Call', 'We will finalize the priest and pricing during the call.'),
                  const SizedBox(height: 16),
                  Tap(
                    onTap: () => context.go('/'),
                    radius: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(color: _bluntRed, borderRadius: BorderRadius.circular(8)),
                      child: Text('Explore More Services',
                          textAlign: TextAlign.center, style: AppText.sans(size: 16, weight: FontWeight.w600, color: Colors.white)),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(32),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_bluntRed, Color(0xFFA52A2A)]),
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  boxShadow: [BoxShadow(color: Color(0x1A000000), blurRadius: 15, offset: Offset(0, 10))],
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    const Icon(Icons.phone, size: 24, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(child: Text('Need Immediate Help?', style: h2.copyWith(color: Colors.white))),
                  ]),
                  const SizedBox(height: 16),
                  Text(
                    'Want to book instantly or have urgent questions? Talk to our puja experts now and get the best priest & price in minutes.',
                    style: AppText.sans(size: 16, color: Colors.white.o(.9)),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.o(.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.o(.15)),
                    ),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Padding(padding: EdgeInsets.only(top: 2), child: Icon(Icons.check_circle, size: 20, color: Colors.white)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Why call now?', style: AppText.sans(size: 14, weight: FontWeight.w600, color: Colors.white)),
                          const SizedBox(height: 4),
                          Text('✅ Instant availability check\n✅ Quick price confirmation\n✅ Get the priest details immediately',
                              style: AppText.sans(size: 14, color: Colors.white.o(.9), height: 1.625)),
                        ]),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 24),
                  Tap(
                    onTap: () => callPhone('+919869929292'),
                    radius: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 15, offset: Offset(0, 10))],
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.phone, size: 24, color: _bluntRed),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text('Call Now: 9869 92 92 92', style: AppText.sans(size: 18, weight: FontWeight.w700, color: _bluntRed)),
                        ),
                      ]),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 48),
              Container(
                padding: const EdgeInsets.all(32),
                decoration: _card,
                child: Column(children: [
                  Text('Why Thousands Choose Us', textAlign: TextAlign.center, style: h2),
                  const SizedBox(height: 32),
                  _feature(AppColors.green100, AppColors.green500, LucideIcons.dollarSign, 'No Advance Payment',
                      'Book without any upfront costs. Pay only after the puja is completed.'),
                  _feature(AppColors.blue100, AppColors.blue500, LucideIcons.circleCheck, 'Verified Pandits',
                      'All our pandits are experienced, verified, and trained in traditional rituals.'),
                  _feature(_purple100, _purple500, LucideIcons.zap, 'Quick Response',
                      'Fast booking process with same-day availability for urgent requirements.'),
                ]),
              ),
              const SizedBox(height: 48),
              Tap(
                onTap: () => context.canPop() ? context.pop() : context.go('/'),
                radius: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  decoration: BoxDecoration(color: AppColors.gray100, borderRadius: BorderRadius.circular(8)),
                  child: Text('← Go Back', textAlign: TextAlign.center, style: AppText.sans(size: 16, weight: FontWeight.w600, color: AppColors.gray700)),
                ),
              ),
              const SizedBox(height: 16),
              Tap(
                onTap: () => context.go('/'),
                radius: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  decoration: BoxDecoration(color: _bluntRed, borderRadius: BorderRadius.circular(8)),
                  child: Text('Return to Home', textAlign: TextAlign.center, style: AppText.sans(size: 16, weight: FontWeight.w600, color: Colors.white)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
