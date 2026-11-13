import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
import '../../core/widgets/fieldset.dart';
import '../../core/widgets/portable_text.dart';
import '../../core/widgets/site/site_page.dart';
import '../../core/widgets/site_image.dart';
import '../../core/widgets/toast.dart';
import '../../core/widgets/ui.dart';

// ---------------------------------------------------------------------------
// pages/vidya/index.jsx
// ---------------------------------------------------------------------------

final _blogsProvider = FutureProvider.family<(List<Json>, int), int>((ref, page) async {
  try {
    final r = await BmpApi.allBlogs(page, 8);
    final d = obj(r.data);
    if (r.statusCode == 200 && intOf(d['statusCode']) == 200) return (objList(d['body']), intOf(d['totalCount']));
  } catch (_) {}
  return (<Json>[], 0);
});

class VidyaIndexPage extends ConsumerWidget {
  const VidyaIndexPage({super.key, this.page = 1});
  final int page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_blogsProvider(page));
    final (blogs, total) = async.value ?? (const <Json>[], 0);
    const pageSize = 8;
    final totalPages = (total / pageSize).ceil();

    return SitePage(
      pageType: 'other',
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.orange50, Colors.white, AppColors.red50]),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 32, 16, 32),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: AppColors.gray200)),
                boxShadow: [BoxShadow(color: Color(0x0D000000), blurRadius: 2, offset: Offset(0, 1))],
              ),
              child: Column(children: [
                Text('Spiritual Insights & Blogs',
                    textAlign: TextAlign.center, style: AppText.poppins(size: 30, weight: FontWeight.w700, color: AppColors.gray900)),
                const SizedBox(height: 16),
                Text('Discover ancient wisdom, festive traditions, and spiritual guidance for modern life',
                    textAlign: TextAlign.center, style: AppText.poppins(size: 18, color: AppColors.gray600)),
                const SizedBox(height: 24),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.check_circle, size: 16, color: AppColors.gray500),
                  const SizedBox(width: 8),
                  Text('$total Articles Available', style: AppText.poppins(size: 14, color: AppColors.gray500)),
                ]),
                if (totalPages > 1) ...[
                  const SizedBox(height: 16),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.menu, size: 16, color: AppColors.gray500),
                    const SizedBox(width: 8),
                    Text('Page $page of $totalPages', style: AppText.poppins(size: 14, color: AppColors.gray500)),
                  ]),
                ],
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 32, 16, 32),
              child: async.isLoading
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 80),
                      child: Column(children: [
                        const AppSpinner(),
                        const SizedBox(height: 16),
                        Text('Loading articles...', style: AppText.poppins(weight: FontWeight.w500, color: AppColors.gray600)),
                      ]),
                    )
                  : blogs.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 64),
                          child: Column(children: [
                            const Icon(LucideIcons.newspaper, size: 64, color: AppColors.gray400),
                            const SizedBox(height: 16),
                            Text('No Articles Found', style: AppText.poppins(size: 20, weight: FontWeight.w600, color: AppColors.gray900)),
                            const SizedBox(height: 8),
                            Text('Check back later for new spiritual insights and blog posts.',
                                textAlign: TextAlign.center, style: AppText.poppins(color: AppColors.gray600)),
                          ]),
                        )
                      : Column(children: [
                          for (final b in blogs) Padding(padding: const EdgeInsets.only(bottom: 24), child: BlogCard(blog: b)),
                          const SizedBox(height: 24),
                        ]),
            ),
            if (totalPages > 1)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.gray200),
                  boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 2, offset: Offset(0, 1))],
                ),
                child: Column(children: [
                  Text('Showing ${(page - 1) * pageSize + 1} to ${math.min(page * pageSize, total)} of $total articles',
                      style: AppText.poppins(size: 14, color: AppColors.gray600)),
                  const SizedBox(height: 16),
                  _UrlPagination(
                    nPages: totalPages,
                    currentPage: page,
                    onPageChange: (p) => context.pushReplacement(p > 1 ? '/vidya?page=$p' : '/vidya'),
                  ),
                ]),
              ),
          ]),
        ),
      ],
    );
  }
}

