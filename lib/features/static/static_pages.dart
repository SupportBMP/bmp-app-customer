import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/bmp_api.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/json.dart';
import '../../core/utils/launch.dart';
import '../../core/widgets/fieldset.dart';
import '../../core/widgets/html_content.dart';
import '../../core/widgets/site/site_page.dart';
import '../../core/widgets/site_image.dart';
import '../../core/widgets/toast.dart';
import '../pooja/pooja_detail_page.dart';

/// data/data.json
final dataJsonProvider = FutureProvider<Json>((ref) async => obj(jsonDecode(await rootBundle.loadString('assets/data/data.json'))));

// ---------------------------------------------------------------------------
// pages/about-us/index.jsx
// ---------------------------------------------------------------------------

class AboutUsPage extends ConsumerWidget {
  const AboutUsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(dataJsonProvider).value ?? const <String, dynamic>{};
    final sections = objList(d['sections']);
    final stats = objList(d['statistics']);
    return SitePage(pageType: 'other', children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        child: Text(
          "Book My Pooja is India's Most Trusted Platform for Booking Religious Rituals",
          textAlign: TextAlign.center,
          style: AppText.sans(size: 24, weight: FontWeight.w600, color: AppColors.bluntRed, height: 28 / 24),
        ),
      ),
      Container(
        margin: const EdgeInsets.fromLTRB(24, 0, 24, 28),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(border: Border.all(color: AppColors.gray200)),
        child: Column(children: [
          for (final s in sections)
            Padding(
              padding: const EdgeInsets.only(bottom: 28),
              child: Column(children: [
                SiteImage(str(s['icon']), width: 64, height: 64, fit: BoxFit.contain, placeholderColor: Colors.transparent),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(str(s['title']), style: AppText.sans(weight: FontWeight.w500, color: AppColors.defaultText)),
                ),
                Text(str(s['description']),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.sans(size: 14, color: AppColors.headerQuote, height: 24 / 14)),
              ]),
            ),
        ]),
      ),
      Container(
        margin: const EdgeInsets.symmetric(vertical: 24),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        decoration: const BoxDecoration(
          image: DecorationImage(image: AssetImage('assets/icons/Map.png'), fit: BoxFit.cover),
        ),
        child: Column(children: [
          for (final s in stats)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(children: [
                Text(str(s['value']), style: AppText.sans(size: 30, weight: FontWeight.w600, color: AppColors.bluntRed)),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(str(s['label']), textAlign: TextAlign.center, style: AppText.sans(color: AppColors.defaultText)),
                ),
              ]),
            ),
        ]),
      ),
    ]);
  }
}

// ---------------------------------------------------------------------------
// pages/about-us/testimonies.jsx + TestimonialBox.jsx
// ---------------------------------------------------------------------------

class TestimoniesPage extends StatefulWidget {
  const TestimoniesPage({super.key});
  @override
  State<TestimoniesPage> createState() => _TestimoniesPageState();
}

class _TestimoniesPageState extends State<TestimoniesPage> {
  List<Json> _data = [];

  @override
  void initState() {
    super.initState();
    BmpApi.testimonials(1, 100).then((r) {
      final d = obj(r.data);
      if (r.statusCode == 200 && intOf(d['statusCode']) == 200 && mounted) setState(() => _data = objList(d['body']));
    }).catchError((_) {
      Toast.error('Error fetching testimonial details');
    });
  }

  @override
  Widget build(BuildContext context) => SitePage(pageType: 'other', children: [
        const SizedBox(height: 40),
        Text('Speaking from their hearts',
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'Bastoni', fontSize: 20, fontWeight: FontWeight.w300, color: AppColors.defaultText, height: 1.2)),
        const SizedBox(height: 16),
        for (final t in _data) Padding(padding: const EdgeInsets.all(12), child: TestimonialBox(data: t)),
        const SizedBox(height: 16),
      ]);
}

class TestimonialBox extends StatelessWidget {
  const TestimonialBox({super.key, required this.data});
  final Json data;

