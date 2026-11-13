import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/json.dart';
import '../../core/utils/launch.dart';
import '../../core/utils/nav.dart';
import '../../core/widgets/brand_icons.dart';
import '../../core/widgets/site_image.dart';
import '../../core/widgets/ui.dart';
import '../festival/ornaments.dart';

const _container = EdgeInsets.symmetric(horizontal: 32);

IconData _statIcon(String? name) => switch (name) {
      'Trophy' => LucideIcons.trophy,
      'Users' => LucideIcons.users,
      'BookOpen' => LucideIcons.bookOpen,
      'MapPin' => LucideIcons.mapPin,
      'Package' => LucideIcons.package,
      'Globe' => LucideIcons.globe,
      'IndianRupee' => LucideIcons.indianRupee,
      _ => LucideIcons.circleCheck,
    };

/// `Title <highlight> rest` built with the website's `title.split(highlight)`.
Widget splitHeading(String title, String highlight, {double size = 30, Color highlightColor = AppColors.primary, FontStyle? highlightStyle, Color color = AppColors.foreground}) {
  final parts = highlight.isEmpty ? [title, ''] : title.split(highlight);
  return Text.rich(
    TextSpan(children: [
      TextSpan(text: '${parts.first} '),
      TextSpan(text: highlight, style: TextStyle(color: highlightColor, fontStyle: highlightStyle)),
      TextSpan(text: ' ${parts.length > 1 ? parts[1] : ''}'),
    ]),
    textAlign: TextAlign.center,
    style: AppText.heading(size: size, color: color),
  );
}

// ---------------------------------------------------------------------------
// TrustSection.jsx
// ---------------------------------------------------------------------------

const _defaultTestimonials = <Json>[
  {
    'name': 'places/ChIJuU73SL0RrjsRMNDzSXUagjk/reviews/Ci9DQUlRQUNvZENodHljRjlvT2tkak5GSkdNMTlWY20xTE1ESkZSMVpWU0hwT1gyYxAB',
    'relativePublishTimeDescription': 'a month ago',
    'rating': 5,
    'text': {
      'text':
          'Namaste, We did pooja today at our Palakkad, Kerala home. It was done in a really devotional, calm and peaceful way. We are very happy with the pooja performed. Thanking team BookMyPooja for your timely support. Truly appreciated. 🙏🙏',
    },
    'authorAttribution': {'displayName': 'Sreeja S', 'photoUri': ''},
    'googleMapsUri':
        'https://www.google.com/maps/reviews/data=!4m6!14m5!1m4!2m3!1sCi9DQUlRQUNvZENodHljRjlvT2tkak5GSkdNMTlWY20xTE1ESkZSMVpWU0hwT1gyYxAB!2m1!1s0x3bae11bd48f74eb9:0x39821a7549f3d030',
  },
  {
    'rating': 5,
    'text': {
      'text':
          "Extremely professional service. The Pandit ji arrived on time and explained every mantra's significance during our Griha Pravesh. The samagri was of high quality and very well-packed.",
    },
    'authorAttribution': {'displayName': 'Anjali Sharma', 'photoUri': 'https://api.dicebear.com/7.x/avataaars/svg?seed=Anjali'},
  },
  {
    'rating': 5,
    'text': {
      'text':
          'The easiest way to book a puja. I was worried about finding a Marathi-speaking pandit in Delhi, but BookMyPooja made it happen seamlessly. The platform is truly a lifesaver.',
    },
    'authorAttribution': {'displayName': 'Vikram Mehta', 'photoUri': ''},
    'googleMapsUri':
        'https://www.google.com/maps/place/Book+My+Pooja/@12.9716,77.5946,17z/data=!4m8!3m7!1s0x3bae11bd48f74eb9:0x39821a7549f3d030!8m2!3d12.9841872!4d77.7288636!9m1!1b1!16s%2Fg%2F11f_6w0y7v?entry=ttu',
  },
];