/// blogComponent/blogDataBox.jsx
class BlogCard extends StatelessWidget {
  const BlogCard({super.key, required this.blog});
  final Json blog;

  @override
  Widget build(BuildContext context) {
    final slug = str(pick(blog, ['blogSlug', 'current']));
    return GestureDetector(
      onTap: () => context.push('/vidya/$slug'),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.gray100),
          boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 6, offset: Offset(0, 4), spreadRadius: -1)],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
            height: 192,
            child: Stack(fit: StackFit.expand, children: [
              SiteImage(strOrNull(blog['blogHeadingImageUrl'])),
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .9),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 2)],
                  ),
                  child: Text('5 min read', style: AppText.poppins(size: 12, weight: FontWeight.w500, color: AppColors.gray700)),
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(str(blog['blogTitle']),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.poppins(size: 18, weight: FontWeight.w700, color: AppColors.gray900, height: 1.25)),
              const SizedBox(height: 12),
              ClipRect(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 22.0 * 3),
                  // line-clamp-3: size to the content, clip anything past three lines.
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: PortableTextView(
                    blocks: list(blog['blogShortSummary']),
                    maxLines: 3,
                    styles: PortableStyles(
                      normal: AppText.poppins(size: 14, color: AppColors.gray600, height: 1.6),
                      strongColor: AppColors.gray800,
                    ),
                  ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.only(top: 16),
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.gray100))),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if (strOrNull(blog['blogAuthor']) != null)
                        Text(str(blog['blogAuthor']), style: AppText.poppins(size: 14, weight: FontWeight.w500, color: AppColors.gray900)),
                      if (strOrNull(blog['blogPublishedOn']) != null)
                        Text(str(blog['blogPublishedOn']), style: AppText.poppins(size: 12, color: AppColors.gray500)),
                    ]),
                  ),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// pages/vidya/[slug].jsx
// ---------------------------------------------------------------------------

final _blogProvider = FutureProvider.family<Json?, String>((ref, slug) async {
  try {
    final r = await BmpApi.blogBySlug(slug);
    final d = obj(r.data);
    final body = objList(d['body']);
    if (r.statusCode == 200 && intOf(d['statusCode']) == 200 && body.isNotEmpty) return body.first;
  } catch (_) {}
  return null;
});

const _defaultBlogForm = <Json>[
  {
    'fieldLabel': 'Full Name',
    'fieldName': 'username',
    'fieldNameV2': {'fieldName': 'name'},
    'fieldType': 'input',
    'isRequired': false,
    'placeholder': 'Please enter your name',
  },
  {
    'fieldLabel': 'Mobile Number',
    'fieldName': 'phone',
    'fieldNameV2': {'fieldName': 'phone'},
    'fieldType': 'input',
    'isRequired': true,
    'placeholder': 'Please enter your mobile number',
  },
  {
    'fieldLabel': 'City',
    'fieldName': 'city',
    'fieldNameV2': {'fieldName': 'city'},
    'fieldType': 'dropdown',
    'isRequired': false,
    'options': ['Bengaluru', 'Delhi', 'Hyderabad', 'Pune', 'Mumbai', 'Others'],
  },
  {
    'fieldLabel': 'Enquiry',
    'fieldName': 'pooja',
    'fieldNameV2': {'fieldName': 'enquiry'},
    'fieldType': 'text',
    'isRequired': true,
  },
];