  @override
  Widget build(BuildContext context) {
    final text = str(data['testimonial']);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.slate100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gray200),
        boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 15, offset: Offset(0, 10), spreadRadius: -3)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 40,
            height: 40,
            margin: const EdgeInsets.only(right: 16, top: 4),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
            child: SiteImage(strOrNull(data['image']) ?? '/icons/user.svg', placeholderColor: Colors.transparent),
          ),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(str(data['name']), style: AppText.poppins(size: 20, color: AppColors.defaultText, letterSpacing: .5))),
                StarRow(rating: numOf(data['rating'])),
              ]),
              Row(children: [
                Text(str(data['location']), style: AppText.poppins(size: 14, color: AppColors.defaultText, letterSpacing: .4)),
                const SizedBox(width: 8),
                Text(str(data['language']), style: AppText.poppins(size: 14, color: AppColors.defaultText, letterSpacing: .4)),
              ]),
            ]),
          ),
        ]),
        const SizedBox(height: 8),
        Text(str(data['highlight']), style: AppText.poppins(weight: FontWeight.w600, color: AppColors.bluntRed, letterSpacing: .4)),
        const SizedBox(height: 4),
        // On /about-us pages the website shows up to 1000 characters.
        Text(text.length > 1000 ? '${text.substring(0, 1000)}...' : text,
            style: AppText.sans(size: 14, color: AppColors.defaultText, height: 20 / 14)),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// CommonComponent/Accordian.jsx (item2 style) — used by /faq and /terms
// ---------------------------------------------------------------------------

class LegacyAccordion extends StatefulWidget {
  const LegacyAccordion({super.key, required this.items});

  /// (header, content widget)
  final List<(String, Widget)> items;

  @override
  State<LegacyAccordion> createState() => _LegacyAccordionState();
}

class _LegacyAccordionState extends State<LegacyAccordion> {
  int? _open;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      for (var i = 0; i < widget.items.length; i++) ...[
        GestureDetector(
          onTap: () => setState(() => _open = _open == i ? null : i),
          child: Container(
            width: double.infinity,
            color: _open == i ? const Color(0x40CBD5E1) : const Color(0xFFF7F7F7),
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
            child: Row(children: [
              Expanded(child: Text(widget.items[i].$1, style: AppText.sans(size: 18, weight: FontWeight.w500, color: const Color(0xFF333333)))),
              SizedBox(
                width: 16,
                child: Text(_open == i ? '-' : '+',
                    textAlign: TextAlign.center,
                    style: AppText.sans(size: _open == i ? 36 : 27, weight: FontWeight.w700, color: AppColors.slate600, height: 1)),
              ),
            ]),
          ),
        ),
        if (_open == i)
          Container(
            width: double.infinity,
            color: const Color(0xFFF7F7F7),
            padding: const EdgeInsets.fromLTRB(40, 0, 40, 48),
            child: DefaultTextStyle.merge(
              style: AppText.sans(size: 14, color: const Color(0xFF777777), letterSpacing: .4, height: 24 / 14),
              textAlign: TextAlign.justify,
              child: widget.items[i].$2,
            ),
          ),
        const SizedBox(height: 16),
      ],
    ]);
  }
}

Widget _legacyTitlePage({required String title, required String rule, required Widget body}) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, textAlign: TextAlign.center, style: AppText.sans(size: 30, weight: FontWeight.w600, color: const Color(0xFF111111))),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 56, 24, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 160, child: Text(rule, style: AppText.poppins(size: 24, weight: FontWeight.w500, color: const Color(0xFF111111)))),
            const SizedBox(height: 20),
            Container(height: 1.5, color: AppColors.slate200),
          ]),
        ),
        Padding(padding: const EdgeInsets.fromLTRB(24, 48, 24, 112), child: body),
      ],
    );

/// pages/faq/index.jsx
class FaqPage extends StatefulWidget {
  const FaqPage({super.key});
  @override
  State<FaqPage> createState() => _FaqPageState();
}

class _FaqPageState extends State<FaqPage> {
  List<Json> _faqs = [];

