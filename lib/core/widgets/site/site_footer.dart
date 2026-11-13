import 'package:flutter/material.dart';

import '../../config.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../utils/json.dart';
import '../../utils/launch.dart';
import '../../utils/nav.dart';
import '../lucide_by_name.dart';
import '../site_image.dart';

/// components/v2/landing/Footer.jsx (mobile: single column).
class SiteFooter extends StatelessWidget {
  const SiteFooter({super.key, this.data});

  /// `/pooja-global/home-v2` → `body.footer` on the homepage; null elsewhere.
  final Json? data;

  static const _cityLanguages = <String, List<String>>{
    'Bangalore': ['Kannada Purohiths', 'Hindi Pandits', 'Marathi Guruji', 'Tamil Vadhyars', 'Telugu Poojari', 'Bengali Pandit'],
    'Chennai': ['Tamil Vadhyars', 'Hindi Pandits', 'Telugu Poojari', 'Kannada Purohiths', 'Bengali Pandit'],
    'Hyderabad': ['Telugu Poojari', 'Hindi Pandits', 'Marathi Guruji', 'Tamil Vadhyars', 'Kannada Purohiths'],
    'Pune': ['Marathi Guruji', 'Hindi Pandits', 'Gujarati Purohit', 'Telugu Poojari'],
    'Mumbai': ['Marathi Guruji', 'Hindi Pandits', 'Gujarati Purohit', 'Tamil Vadhyars', 'Bengali Pandit'],
    'Delhi': ['Hindi Pandits', 'Bengali Pandit', 'Marathi Guruji', 'Telugu Poojari', 'Tamil Vadhyars'],
  };

  static const _bgText = Color(0xCCFFFFFF); // text-background/80

  /// Pages the app leaves out stay reachable on the website.
  static void _open(BuildContext context, String url) {
    if (url == '/auth/pandit' || url.startsWith('/partners')) {
      openExternal('${AppConfig.siteUrl}$url');
    } else {
      goHref(context, url);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = data ?? const <String, dynamic>{};
    final logo = strOrNull(d['logoUrl']) ?? '/images/bmp.png';
    final description = strOrNull(d['description']) ??
        "India's most trusted platform for booking pujas, homams, and religious ceremonies. Available across 10+ cities in 10+ languages. Facilitates E-Pujas for devotees worldwide.";
    final sections = objList(d['footerSections']);
    final social = objList(d['socialLinks']);
    final copyright = strOrNull(d['copyrightText']) ??
        '© ${DateTime.now().year} Metaplus Technologies Private Limited. All rights reserved.';
    final link = AppText.sans(size: 14, color: Colors.white.o(.7));

    return Container(
      color: AppColors.footerBg,
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 48),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: _bgText),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 128,
              height: 80,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
              child: SiteImage(logo, fit: BoxFit.contain, placeholderColor: Colors.white),
            ),
            const SizedBox(height: 16),
            Opacity(
              opacity: .7,
              child: Text(description, style: AppText.sans(size: 14, color: _bgText, height: 1.6)),
            ),
            if (social.isNotEmpty) ...[
              const SizedBox(height: 24),
              Row(children: [
                for (final s in social)
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: GestureDetector(
                      onTap: () => openExternal(str(s['url'])),
                      child: SocialIcon(str(s['platform']), color: _bgText),
                    ),
                  ),
              ]),
            ],
            const SizedBox(height: 32),
            for (final section in sections) ...[
              Text(str(section['title']), style: AppText.sans(weight: FontWeight.w700, color: Colors.white)),
              const SizedBox(height: 12),
              for (final l in objList(section['links']))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GestureDetector(
                    onTap: () => _open(context, str(l['url'])),
                    child: Text(str(l['text']), style: link),
                  ),
                ),
              const SizedBox(height: 24),
            ],
            if (sections.isEmpty) ...[
              Text('Quick Links', style: AppText.sans(weight: FontWeight.w700, color: Colors.white)),
              const SizedBox(height: 12),
              for (final l in const [
                ['About Us', '/about-us'],
                ['Blogs', '/vidya'],
                ['Pandit Registration', '/auth/pandit'],
                ['Terms & Conditions', '/terms-and-conditions'],
                ['Privacy Policy', '/privacy-policy'],
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GestureDetector(onTap: () => _open(context, l[1]), child: Text(l[0], style: link)),
                ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.only(top: 32),
                decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.white.o(.1)))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Book Puja in Your City', style: AppText.sans(size: 18, weight: FontWeight.w700, color: Colors.white)),
                    const SizedBox(height: 24),
                    _CityGrid(entries: _cityLanguages.entries.toList()),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 24),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.white.o(.1)))),
              child: Opacity(
                opacity: .5,
                child: Text(copyright, textAlign: TextAlign.center, style: AppText.sans(size: 14, color: _bgText)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CityGrid extends StatelessWidget {
  const _CityGrid({required this.entries});
  final List<MapEntry<String, List<String>>> entries;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < entries.length; i += 2) {
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _city(context, entries[i])),
            const SizedBox(width: 32),
            Expanded(child: i + 1 < entries.length ? _city(context, entries[i + 1]) : const SizedBox()),
          ],
        ),
      ));
    }
    return Column(children: rows);
  }

  Widget _city(BuildContext context, MapEntry<String, List<String>> e) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(e.key, style: AppText.sans(size: 14, weight: FontWeight.w600, color: Colors.white)),
          const SizedBox(height: 8),
          for (final lang in e.value)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: GestureDetector(
                onTap: () => goHref(context, '/${lang.split(' ').first.toLowerCase()}/${e.key.toLowerCase()}/pooja'),
                child: Text('$lang in ${e.key}', style: AppText.sans(size: 12, color: Colors.white.o(.6))),
              ),
            ),
        ],
      );
}