class VidyaPostPage extends ConsumerWidget {
  const VidyaPostPage({super.key, required this.slug});
  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_blogProvider(slug));
    final blog = async.value;
    void openWa() => openWhatsApp("Hi! I'd like to chat with a Puja Advisor about a ceremony.\n\n${pageReference('/vidya/$slug')}");

    return SitePage(
      pageType: 'other',
      bottomBar: blog == null ? null : _bottomBar(context, openWa),
      children: [
        if (async.isLoading)
          const Padding(padding: EdgeInsets.symmetric(vertical: 120), child: AppSpinner())
        else if (blog == null)
          const NotFoundBody()
        else
          _BlogBody(blog: blog, slug: slug, openWa: openWa),
      ],
    );
  }

  Widget _bottomBar(BuildContext context, VoidCallback openWa) => Container(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.paddingOf(context).bottom),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.gray200)),
          boxShadow: [BoxShadow(color: Color(0x1A000000), blurRadius: 6, offset: Offset(0, -2))],
        ),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('Ready to book your puja?', style: AppText.poppins(size: 14, weight: FontWeight.w500, color: const Color(0xFF8A1C23))),
              Text('Expert pandits. Hassle Free Packages.', style: AppText.poppins(size: 12, color: AppColors.gray500)),
            ]),
          ),
          _small(AppColors.blue600, 80, const Icon(LucideIcons.phone, size: 14, color: Colors.white), 'Call', () => callPhone()),
          const SizedBox(width: 8),
          _small(AppColors.whatsappBrand, 100, const WhatsAppIcon(size: 14), 'WhatsApp', openWa),
        ]),
      );

  Widget _small(Color c, double w, Widget icon, String label, VoidCallback onTap) => Material(
        color: c,
        borderRadius: BorderRadius.circular(6),
        elevation: 1,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: SizedBox(
            width: w,
            height: 30,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              icon,
              const SizedBox(width: 4),
              Text(label, style: AppText.poppins(size: 12, weight: FontWeight.w500, color: Colors.white)),
            ]),
          ),
        ),
      );
}

class _BlogBody extends StatelessWidget {
  const _BlogBody({required this.blog, required this.slug, required this.openWa});
  final Json blog;
  final String slug;
  final VoidCallback openWa;

  PortableStyles get _styles => PortableStyles(
        normal: blogBody(),
        strongColor: AppColors.gray900,
        h2Border: AppColors.orange500,
        headings: {
          'h1': AppText.poppins(size: 30, weight: FontWeight.w700, color: AppColors.gray900, height: 1.25),
          'h2': AppText.poppins(size: 24, weight: FontWeight.w600, color: AppColors.gray900, height: 1.25),
          'h3': AppText.poppins(size: 20, weight: FontWeight.w600, color: AppColors.gray800, height: 1.25),
          'h4': AppText.poppins(size: 18, weight: FontWeight.w500, color: AppColors.gray800, height: 1.25),
          'h5': AppText.poppins(size: 16, weight: FontWeight.w500, color: AppColors.gray700, height: 1.25),
          'h6': AppText.poppins(size: 14, weight: FontWeight.w500, color: AppColors.gray700, height: 1.25),
        },
        blockquote: AppText.poppins(size: 18, color: AppColors.gray700, height: 1.6).copyWith(fontStyle: FontStyle.italic),
        blockSpacing: const {
          'normal': (0, 24),
          'h1': (48, 24),
          'h2': (40, 20),
          'h3': (32, 16),
          'h4': (24, 16),
          'h5': (20, 12),
          'h6': (16, 12),
          'blockquote': (24, 24),
        },
      );

