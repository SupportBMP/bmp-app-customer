import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/json.dart';
import '../../core/utils/launch.dart';
import '../../core/utils/nav.dart';
import '../../core/widgets/brand_icons.dart';
import '../../core/widgets/lucide_by_name.dart';
import '../../core/widgets/site_image.dart';
import '../../core/widgets/native.dart';
import '../../core/widgets/ui.dart';
import '../festival/festival_widgets.dart';
import '../festival/ornaments.dart';

const _container = EdgeInsets.symmetric(horizontal: 32);

/// Fired by the hero's language tap; the self-booking widget listens
/// (the website's `select-language` CustomEvent).
final selectLanguageSignal = ValueNotifier<String?>(null);

// ---------------------------------------------------------------------------
// HeroSection.jsx (mobile)
// ---------------------------------------------------------------------------

class HeroSection extends StatelessWidget {
  const HeroSection({super.key, required this.heroData, required this.experience});
  final Json heroData;
  final Json? experience;

  static const _langMap = {'Marwari': 'Hindi'};

  void _scrollToBooking(BuildContext context, String? lang) {
    final mapped = lang == null ? null : (_langMap[lang] ?? lang);
    if (mapped != null) selectLanguageSignal.value = mapped;
    SectionAnchors.maybeOf(context)?.scrollTo('self-booking');
  }