class TrustSection extends StatelessWidget {
  const TrustSection({super.key, required this.testimonials, required this.data});
  final List<Json> testimonials;
  final Json data;

  @override
  Widget build(BuildContext context) {
    final stats = objList(data['stats']);
    final reviews = testimonials.isNotEmpty ? testimonials : _defaultTestimonials;
    final cta = obj(data['googleReviewsCta']);
    final cardWidth = (MediaQuery.sizeOf(context).width * .85).clamp(280.0, double.infinity);

    return Anchor(
      'testimonials',
      child: Container(
        color: AppColors.secondary,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            const Positioned(left: -128, top: 40, child: MandalaWatermark(size: 500, color: AppColors.primary, opacity: .03)),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Padding(
                    padding: _container,
                    child: Column(children: [
                      splitHeading(str(data['title']), str(data['highlight'])),
                      const SizedBox(height: 12),
                      Text(str(data['subtitle']),
                          textAlign: TextAlign.center, style: AppText.sans(size: 18, color: AppColors.mutedForeground)),
                      const SizedBox(height: 16),
                      Text(str(data['description']),
                          textAlign: TextAlign.center, style: AppText.sans(size: 14, color: AppColors.mutedForeground)),
                      const SizedBox(height: 24),
                    ]),
                  ),
                  _Marquee(
                    children: [
                      for (var i = 0; i < stats.length * 2; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            if (i > 0)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Text('•', style: AppText.body(color: AppColors.border)),
                              ),
                            Icon(_statIcon(str(stats[i % stats.length]['iconName'])), size: 16, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Text(
                              strOrNull(stats[i % stats.length]['label']) ?? str(stats[i % stats.length]['metric']),
                              style: AppText.sans(size: 14, weight: FontWeight.w600),
                            ),
                          ]),
                        ),
                    ],
                  ),
                  const SizedBox(height: 56 + 64),
                  Padding(
                    padding: _container,
                    child: Text(
                      strOrNull(data['reviewsTitle']) ?? 'What Families Say About Us',
                      textAlign: TextAlign.center,
                      style: AppText.heading(size: 24),
                    ),
                  ),
                  const SizedBox(height: 40),
                  _AutoScrollRow(
                    padding: _container,
                    gap: 24,
                    children: [
                      for (final r in reviews) SizedBox(width: cardWidth, child: _ReviewCard(review: r, data: data)),
                      SizedBox(
                        width: cardWidth,
                        child: GestureDetector(
                          onTap: () => openExternal(
                            'https://www.google.com/maps/place/Book+My+Pooja/@12.9841872,77.7262887,17z/data=!4m8!3m7!1s0x3bae11bd48f74eb9:0x39821a7549f3d030!8m2!3d12.9841872!4d77.7288636!9m1!1b1!16s%2Fg%2F11f_6w0y7v?entry=ttu',
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: AppColors.primary.o(.05),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.primary.o(.1)),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 64,
                                  height: 64,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppColors.background,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppColors.primary.o(.1)),
                                  ),
                                  child: const GoogleIcon(size: 32),
                                ),
                                const SizedBox(height: 24),
                                Text(str(cta['title']),
                                    textAlign: TextAlign.center, style: AppText.heading(size: 20, weight: FontWeight.w600)),
                                const SizedBox(height: 12),
                                Text(str(cta['subtitle']),
                                    textAlign: TextAlign.center, style: AppText.sans(size: 14, color: AppColors.mutedForeground)),
                                const SizedBox(height: 24),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(5, (_) => const Icon(Icons.star_rounded, size: 22, color: AppColors.gold)),
                                ),
                                const SizedBox(height: 24),
                                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                  Text(str(cta['buttonText']).toUpperCase(),
                                      style: AppText.body(size: 12, weight: FontWeight.w700, color: AppColors.primary, letterSpacing: .6)),
                                  const SizedBox(width: 8),
                                  const Icon(LucideIcons.arrowRight, size: 16, color: AppColors.primary),
                                ]),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
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

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review, required this.data});
  final Json review;
  final Json data;

  @override
  Widget build(BuildContext context) {
    final author = obj(review['authorAttribution']);
    final name = strOrNull(author['displayName']) ?? str(review['name']);
    final text = review['text'] is Map ? str(review['text']['text']) : str(review['text']);
    final photo = strOrNull(author['photoUri']) ??
        strOrNull(review['photo']) ??
        'https://api.dicebear.com/7.x/avataaars/svg?seed=${Uri.encodeComponent(name)}';
    final rating = intOf(review['rating']);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.o(.1)),
        boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 2, offset: Offset(0, 1))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            for (var s = 0; s < 5; s++)
              Padding(
                padding: const EdgeInsets.only(right: 2),
                child: s < rating
                    ? const Icon(Icons.star_rounded, size: 17, color: AppColors.gold)
                    : const Icon(LucideIcons.star, size: 16, color: AppColors.border),
              ),
          ]),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 88),
            child: Text(
              text,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: AppText.sans(size: 15, color: AppColors.mutedForeground, height: 1.6, style: FontStyle.italic),
            ),
          ),
          if (strOrNull(review['googleMapsUri']) != null) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => openExternal(str(review['googleMapsUri'])),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text((strOrNull(data['viewGoogleReview']) ?? 'View Review on Google').toUpperCase(),
                    style: AppText.body(size: 10, weight: FontWeight.w700, color: AppColors.primary, letterSpacing: .5)),
                const SizedBox(width: 4),
                const Icon(LucideIcons.externalLink, size: 10, color: AppColors.primary),
              ]),
            ),
          ],
          const Spacer(),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.only(top: 16),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.primary.o(.05)))),
            child: Row(children: [
              Container(
                width: 36,
                height: 36,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.o(.05),
                  border: Border.all(color: AppColors.primary.o(.1)),
                ),
                child: SiteImage(photo, placeholderColor: Colors.transparent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.sans(size: 14, weight: FontWeight.w700)),
                  if (strOrNull(review['relativePublishTimeDescription']) != null)
                    Text(str(review['relativePublishTimeDescription']),
                        style: AppText.sans(size: 10, color: AppColors.mutedForeground)),
                ]),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