  @override
  Widget build(BuildContext context) {
    final image = strOrNull(blog['blogHeadingImageUrl']);
    final content = objList(blog['blogParagraphsAndContent']);
    final fields = objList(pick(blog, ['customForm', 'fields'])).isNotEmpty ? objList(pick(blog, ['customForm', 'fields'])) : _defaultBlogForm;
    final formAt = (content.length * .3).floor();
    final ctaAt = (content.length * .6).floor();
    final authorImg = sanityImageUrl(blog['blogAuthorImage']);
    final poojaLinks = objList(blog['blogPoojaLinks']);

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(bottom: 96),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: const BoxDecoration(color: AppColors.gray50, border: Border(bottom: BorderSide(color: AppColors.gray200))),
          child: Row(children: [
            GestureDetector(onTap: () => context.go('/'), child: Text('Home', style: AppText.poppins(size: 14, color: AppColors.gray500))),
            Text('  /  ', style: AppText.poppins(size: 14, color: AppColors.gray400)),
            GestureDetector(onTap: () => context.push('/vidya'), child: Text('Blogs', style: AppText.poppins(size: 14, color: AppColors.gray500))),
            Text('  /  ', style: AppText.poppins(size: 14, color: AppColors.gray400)),
            Flexible(
              child: Text(str(blog['blogTitle'], 'Current Blog'),
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.poppins(size: 14, weight: FontWeight.w500, color: AppColors.gray900)),
            ),
          ]),
        ),
        if (image != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 48),
            child: SizedBox(
              height: 256,
              child: Stack(fit: StackFit.expand, children: [
                SiteImage(image),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Color(0x33000000), Colors.transparent]),
                  ),
                ),
              ]),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SizedBox(height: 16),
            if (strOrNull(blog['blogTitle']) != null)
              Text(str(blog['blogTitle']),
                  textAlign: TextAlign.center, style: AppText.poppins(size: 30, weight: FontWeight.w700, color: AppColors.gray900, height: 1.25)),
            const SizedBox(height: 24),
            Center(
              child: Container(
                width: 96,
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: const LinearGradient(colors: [Color(0xFFFB923C), AppColors.red500]),
                ),
              ),
            ),
            const SizedBox(height: 32),
            if (list(blog['blogShortSummary']).isNotEmpty)
              PortableTextView(
                blocks: list(blog['blogShortSummary']),
                styles: _styles.copyWithNormal(AppText.poppins(size: 18, color: AppColors.gray600, height: 1.6)),
              ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              margin: const EdgeInsets.only(bottom: 32),
              decoration: const BoxDecoration(border: Border.symmetric(horizontal: BorderSide(color: AppColors.gray200))),
              child: Column(children: [
                if (authorImg != null)
                  Container(
                    width: 48,
                    height: 48,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFFFED7AA), width: 2)),
                    child: SiteImage(authorImg),
                  ),
                const SizedBox(height: 16),
                if (strOrNull(blog['blogAuthor']) != null)
                  Text('By ${str(blog['blogAuthor'])}', style: AppText.poppins(size: 14, weight: FontWeight.w500, color: AppColors.gray900)),
                if (strOrNull(blog['blogPublishedOn']) != null)
                  Text('Published ${str(blog['blogPublishedOn'])}', style: AppText.poppins(size: 14, color: AppColors.gray500)),
              ]),
            ),
            for (var i = 0; i < content.length; i++) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 40),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (sanityImageUrl(content[i]['image']) != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Container(
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 15, offset: Offset(0, 10))],
                        ),
                        child: AspectRatio(aspectRatio: 16 / 9, child: SiteImage(sanityImageUrl(content[i]['image']))),
                      ),
                    ),
                  if (strOrNull(content[i]['youtubelink']) != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: YoutubeThumbnail(videoUrl: str(content[i]['youtubelink'])),
                    ),
                  if (list(content[i]['paragrahWithHeading']).isNotEmpty)
                    PortableTextView(blocks: list(content[i]['paragrahWithHeading']), styles: _styles),
                ]),
              ),
              if (i == formAt) _BlogLeadForm(blog: blog, fields: fields, slug: slug),
              if (i == ctaAt) _cta(context),
            ],
            if (strOrNull(blog['youtubeVideoId']) != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: YoutubeThumbnail(videoUrl: 'https://www.youtube.com/watch?v=${str(blog['youtubeVideoId'])}'),
              ),
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 48),
                width: 128,
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: const LinearGradient(colors: [Color(0xFFFB923C), AppColors.red500]),
                ),
              ),
            ),
            if (poojaLinks.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 48),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(colors: [AppColors.bluntRed, AppColors.red50]),
                ),
                child: Column(children: [
                  Text('Associated Poojas',
                      textAlign: TextAlign.center, style: AppText.poppins(size: 24, weight: FontWeight.w700, color: AppColors.gray900)),
                  const SizedBox(height: 16),
                  Text('Explore related spiritual services',
                      textAlign: TextAlign.center, style: AppText.poppins(size: 18, color: AppColors.gray600)),
                  const SizedBox(height: 32),
                  for (final p in poojaLinks)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: PoojaImageBox(
                        name: str(p['poojaName']),
                        imageUrl: '/images/Temple_Services.jpg',
                        onTap: () => goHref(context, str(p['poojaLink'])),
                      ),
                    ),
                ]),
              ),
          ]),
        ),
      ]),
    );
  }

  Widget _cta(BuildContext context) {
    final cta = obj(blog['CTA']);
    final type = strOrNull(cta['ctaType']);
    final (bg, icon) = switch (type) {
      'whatsapp' => (AppColors.green500, LucideIcons.messageCircle),
      'phone' => (AppColors.blue500, LucideIcons.phone),
      'link' => (AppColors.bluntRed, LucideIcons.externalLink),
      _ => (AppColors.bluntRed, LucideIcons.externalLink),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: GestureDetector(
          onTap: () {
            if (type == 'whatsapp') {
              openWa();
            } else if (type == 'phone') {
              callPhone();
            } else if (type == 'link' && strOrNull(cta['linkUrl']) != null) {
              // The website opens `blogDetails.linkUrl` here (not CTA.linkUrl).
              final url = strOrNull(blog['linkUrl']);
              if (url != null) openExternal(url);
            } else {
              context.go('/');
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            decoration: BoxDecoration(
              color: type == null ? null : bg,
              gradient: type == null ? const LinearGradient(colors: [AppColors.bluntRed, AppColors.red500]) : null,
              borderRadius: BorderRadius.circular(999),
              boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 15, offset: Offset(0, 10))],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 20, color: Colors.white),
              const SizedBox(width: 12),
              Flexible(
                child: Text(strOrNull(cta['title']) ?? 'Explore Vedic Pandits for Poojas',
                    style: AppText.poppins(size: 16, weight: FontWeight.w600, color: Colors.white)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

extension on PortableStyles {
  PortableStyles copyWithNormal(TextStyle normal) => PortableStyles(
        normal: normal,
        headings: headings,
        blockSpacing: blockSpacing,
        listIndent: listIndent,
        listGap: listGap,
        linkColor: linkColor,
        strongColor: strongColor,
        blockquote: blockquote,
        h2Border: h2Border,
      );
}

/// The lead form injected at 30% of a blog post.
class _BlogLeadForm extends ConsumerStatefulWidget {
  const _BlogLeadForm({required this.blog, required this.fields, required this.slug});
  final Json blog;
  final List<Json> fields;
  final String slug;

  @override
  ConsumerState<_BlogLeadForm> createState() => _BlogLeadFormState();
}

class _BlogLeadFormState extends ConsumerState<_BlogLeadForm> {
  late final Map<String, Json> _specs = transformFields(widget.fields);
  late Map<String, String> _values = {for (final k in _specs.keys) k: ''};
  bool _submitting = false;

  bool get _valid => _specs.entries.every((e) => !boolOf(e.value['required']) || (_values[e.key] ?? '').isNotEmpty);

  /// utils `formatBlogsForm`.
  Json _formatBlogsForm() {
    String norm(String s) => s.replaceAll(RegExp(r'\s+'), '').replaceAll('&', '').toLowerCase();
    final result = <String, dynamic>{};
    for (final f in widget.fields) {
      final original = norm(str(f['fieldName']));
      final match = _values.keys.where((k) => norm(k) == original).firstOrNull;
      final v2 = strOrNull(pick(f, ['fieldNameV2', 'fieldName']));
      final outKey = match != null && v2 != null ? v2 : str(f['fieldName']);
      if (match != null) {
        final v = _values[match]!;
        result[outKey] = result[outKey] != null ? '${result[outKey]}, $v' : v;
      } else {
        result.putIfAbsent(outKey, () => null);
      }
    }
    if (result.containsKey('phone')) result['phone'] = int.tryParse('${result['phone']}'.replaceAll(RegExp(r'\D'), ''));
    return result;
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    final path = '/vidya/${widget.slug}';
    try {
      try {
        final crm = createCrmLeadEnquiryBody(_formatBlogsForm());
        await BmpApi.postGlobalLeadCapture({...crm, 'webPageLink': '${AppConfig.siteUrl}$path'});
      } catch (_) {}
      final r = await BmpApi.postEnquiry({
        'unstructuredData': jsonEncode(_values.map((k, v) => MapEntry(k, {'value': v}))),
        'leadType': 1,
        'referenceFrom': path,
      });
      final d = obj(r.data);
      if (r.statusCode == 201) {
        if (intOf(d['statusCode']) == 200) {
          Toast.success(str(d['message']));
          setState(() => _values = {for (final k in _specs.keys) k: ''});
        } else {
          Toast.error(str(d['message']));
        }
      } else {
        Toast.show('Something went wrong');
      }
    } catch (_) {
      Toast.error('Error posting pooja leads. Please try again later.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final valid = _valid && !_submitting;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 64),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFEDD5), AppColors.red50, Color(0xFFFEF9C3)],
        ),
        boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 15, offset: Offset(0, 10))],
      ),
      child: Column(children: [
        Text(strOrNull(widget.blog['customFormHeading']) ?? 'Having doubts or want to book a pooja?',
            textAlign: TextAlign.center, style: AppText.poppins(size: 24, weight: FontWeight.w700, color: AppColors.gray900)),
        const SizedBox(height: 16),
        Text("Fill out the form below and we'll get back to you soon",
            textAlign: TextAlign.center, style: AppText.poppins(size: 18, color: AppColors.gray600)),
        const SizedBox(height: 32),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.gray100),
            boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 25, offset: Offset(0, 20))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(gradient: LinearGradient(colors: [AppColors.bluntRed, AppColors.red500])),
              child: Text('Fill Your Details',
                  textAlign: TextAlign.center, style: AppText.poppins(size: 20, weight: FontWeight.w600, color: Colors.white)),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (final e in _specs.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: DynamicFormField(
                      key: ValueKey('${e.key}-${_values[e.key]!.isEmpty}'),
                      spec: e.value,
                      value: _values[e.key]!,
                      onChanged: (v) => setState(() => _values[e.key] = v),
                    ),
                  ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: valid ? _submit : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: valid ? null : AppColors.gray300,
                      gradient: valid ? const LinearGradient(colors: [AppColors.bluntRed, AppColors.red500]) : null,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_submitting ? 'Submitting...' : 'Submit Enquiry',
                        textAlign: TextAlign.center,
                        style: AppText.poppins(size: 14, weight: FontWeight.w500, color: valid ? Colors.white : AppColors.gray500, letterSpacing: .4)),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}

/// AudioVideoComponents/YoutubeThumbnailComponent.jsx — the app shows the
/// video's thumbnail and opens it in YouTube.
class YoutubeThumbnail extends StatelessWidget {
  const YoutubeThumbnail({super.key, required this.videoUrl});
  final String videoUrl;

  @override
  Widget build(BuildContext context) {
    final id = videoUrl.split('v=').length > 1 ? videoUrl.split('v=')[1].split('&').first : '';
    return Column(children: [
      GestureDetector(
        onTap: () => openExternal('https://www.youtube.com/watch?v=$id'),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(fit: StackFit.expand, children: [
            SiteImage('https://img.youtube.com/vi/$id/hqdefault.jpg', placeholderColor: Colors.black),
            Center(
              child: Container(
                width: 68,
                height: 48,
                decoration: BoxDecoration(color: const Color(0xFFFF0000), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.play_arrow_rounded, size: 36, color: Colors.white),
              ),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 8),
      Text('source: youtube', style: AppText.poppins(size: 14, color: AppColors.gray500)),
    ]);
  }
}

/// HomePoojaComponents/HomePoojaImageBox.jsx
class PoojaImageBox extends StatelessWidget {
  const PoojaImageBox({super.key, required this.name, required this.imageUrl, required this.onTap});
  final String name;
  final String imageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = (name.length > 30 ? name.substring(0, 30) : name).replaceAll('-', ' ') + (name.length > 30 ? '...' : '');
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFF1F1F1))),
        child: Center(
          child: Container(
            width: 204,
            height: 236,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 6, offset: Offset(0, 4))],
            ),
            child: Stack(fit: StackFit.expand, children: [
              SiteImage(imageUrl),
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Color(0xB3000000), Color(0x80000000), Colors.transparent],
                    ),
                  ),
                  child: Text(label, textAlign: TextAlign.center, style: AppText.poppins(size: 14, weight: FontWeight.w600, color: Colors.white)),
                ),
              ),
              const Positioned(
                left: 0,
                top: 0,
                child: SiteImage('/icons/Group6334.svg', width: 48, height: 48, fit: BoxFit.contain, placeholderColor: Colors.transparent),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// components/pagination/UrlPagination.jsx. Its eight 40px squares are wider
/// than a phone card on the website too; here the row scales down to fit.
class _UrlPagination extends StatelessWidget {
  const _UrlPagination({required this.nPages, required this.currentPage, required this.onPageChange});
  final int nPages;
  final int currentPage;
  final ValueChanged<int> onPageChange;

  List<Object> _pages() {
    if (nPages <= 5) return [for (var i = 1; i <= nPages; i++) i];
    if (currentPage <= 3) return [1, 2, 3, 4, '...', nPages];
    if (currentPage >= nPages - 2) return [1, '...', nPages - 3, nPages - 2, nPages - 1, nPages];
    return [1, '...', currentPage - 1, currentPage, currentPage + 1, '...', nPages];
  }

  Widget _square({required Widget child, VoidCallback? onTap, bool active = false, bool disabled = false}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? AppColors.blue600 : (disabled ? AppColors.gray50 : Colors.white),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: active ? AppColors.blue600 : (disabled ? AppColors.gray200 : AppColors.gray300)),
              boxShadow: active ? const [BoxShadow(color: Color(0x0D000000), blurRadius: 2, offset: Offset(0, 1))] : null,
            ),
            child: child,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (nPages <= 1) return const SizedBox.shrink();
    final first = currentPage == 1;
    final last = currentPage == nPages;
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _square(
          disabled: first,
          onTap: first ? null : () => onPageChange(currentPage - 1),
          child: Icon(LucideIcons.chevronLeft, size: 16, color: first ? AppColors.gray400 : AppColors.gray700),
        ),
        for (final p in _pages())
          if (p is String)
            SizedBox(width: 44, height: 40, child: Center(child: Text('...', style: AppText.poppins(size: 16, color: AppColors.gray500))))
          else
            _square(
              active: p == currentPage,
              onTap: p == currentPage ? null : () => onPageChange(p as int),
              child: Text('$p',
                  style: AppText.poppins(size: 14, weight: FontWeight.w500, color: p == currentPage ? Colors.white : AppColors.gray700)),
            ),
        _square(
          disabled: last,
          onTap: last ? null : () => onPageChange(currentPage + 1),
          child: Icon(LucideIcons.chevronRight, size: 16, color: last ? AppColors.gray400 : AppColors.gray700),
        ),
      ]),
    );
  }
}