  @override
  void initState() {
    super.initState();
    BmpApi.allFaqs().then((r) {
      final d = obj(r.data);
      if (r.statusCode == 200 && intOf(d['statusCode']) == 200 && mounted) setState(() => _faqs = objList(d['body']));
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) => SitePage(pageType: 'other', children: [
        _legacyTitlePage(
          title: 'FAQ Section',
          rule: "FAQ's",
          body: LegacyAccordion(items: [
            for (final f in _faqs)
              (str(f['question']), PoojaHtml(str(f['answer']), color: const Color(0xFF777777), textAlign: TextAlign.justify)),
          ]),
        ),
      ]);
}

/// pages/terms-and-conditions/index.jsx
class TermsPage extends ConsumerWidget {
  const TermsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = objList((ref.watch(dataJsonProvider).value ?? const {})['termsPrivacyAccordion']);
    return SitePage(pageType: 'other', children: [
      _legacyTitlePage(
        title: 'Terms and Conditions',
        rule: 'Terms of Use',
        body: LegacyAccordion(items: [for (final i in items) (str(i['header']), Text(str(i['content'])))]),
      ),
    ]);
  }
}

// ---------------------------------------------------------------------------
// pages/privacy-policy/index.jsx (markup bundled as assets/data/privacy-policy.html)
// ---------------------------------------------------------------------------

final _privacyProvider = FutureProvider<String>((ref) => rootBundle.loadString('assets/data/privacy-policy.html'));

class PrivacyPolicyPage extends ConsumerWidget {
  const PrivacyPolicyPage({super.key});

  static Map<String, String>? _styles(dynamic e) {
    final classes = (e.classes as Iterable).map((c) => '$c').toSet();
    final s = <String, String>{};
    bool has(String c) => classes.contains(c);
    if (has('bg-BluntRed')) s['background-color'] = '#8A1C23';
    if (has('bg-white')) s['background-color'] = '#FFFFFF';
    if (has('bg-gray-50')) s['background-color'] = '#F9FAFB';
    if (has('text-white')) s['color'] = '#FFFFFF';
    if (has('text-BluntRed')) s['color'] = '#8A1C23';
    if (has('text-gray-700')) s['color'] = '#374151';
    if (has('text-gray-800')) s['color'] = '#1F2937';
    if (has('text-3xl')) s['font-size'] = '30px';
    if (has('text-2xl')) s['font-size'] = '24px';
    if (has('text-xl')) s['font-size'] = '20px';
    if (has('text-lg')) s['font-size'] = '18px';
    if (has('font-bold')) s['font-weight'] = '700';
    if (has('font-semibold')) s['font-weight'] = '600';
    if (has('leading-relaxed')) s['line-height'] = '1.625';
    if (has('p-4')) s['padding'] = '16px';
    if (has('p-6')) s['padding'] = '24px';
    if (has('p-8')) s['padding'] = '32px';
    if (has('px-4')) s['padding'] = '${has('py-12') ? '48px' : '0'} 16px';
    if (has('py-6')) s['padding'] = '24px 0';
    if (has('rounded-lg') || has('rounded')) s['border-radius'] = '8px';
    for (final m in const ['mb-2', 'mb-3', 'mb-4', 'mb-6', 'mb-12']) {
      if (has(m)) s['margin-bottom'] = '${int.parse(m.substring(3)) * 4}px';
    }
    if (has('mt-2')) s['margin-top'] = '8px';
    if (has('mt-4')) s['margin-top'] = '16px';
    if (has('mt-12')) s['margin-top'] = '48px';
    if (has('text-center')) s['text-align'] = 'center';
    if (e.localName == 'p' || e.localName == 'h1' || e.localName == 'h2' || e.localName == 'h3') s.putIfAbsent('margin', () => '0');
    return s.isEmpty ? null : s;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final html = ref.watch(_privacyProvider).value;
    return SitePage(pageType: 'other', background: AppColors.bluntRed, children: [
      if (html != null)
        HtmlWidget(
          html,
          textStyle: AppText.sans(size: 16, color: AppColors.gray700),
          customStylesBuilder: _styles,
        ),
    ]);
  }
}

// ---------------------------------------------------------------------------
// pages/contact-us/index.jsx
// ---------------------------------------------------------------------------

class ContactUsPage extends StatefulWidget {
  const ContactUsPage({super.key});
  @override
  State<ContactUsPage> createState() => _ContactUsPageState();
}

class _ContactUsPageState extends State<ContactUsPage> {
  final _form = {'fullName': '', 'phone': '', 'email': '', 'enquiry': ''};