/// `animate-marquee` — 30s linear loop over a duplicated row.
class _Marquee extends StatefulWidget {
  const _Marquee({required this.children});
  final List<Widget> children;

  @override
  State<_Marquee> createState() => _MarqueeState();
}

class _MarqueeState extends State<_Marquee> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  final _key = GlobalKey();
  double _width = 0;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 30))..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final box = _key.currentContext?.findRenderObject() as RenderBox?;
      if (box != null && mounted) setState(() => _width = box.size.width);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Repaints every frame; the boundary keeps that from repainting the
    // whole section around it while the page scrolls.
    return RepaintBoundary(
      child: ClipRect(
        child: SizedBox(
          height: 24,
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, child) => OverflowBox(
              alignment: Alignment.centerLeft,
              maxWidth: double.infinity,
              child: Transform.translate(offset: Offset(-_width / 2 * _c.value, 0), child: child),
            ),
            child: Row(key: _key, mainAxisSize: MainAxisSize.min, children: widget.children),
          ),
        ),
      ),
    );
  }
}

/// The reviews row: 25 px/s ping-pong auto-scroll that pauses while touched.
class _AutoScrollRow extends StatefulWidget {
  const _AutoScrollRow({required this.children, required this.padding, required this.gap});
  final List<Widget> children;
  final EdgeInsets padding;
  final double gap;

  @override
  State<_AutoScrollRow> createState() => _AutoScrollRowState();
}