  @override
  Widget build(BuildContext context) {
    final headline = strOrNull(heroData['headline']) ?? 'Worried About Doing the Puja Right?';
    final highlight = strOrNull(heroData['headlineHighlight']) ?? 'Let Us Handle Everything';
    final sub = strOrNull(heroData['subheadline']) ??
        'Book experienced pandits for personalized home pujas across major Indian cities and online personalized pujas for overseas Indians.';
    final features = list(heroData['features']).map((e) => '$e').toList();
    final cta = obj(heroData['cta']);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.heroFrom, AppColors.background, AppColors.heroTo],
        ),
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          FestivalHeroDecor(experience: experience),
          Positioned.fill(
            child: OverflowBox(
              maxWidth: 900,
              maxHeight: 900,
              child: MandalaWatermark(size: 900, color: AppColors.primary, opacity: .07),
            ),
          ),
          Padding(
            padding: _container.copyWith(top: 32, bottom: 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FestivalHeroBadge(experience: experience),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.gold.o(.15),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppColors.gold.o(.3)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.star_rounded, size: 15, color: AppColors.gold),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        strOrNull(heroData['trustBadge']) ?? 'Trusted by 10,000+ families',
                        style: AppText.sans(size: 14, weight: FontWeight.w600, color: Colors.black),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 24),
                Text.rich(
                  TextSpan(children: [
                    TextSpan(text: '$headline '),
                    TextSpan(text: highlight, style: const TextStyle(color: AppColors.primary)),
                    const TextSpan(text: ' – the '),
                    TextSpan(
                      text: 'Right Way.',
                      style: AppText.heading(size: 30, color: AppColors.saffron, style: FontStyle.italic),
                    ),
                  ]),
                  style: AppText.heading(size: 30, letterSpacing: -.75),
                ),
                const SizedBox(height: 24),
                _RotatingPanditLanguage(onSelect: (l) => _scrollToBooking(context, l)),
                const SizedBox(height: 24),
                Text(sub, style: AppText.sans(size: 18, color: AppColors.mutedForeground, height: 1.6)),
                const SizedBox(height: 24),
                for (final f in features.isEmpty
                    ? const [
                        'Certified & Experienced Pandits (All Languages)',
                        'Personalised Home Pujas Across Major Indian Cities',
                        'Online Personalised Pujas for Overseas Indians',
                      ]
                    : features) ...[
                  CheckLine(f),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 8),
                Center(
                  child: AppButton(
                    size: BtnSize.lg,
                    height: 52,
                    label: strOrNull(cta['book']) ?? 'Book Your Puja →',
                    textStyle: AppText.sans(size: 16, weight: FontWeight.w500),
                    onPressed: () => SectionAnchors.maybeOf(context)?.scrollTo('self-booking'),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: AppButton(
                    size: BtnSize.lg,
                    height: 52,
                    variant: BtnVariant.outline,
                    borderColor: AppColors.gold.o(.6),
                    borderWidth: 2,
                    foreground: Colors.black,
                    icon: LucideIcons.phoneCall,
                    label: strOrNull(cta['callback']) ?? 'Request a Callback',
                    textStyle: AppText.sans(size: 14, weight: FontWeight.w500),
                    onPressed: () => SectionAnchors.maybeOf(context)?.scrollTo('enquiry'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RotatingPanditLanguage extends StatefulWidget {
  const _RotatingPanditLanguage({required this.onSelect});
  final ValueChanged<String> onSelect;

  @override
  State<_RotatingPanditLanguage> createState() => _RotatingPanditLanguageState();
}

class _RotatingPanditLanguageState extends State<_RotatingPanditLanguage> {
  static const _pandits = [
    ('Hindi', 'हिंदी पंडित'),
    ('Kannada', 'ಕನ್ನಡ ಪುರೋಹಿತರು'),
    ('Telugu', 'తెలుగు పురోహితులు'),
    ('Tamil', 'தமிழ் புரோகிதர்'),
    ('Malayalam', 'മലയാളം പൂജാരി'),
    ('Marathi', 'मराठी गुरुजी'),
    ('Gujarati', 'ગુજરાતી મહારાજ'),
    ('Bengali', 'বাংলা পুরোহিত'),
    ('Odia', 'ଓଡ଼ିଆ ପଣ୍ଡିତ'),
    ('Marwari', 'मारवाड़ी पंडित'),
  ];
  int _i = 0;
  late final Timer _t = Timer.periodic(const Duration(milliseconds: 1500), (_) {
    if (mounted) setState(() => _i = (_i + 1) % _pandits.length);
  });

  @override
  void initState() {
    super.initState();
    _t;
  }

  @override
  void dispose() {
    _t.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cur = _pandits[_i];
    return GestureDetector(
      onTap: () => widget.onSelect(cur.$1),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (child, a) => FadeTransition(
            opacity: a,
            child: SlideTransition(position: Tween(begin: const Offset(0, .1), end: Offset.zero).animate(a), child: child),
          ),
          child: Text(
            cur.$2,
            key: ValueKey(cur.$1),
            style: AppText.body(size: 24, weight: FontWeight.w600, color: AppColors.primary),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// OurPromiseStrip.jsx
// ---------------------------------------------------------------------------

class OurPromiseStrip extends StatelessWidget {
  const OurPromiseStrip({super.key, required this.data, this.topPadding = 80});
  final Json data;

  /// On the homepage the hero is shifted down 80px (`relative top-20`) and
  /// covers this strip's top padding, so the visible padding is 0.
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    final items = objList(data['items']);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.secondary,
        border: Border.symmetric(horizontal: BorderSide(color: AppColors.primary.o(.05))),
      ),
      padding: _container.copyWith(top: topPadding, bottom: 80),
      child: Column(children: [
        HighlightHeading(title: str(data['title'], 'Our'), highlight: str(data['highlight'], 'Promise'), size: 24),
        const SizedBox(height: 24),
        LayoutBuilder(builder: (context, c) {
          final w = (c.maxWidth - 2 * 8) / 3;
          return Wrap(
            spacing: 8,
            runSpacing: 20,
            children: [
              for (final item in items)
                SizedBox(
                  width: w,
                  child: Column(children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.o(.05),
                        border: Border.all(color: AppColors.primary.o(.3), width: 2),
                      ),
                      child: Icon(lucideByName(str(item['icon'])), size: 20, color: AppColors.primary),
                    ),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 90),
                      child: Text(
                        str(item['label']),
                        textAlign: TextAlign.center,
                        style: AppText.sans(size: 12, weight: FontWeight.w600, height: 1.25),
                      ),
                    ),
                  ]),
                ),
            ],
          );
        }),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// SelfBookingSection.jsx (shown below `lg`)
// ---------------------------------------------------------------------------

const instaLanguages = ['Hindi', 'Kannada', 'Telugu', 'Tamil', 'Marathi', 'Malayalam', 'Gujarati', 'Bengali', 'Odia'];
const instaCities = ['Bangalore', 'Mumbai', 'Pune', 'Hyderabad', 'Delhi', 'Chennai'];

class SelfBookingSection extends StatefulWidget {
  const SelfBookingSection({super.key, required this.data});
  final Json data;

  @override
  State<SelfBookingSection> createState() => _SelfBookingSectionState();
}

class _SelfBookingSectionState extends State<SelfBookingSection> {
  String? _lang;
  String? _city;

  @override
  void initState() {
    super.initState();
    selectLanguageSignal.addListener(_onSignal);
  }

  void _onSignal() {
    final l = selectLanguageSignal.value;
    if (l != null && instaLanguages.contains(l)) setState(() => _lang = l);
  }

  @override
  void dispose() {
    selectLanguageSignal.removeListener(_onSignal);
    super.dispose();
  }

  Future<void> _pick({required bool language}) async {
    final options = language ? instaLanguages : [...instaCities, 'E-Pooja'];
    final v = await showNativePicker<String>(
      context,
      title: language ? 'Preferred priest language' : 'Where should the puja happen?',
      options: options,
      labelOf: (o) => o == 'E-Pooja' ? '🌐 E-Pooja (Virtual)' : o,
      selected: language ? _lang : _city,
      message: language ? null : '🌐 E-Pooja — Live or Recorded, for international users',
    );
    if (v != null) setState(() => language ? _lang = v : _city = v);
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final title = str(d['title']);
    final highlight = str(d['highlight']);
    final steps = objList(d['steps']);
    final isVirtual = _city == 'E-Pooja';
    final url = _lang != null && _city != null
        ? isVirtual
            ? '/${_lang!.toLowerCase()}/e-pooja/pooja'
            : '/${_lang!.toLowerCase()}/${_city!.toLowerCase()}/pooja'
        : null;

    Widget selector({required String label, required String? value, required String placeholder, required bool language}) {
      return GestureDetector(
        onTap: () => _pick(language: language),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: value != null ? AppColors.primary : AppColors.border.o(.6)),
            boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 6, offset: Offset(0, 4), spreadRadius: -1)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppText.body(size: 12, weight: FontWeight.w500, color: AppColors.mutedForeground)),
              const SizedBox(height: 4),
              Row(children: [
                Expanded(
                  child: Text(
                    value == 'E-Pooja' ? '🌐 E-Pooja (Virtual)' : (value ?? placeholder),
                    style: AppText.body(
                      size: 16,
                      weight: FontWeight.w600,
                      color: value != null ? AppColors.primary : AppColors.foreground.o(.5),
                    ),
                  ),
                ),
                const Icon(LucideIcons.chevronDown, size: 20, color: AppColors.mutedForeground),
              ]),
            ],
          ),
        ),
      );
    }

    final parts = highlight.isEmpty ? [title, ''] : title.split(highlight);
    return Anchor(
      'self-booking',
      child: Container(
        color: AppColors.secondary,
        padding: _container.copyWith(top: 40, bottom: 40),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: AppColors.primary.o(.1), borderRadius: BorderRadius.circular(999)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(LucideIcons.zap, size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Text('Insta Book', style: AppText.body(size: 14, weight: FontWeight.w600, color: AppColors.primary)),
              ]),
            ),
            const SizedBox(height: 12),
            Text.rich(
              TextSpan(children: [
                TextSpan(text: '${parts.first} '),
                TextSpan(text: highlight, style: const TextStyle(color: AppColors.primary)),
                TextSpan(text: ' ${parts.length > 1 ? parts[1] : ''}'),
              ]),
              textAlign: TextAlign.center,
              style: AppText.heading(size: 30),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < steps.length; i++) ...[
                    Row(children: [
                      Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.primary, width: 2)),
                        child: Text(str(steps[i]['num']),
                            style: AppText.body(size: 14, weight: FontWeight.w700, color: AppColors.primary)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(str(steps[i]['label']), style: AppText.body(size: 14, weight: FontWeight.w500)),
                          Text(str(steps[i]['hint']), style: AppText.body(size: 12, color: AppColors.mutedForeground)),
                        ]),
                      ),
                    ]),
                    if (i < steps.length - 1)
                      Container(
                        margin: const EdgeInsets.only(left: 15),
                        height: 16,
                        child: CustomPaint(painter: _DashedVLine(AppColors.primary.o(.25))),
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16 + 32),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
                boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 2, offset: Offset(0, 1))],
              ),
              child: Column(
                children: [
                  selector(
                    label: strOrNull(d['languageLabel']) ?? 'I prefer a priest who speaks',
                    value: _lang,
                    placeholder: 'Select language',
                    language: true,
                  ),
                  const SizedBox(height: 16),
                  selector(
                    label: strOrNull(d['cityLabel']) ?? 'Pooja to be performed in',
                    value: _city,
                    placeholder: 'Select city',
                    language: false,
                  ),
                  if (_lang != null && _city != null) ...[
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.o(.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary.o(.2)),
                      ),
                      child: Text.rich(
                        TextSpan(
                          children: isVirtual
                              ? [
                                  const TextSpan(text: 'Virtual pooja with a '),
                                  TextSpan(text: _lang, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)),
                                  const TextSpan(text: '-speaking priest'),
                                ]
                              : [
                                  TextSpan(text: _lang, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)),
                                  const TextSpan(text: '-speaking priest in '),
                                  TextSpan(text: _city, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)),
                                ],
                        ),
                        textAlign: TextAlign.center,
                        style: AppText.body(size: 14, weight: FontWeight.w500),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Text(
                    strOrNull(d['reassurance']) ?? 'Priest details & home prep list sent within 24 hrs · Partial payment accepted',
                    textAlign: TextAlign.center,
                    style: AppText.body(size: 14, color: AppColors.mutedForeground),
                  ),
                  const SizedBox(height: 24),
                  AppButton(
                    expand: true,
                    height: 52,
                    radius: 12,
                    textStyle: AppText.body(size: 18, weight: FontWeight.w600),
                    label: url != null
                        ? (strOrNull(d['buttonText']) ?? 'Browse Puja Packages')
                        : (strOrNull(d['disabledButtonText']) ?? 'Select language & city first'),
                    trailingIcon: url != null ? LucideIcons.arrowRight : null,
                    onPressed: url == null ? null : () => context.push(url),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedVLine extends CustomPainter {
  _DashedVLine(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 2;
    for (double y = 0; y < size.height; y += 6) {
      canvas.drawLine(Offset(1, y), Offset(1, math.min(y + 3, size.height)), p);
    }
  }

  @override
  bool shouldRepaint(covariant _DashedVLine old) => old.color != color;
}

// ---------------------------------------------------------------------------
// CategoriesSection.jsx
// ---------------------------------------------------------------------------

class CategoriesSection extends StatelessWidget {
  const CategoriesSection({super.key, required this.categories, required this.data});
  final List<Json> categories;
  final Json data;

  @override
  Widget build(BuildContext context) {
    final title = str(data['title']);
    final highlight = str(data['highlight']);
    final parts = highlight.isEmpty ? [title, ''] : title.split(highlight);
    return Anchor(
      'categories',
      child: Padding(
        padding: _container.copyWith(top: 24, bottom: 24),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const _SpinningMandala(),
                const SizedBox(width: 8),
                Flexible(
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(text: '${parts.first} '),
                      TextSpan(text: highlight, style: const TextStyle(color: AppColors.primary)),
                      TextSpan(text: ' ${parts.length > 1 ? parts[1] : ''}'),
                    ]),
                    textAlign: TextAlign.center,
                    style: AppText.heading(size: 24),
                  ),
                ),
                const SizedBox(width: 8),
                const _SpinningMandala(),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${strOrNull(data['subtitleMobile']) ?? 'Tap'} a category to explore pujas',
              textAlign: TextAlign.center,
              style: AppText.body(size: 14, color: AppColors.mutedForeground),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(builder: (context, c) {
              final w = (c.maxWidth - 16) / 2;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final cat in categories) SizedBox(width: w, child: _CategoryCard(cat: cat)),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _SpinningMandala extends StatefulWidget {
  const _SpinningMandala();
  @override
  State<_SpinningMandala> createState() => _SpinningMandalaState();
}

class _SpinningMandalaState extends State<_SpinningMandala> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      RepaintBoundary(child: RotationTransition(turns: _c, child: const MandalaWatermark(size: 24, color: AppColors.primary)));
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.cat});
  final Json cat;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // The website reads `locationName`/`languageName` cookies that are never
      // set, so category cards always open the Hindi / Bangalore listing.
      onTap: () {
        final slug = strOrNull(cat['slug']);
        if (slug != null) context.push('/hindi/bangalore/category/$slug');
      },
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary.o(.1), width: 2),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              SiteImage(strOrNull(cat['imageLink'])),
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(12, 40, 12, 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black.o(.7), Colors.black.o(.3), Colors.transparent],
                    ),
                  ),
                  child: Text(
                    str(cat['subCategoryName']),
                    textAlign: TextAlign.center,
                    style: AppText.body(size: 14, weight: FontWeight.w700, color: Colors.white).copyWith(
                      shadows: const [Shadow(color: Color(0x40000000), blurRadius: 4, offset: Offset(0, 2))],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// CredibilityStrip.jsx
// ---------------------------------------------------------------------------

class CredibilityStrip extends StatelessWidget {
  const CredibilityStrip({super.key, required this.label, required this.items});
  final String label;
  final List<Json> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.secondary.o(.5),
        border: Border.symmetric(horizontal: BorderSide(color: AppColors.primary.o(.05))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
      child: Column(
        children: [
          Opacity(
            opacity: .7,
            child: Text(label.toUpperCase(),
                style: AppText.sans(size: 14, weight: FontWeight.w600, color: AppColors.mutedForeground, letterSpacing: 2.8)),
          ),
          const SizedBox(height: 24),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 24,
            runSpacing: 24,
            children: [
              for (final item in items)
                GestureDetector(
                  onTap: strOrNull(item['url']) == null ? null : () => openExternal(str(item['url'])),
                  child: Container(
                    width: 128,
                    height: 64,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black.o(.03)),
                      boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 2, offset: Offset(0, 1))],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: SiteImage(str(item['logo']), fit: BoxFit.contain, placeholderColor: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// NeedHelpStrip.jsx
// ---------------------------------------------------------------------------

class NeedHelpStrip extends StatelessWidget {
  const NeedHelpStrip({super.key, required this.data});
  final Json data;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primary,
      width: double.infinity,
      padding: _container.copyWith(top: 24, bottom: 24),
      child: Column(
        children: [
          Text(str(data['title']),
              textAlign: TextAlign.center, style: AppText.sans(size: 20, weight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 4),
          Opacity(
            opacity: .9,
            child: Text(str(data['subtitle']), textAlign: TextAlign.center, style: AppText.body(color: Colors.white)),
          ),
          const SizedBox(height: 16),
          AppButton(
            variant: BtnVariant.secondary,
            size: BtnSize.lg,
            height: 48,
            icon: LucideIcons.phone,
            label: str(data['callButton']),
            textStyle: AppText.body(size: 14, weight: FontWeight.w600),
            onPressed: () => goHref(context, str(data['callHref'])),
          ),
          const SizedBox(height: 12),
          AppButton(
            size: BtnSize.lg,
            height: 48,
            background: AppColors.whatsapp,
            textStyle: AppText.body(size: 14, weight: FontWeight.w600),
            onPressed: () => openExternal(str(data['whatsappHref'])),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const WhatsAppIcon(size: 20),
              const SizedBox(width: 8),
              Text(str(data['whatsappButton'])),
            ]),
          ),
        ],
      ),
    );
  }
}