  static const _specs = <String, Json>{
    'fullName': {'type': 'text', 'placeholder': 'Enter First Name', 'required': true, 'label': 'Full Name'},
    'phone': {'type': 'number', 'placeholder': 'Enter Phone Number without +91', 'required': true, 'label': 'Phone'},
    'email': {'type': 'text', 'placeholder': 'Enter Email', 'required': false, 'label': 'Email'},
    'enquiry': {'type': 'textarea', 'placeholder': 'Enter your enquiry', 'required': false, 'label': 'Enquiry'},
  };

  bool get _valid => _specs.entries.where((e) => boolOf(e.value['required'])).every((e) => _form[e.key]!.isNotEmpty);

  Widget _svg(String path) => SvgPicture.string(
        '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="#8A1C23" stroke-width="2">$path</svg>',
        width: 24,
        height: 24,
      );

  Widget _contactRow(Widget icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          icon,
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: AppText.poppins(color: AppColors.gray700))),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return SitePage(pageType: 'other', children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 32, 16, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 15, offset: Offset(0, 10), spreadRadius: -3)],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Submit Your Enquiry Here', style: AppText.poppins(size: 20, weight: FontWeight.w600, color: AppColors.gray800)),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 15, offset: Offset(0, 10), spreadRadius: -3)],
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  for (final e in _specs.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: DynamicFormField(spec: e.value, value: _form[e.key]!, onChanged: (v) => setState(() => _form[e.key] = v)),
                    ),
                  GestureDetector(
                    onTap: () {
                      if (!_valid) Toast.error('Please fill all the required fields');
                    },
                    child: Container(
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: _valid ? AppColors.bluntRed : AppColors.gray400, borderRadius: BorderRadius.circular(8)),
                      child: Text('Submit Enquiry', style: AppText.poppins(color: _valid ? Colors.white : AppColors.gray50)),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 32),
          Text('Contact Us For More Info', style: AppText.poppins(size: 24, weight: FontWeight.w600, color: AppColors.bluntRed)),
          const SizedBox(height: 24),
          _contactRow(
            _svg('<path stroke-linecap="round" stroke-linejoin="round" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"/>'
                '<path stroke-linecap="round" stroke-linejoin="round" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"/>'),
            'Krishnappa Garden, C V Raman Nagar, Bengaluru Karnataka 560093',
          ),
          _contactRow(
            _svg('<path stroke-linecap="round" stroke-linejoin="round" d="M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z"/>'),
            '(+91) 9869929292',
          ),
          _contactRow(
            _svg('<path stroke-linecap="round" stroke-linejoin="round" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"/>'),
            'support@bookmypooja.online',
          ),
          Text('Follow us', style: AppText.poppins(color: AppColors.gray600)),
          const SizedBox(height: 12),
          Row(children: [
            for (final s in const [
              ('/icons/fb-icon.png', 'https://www.facebook.com/p/Bookmypooja-100081370088277/'),
              ('/icons/instagram.svg', 'https://www.instagram.com/bookmypooja.online/'),
              ('/icons/linkedin.svg', 'https://www.linkedin.com/company/bookmypooja1/'),
              ('/icons/x-icon.png', 'https://x.com/bookmypooja1?t=NIv60KKoU47ytqTN996lmQ&s=08'),
              ('/icons/youtube.svg', 'https://www.youtube.com/@bookmypoojaonline242'),
            ])
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: GestureDetector(
                  onTap: () => openExternal(s.$2),
                  child: SiteImage(s.$1, width: 30, height: 30, fit: BoxFit.contain, placeholderColor: Colors.transparent),
                ),
              ),
          ]),
        ]),
      ),
    ]);
  }
}

/// pages/404.jsx — toast and go home.
class RedirectHome404 extends StatefulWidget {
  const RedirectHome404({super.key});
  @override
  State<RedirectHome404> createState() => _RedirectHome404State();
}

class _RedirectHome404State extends State<RedirectHome404> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Toast.show('ℹ️ Page not found. Redirecting to homepage...');
      if (mounted) GoRouter.of(context).go('/');
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: Text('Redirecting to homepage...', style: AppText.poppins(size: 20, color: AppColors.gray600))),
      );
}