class _AutoScrollRowState extends State<_AutoScrollRow> with SingleTickerProviderStateMixin {
  final _scroll = ScrollController();
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  bool _paused = false;
  bool _reverse = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  void _tick(Duration now) {
    final dt = (now - _last).inMicroseconds / 1e6;
    _last = now;
    if (_paused || !_scroll.hasClients) return;
    final pos = _scroll.position;
    var x = pos.pixels + (_reverse ? -25 : 25) * dt;
    if (x >= pos.maxScrollExtent - 2) _reverse = true;
    if (x <= 2) _reverse = false;
    x = x.clamp(0, pos.maxScrollExtent);
    _scroll.jumpTo(x);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _paused = true,
      onPointerUp: (_) => _paused = false,
      onPointerCancel: (_) => _paused = false,
      child: SingleChildScrollView(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        padding: widget.padding.copyWith(bottom: 24),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < widget.children.length; i++) ...[
                if (i > 0) SizedBox(width: widget.gap),
                widget.children[i],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// FeaturedPriestsSection.jsx
// ---------------------------------------------------------------------------

class FeaturedPriestsSection extends StatelessWidget {
  const FeaturedPriestsSection({super.key, required this.data});
  final Json data;

  @override
  Widget build(BuildContext context) {
    final priests = objList(data['priests']);
    final note = str(data['footerNote']);
    final noteParts = note.split('FAQs');
    final itemWidth = (MediaQuery.sizeOf(context).width - 64) * .7;

    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        const Positioned(right: -128, top: 0, child: MandalaWatermark(size: 400, color: AppColors.primary, opacity: .03)),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Column(
            children: [
              Padding(
                padding: _container,
                child: Column(children: [
                  splitHeading(str(data['title']), str(data['highlight']), size: 24),
                  const SizedBox(height: 8),
                  Text(str(data['subtitle']),
                      textAlign: TextAlign.center, style: AppText.sans(size: 14, color: AppColors.mutedForeground)),
                ]),
              ),
              const SizedBox(height: 24),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: _container,
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < priests.length; i++)
                        Padding(
                          padding: EdgeInsets.only(left: i == 0 ? 0 : 12),
                          child: SizedBox(width: itemWidth, child: _PriestCard(priest: priests[i])),
                        ),
                    ],
                  ),
                ),
              ),
              if (note.isNotEmpty) ...[
                const SizedBox(height: 20),
                Padding(
                  padding: _container,
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(text: noteParts.first),
                      if (noteParts.length > 1) ...[
                        WidgetSpan(
                          alignment: PlaceholderAlignment.baseline,
                          baseline: TextBaseline.alphabetic,
                          child: GestureDetector(
                            onTap: () => SectionAnchors.maybeOf(context)?.scrollTo('faq'),
                            child: Text('FAQs',
                                style: AppText.sans(size: 12, weight: FontWeight.w600, color: AppColors.primary, decoration: TextDecoration.underline)),
                          ),
                        ),
                        TextSpan(text: noteParts[1]),
                      ],
                    ]),
                    textAlign: TextAlign.center,
                    style: AppText.sans(size: 12, color: AppColors.mutedForeground, height: 1.6),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PriestCard extends StatelessWidget {
  const _PriestCard({required this.priest});
  final Json priest;

  @override
  Widget build(BuildContext context) {
    final langs = list(priest['languages']).map((e) => '$e').join(', ');
    return Container(
      constraints: const BoxConstraints(minHeight: 240),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (boolOf(priest['featured'])) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.gold.o(.15),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.gold.o(.3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(LucideIcons.award, size: 12, color: AppColors.gold),
                const SizedBox(width: 4),
                Text('Pandit of the Month', style: AppText.sans(size: 10, weight: FontWeight.w600, color: AppColors.gold)),
              ]),
            ),
            const SizedBox(height: 12),
          ],
          Icon(LucideIcons.quote, size: 20, color: AppColors.primary.o(.3)),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              '"${str(priest['quote'])}"',
              style: AppText.body(size: 14, color: AppColors.foreground.o(.85), height: 1.6, style: FontStyle.italic),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.border.o(.5)))),
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.o(.1),
                  border: Border.all(color: AppColors.gold.o(.4)),
                ),
                alignment: Alignment.center,
                child: strOrNull(priest['image']) == null
                    ? Text(str(priest['initials']),
                        style: AppText.body(size: 14, weight: FontWeight.w600, color: AppColors.primary))
                    : SiteImage(str(priest['image'])),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(str(priest['name']),
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.heading(size: 14, weight: FontWeight.w600)),
                  Text('${str(priest['city'])} · ${str(priest['years'])}+ yrs · ${str(priest['pujas'])}+ pujas',
                      style: AppText.sans(size: 11, color: AppColors.mutedForeground)),
                  const SizedBox(height: 2),
                  Row(children: [
                    const Icon(Icons.star_rounded, size: 13, color: AppColors.gold),
                    const SizedBox(width: 4),
                    Text(str(priest['rating']), style: AppText.sans(size: 11, weight: FontWeight.w600)),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(langs,
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.sans(size: 10, color: AppColors.mutedForeground)),
                    ),
                  ]),
                ]),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// FAQSection.jsx
// ---------------------------------------------------------------------------

const defaultHomeFaqs = <Json>[
  {
    'q': 'What services does BookMyPooja offer?',
    'a':
        'BookMyPooja, started in 2021, offers hassle free and reliable Pandits for puja arrangements services. Priests of your cultures get allocated for your puja rituals after booking. Entire process is efficiently managed for best puja benefits.',
  },
  {
    'q': 'Who started BookMyPooja?',
    'a':
        'Mr Dayanand Kamble is the founder of BookMyPooja. He is an experienced astrologer and author of the upcoming Book “Altar Ego - Ancient Vedic Rituals for Modern Souls”. He is an IIM Bangalore Alumnus who has more than 20 years of experience in corporate life as well.',
  },
  {
    'q': 'Is it reliable to book online through the Insta Book method?',
    'a':
        'Absolutely! Our Insta Book method is 100% reliable. Our dedicated Seva Team of expert priests and astrologers works behind the scenes from 8 AM to 9 PM every day. The moment your booking is received, they begin allocating a qualified pandit and share all necessary details with you promptly. Not a single puja has been missed or delayed out of the 10,000+ ceremonies we have facilitated so far. You can also track your booking status in real time — giving you complete peace of mind from the moment you book.',
  },
  {
    'q': 'Will I definitely get the Panditji of my preferred language?',
    'a':
        'We have a wide network of verified Vedic priests, so you will definitely get a pandit of your preferred language. However, for festive dates, we advise checking in advance with our team to ensure availability.',
  },
  {
    'q': 'Do I need to pay in advance?',
    'a':
        'Based on the package you choose, you can either pay the full amount upfront or pay a partial advance to confirm your booking (if booked through the Insta Book method). If you choose partial payment, the remaining balance is to be paid after the puja is completed by logging into the platform.',
  },
  {
    'q': 'When do I get to know about the allocated Pandit Ji?',
    'a': 'After the puja is booked, within 24–48 hours. If the puja is within 24–48 hours itself, it will be allocated on priority — not to worry.',
  },
  {
    'q': 'Are the packages including Dakshina?',
    'a':
        'Yes, every package includes Dakshina, travel charges, and puja items as a bare minimum. Larger packages may account for fruits, flowers, additional priests, additional days of rituals, or more mantras.',
  },
  {
    'q': 'Can I pay the balance amount to Pandit Ji directly?',
    'a':
        "As a technology-first platform committed to financial transparency, all Dakshina and payments are processed through BookMyPooja. After the puja is successfully completed, the pandit's Dakshina is transferred directly to their bank account from BookMyPooja. You are not expected to pay the pandit directly — this ensures clarity and avoids any miscommunication.",
  },
  {'q': 'Can I reschedule my booking?', 'a': 'Please refer to our Terms & Conditions for rescheduling policies.'},
  {
    'q': 'Can I book for someone else?',
    'a': "Absolutely! You can book a puja for family or friends. Just provide their details during booking and we'll coordinate directly with them.",
  },
  {
    'q': 'I have put an enquiry — how does the booking happen after that?',
    'a':
        'Once you submit an enquiry, our Seva Team of expert pandits and astrologers will get in touch with you to understand your requirements. They will guide you on the puja to be performed, its duration, auspicious dates and times, and the most suitable package and costs. After the consultation, you can either book through the Insta Book method or work with the team to create a custom package tailored to your needs.',
  },
  {
    'q': 'How does custom booking work?',
    'a':
        'If the puja you need is not available as a standard Insta Book package, our team will create a custom booking for you. They will collect essential details — your name, email, phone number, Google Maps location, priest language preference, and chosen package. A payment link from our partner Razorpay will be shared for you to complete a 50% advance payment to confirm the booking. Once received, the booking is confirmed and pandit allocation begins within 24–48 hours. After the puja is completed, the remaining balance is payable through the same payment link. Please note — you are not expected to pay the pandit directly, as their Dakshina is transferred from BookMyPooja to their bank account after the puja.',
  },
  {
    'q': 'How do you verify Pandits registered on your platform?',
    'a':
        'Every pandit on BookMyPooja goes through a rigorous multi-step verification process. We check their Vedic education certificates from recognized Pathshalas, assess language proficiencies, review their experience conducting specific rituals, verify the number of years of active practice, and conduct reference checks with previous yajmaans (hosts). We also evaluate their knowledge of regional customs and rituals. Only pandits who clear all stages are onboarded, ensuring you receive a qualified and trustworthy priest every time.',
  },
  {
    'q': 'If Pandit Dakshina is included in the package, how does the Pandit get paid?',
    'a':
        "Our pandits' bank accounts are linked directly with the BookMyPooja platform. Once the puja is successfully completed and confirmed, the Dakshina amount is released to the pandit's account electronically. This ensures timely, transparent, and hassle-free payments for every priest.",
  },
  {
    'q': 'Do I need to pay anything extra to the Pandit?',
    'a':
        'No, you do not need to pay anything extra. All our pandits are trained and briefed not to ask for any additional payments beyond what is included in your package. If you choose to offer something voluntarily as a gesture of goodwill, that is entirely your personal choice — BookMyPooja does not get involved in or have any say over voluntary offerings.',
  },
  {
    'q': "What if I don't get a pandit of my preferred language?",
    'a':
        'In over 90% of bookings, we successfully match your preferred language. However, during festive seasons or peak demand periods, scheduling conflicts may occasionally arise. In such cases, we reserve the right to allocate a pandit of a different language preference to ensure your puja is conducted on time.',
  },
  {
    'q': 'Your team assigned a different language Pandit Ji. Will it affect my puja experience?',
    'a':
        'Not at all. Assigning a pandit of a different linguistic background happens only about 10% of the time and is quite rare. In Vedic tradition, all puja steps, rituals, and mantras are performed in Sanskrit following established scriptural procedures. Language preference helps you feel closer to your mother tongue, but it does not impact the spiritual benefits or effectiveness of the puja in any way.',
  },
  {'q': 'Cancellation and Refund', 'a': null},
];

class FaqSection extends StatefulWidget {
  const FaqSection({super.key, required this.items});
  final List<Json> items;

  @override
  State<FaqSection> createState() => _FaqSectionState();
}

class _FaqSectionState extends State<FaqSection> {
  int? _open;

  @override
  Widget build(BuildContext context) {
    final faqs = widget.items.isNotEmpty ? widget.items : defaultHomeFaqs;
    return Anchor(
      'faq',
      child: Container(
        color: AppColors.card,
        padding: _container.copyWith(top: 40, bottom: 40),
        child: Column(
          children: [
            const HighlightHeading(title: 'Frequently Asked', highlight: 'Questions', size: 30),
            const SizedBox(height: 12),
            Text('Everything you need to know before booking',
                textAlign: TextAlign.center, style: AppText.body(size: 18, color: AppColors.mutedForeground)),
            const SizedBox(height: 40),
            for (var i = 0; i < faqs.length; i++) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: AccordionTile(
                  showBorder: false,
                  open: _open == i,
                  onToggle: () => setState(() => _open = _open == i ? null : i),
                  title: Text(str(faqs[i]['q']), style: AppText.sans(size: 16, weight: FontWeight.w600)),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: strOrNull(faqs[i]['a']) != null
                        ? Text(str(faqs[i]['a']), style: AppText.body(size: 14, color: AppColors.mutedForeground, height: 1.6))
                        : Text.rich(
                            TextSpan(children: [
                              const TextSpan(
                                  text: 'Our cancellation and refund policies are detailed in our Terms & Conditions. Please refer to them here: '),
                              WidgetSpan(
                                child: GestureDetector(
                                  onTap: () => goHref(context, '/terms-and-conditions'),
                                  child: Text('Terms & Conditions',
                                      style: AppText.body(size: 14, color: AppColors.primary, decoration: TextDecoration.underline)),
                                ),
                              ),
                            ]),
                            style: AppText.body(size: 14, color: AppColors.mutedForeground, height: 1.6),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// FinalCTASection.jsx
// ---------------------------------------------------------------------------

class FinalCtaSection extends StatelessWidget {
  const FinalCtaSection({super.key, required this.data});
  final Json data;

  @override
  Widget build(BuildContext context) {
    final points = list(data['trustPoints']).map((e) => '$e').toList();
    const icons = [LucideIcons.userCheck, LucideIcons.sparkles, LucideIcons.shieldCheck];
    return Container(
      color: AppColors.primary,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          const Positioned(right: -80, bottom: -80, child: MandalaWatermark(size: 400, color: Colors.white, opacity: .08)),
          Padding(
            padding: _container.copyWith(top: 40, bottom: 40),
            child: Column(
              children: [
                splitHeading(str(data['title']), str(data['highlight']),
                    color: Colors.white, highlightColor: AppColors.saffron, highlightStyle: FontStyle.italic),
                const SizedBox(height: 16),
                Opacity(
                  opacity: .9,
                  child: Text(str(data['subtitle']),
                      textAlign: TextAlign.center, style: AppText.sans(size: 18, color: Colors.white)),
                ),
                const SizedBox(height: 32),
                AppButton(
                  variant: BtnVariant.secondary,
                  size: BtnSize.lg,
                  height: 52,
                  label: str(data['bookButton']),
                  trailingIcon: LucideIcons.arrowRight,
                  textStyle: AppText.sans(size: 16, weight: FontWeight.w600),
                  onPressed: () => SectionAnchors.maybeOf(context)?.scrollTo('self-booking'),
                ),
                const SizedBox(height: 12),
                AppButton(
                  size: BtnSize.lg,
                  height: 52,
                  background: AppColors.whatsapp,
                  textStyle: AppText.sans(size: 16, weight: FontWeight.w600),
                  onPressed: () => openExternal(str(data['whatsappHref'])),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const WhatsAppIcon(size: 20),
                    const SizedBox(width: 8),
                    Text(str(data['chatButton'])),
                  ]),
                ),
                const SizedBox(height: 32),
                Opacity(
                  opacity: .8,
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 24,
                    runSpacing: 8,
                    children: [
                      for (var i = 0; i < points.length; i++)
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(icons[i % 3], size: 16, color: Colors.white),
                          const SizedBox(width: 6),
                          Text(points[i], style: AppText.sans(size: 14, color: Colors.white)),
                        ]),
                    ],
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
