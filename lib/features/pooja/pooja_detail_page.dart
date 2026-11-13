import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api/bmp_api.dart';
import '../../core/config.dart';
import '../../core/state/app_state.dart';
import '../../core/storage/cookies.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/format.dart';
import '../../core/utils/json.dart';
import '../../core/utils/launch.dart';
import '../../core/utils/leads.dart';
import '../../core/widgets/fieldset.dart';
import '../../core/widgets/html_content.dart';
import '../../core/widgets/site/site_page.dart';
import '../../core/widgets/site_image.dart';
import '../../core/widgets/toast.dart';
import '../festival/festival_widgets.dart';
import 'inline_checkout.dart';
import 'listing_widgets.dart';
import '../../core/widgets/ui.dart';

/// Everything getServerSideProps resolves for the PDP.
class _PdpData {
  _PdpData({
    this.pooja,
    this.packages,
    this.faqs = const [],
    this.customForm,
    this.languageName = '',
    this.locationName = '',
    this.languageId = '',
    this.locationId = '',
  });

  final Json? pooja;
  final Json? packages;
  final List<Json> faqs;
  final Json? customForm;
  final String languageName;
  final String locationName;
  final String languageId;
  final String locationId;
}

final _pdpProvider = FutureProvider.family<_PdpData, (String, String, String)>((ref, args) async {
  final (slug, language, location) = args;
  final languages = await ref.watch(languagesProvider.future);
  final locations = await ref.watch(locationsProvider.future);
  final lang = languages.where((l) => str(l['languageName']).toLowerCase() == language.toLowerCase()).firstOrNull;
  final loc = locations.where((l) => str(l['locationName']).toLowerCase() == location.toLowerCase()).firstOrNull;
  if (lang == null || loc == null) return _PdpData();
  final languageId = str(lang['_id']);
  final locationId = str(loc['_id']);

  Json? customForm;
  try {
    final f = obj((await BmpApi.customForm('$language/$location/pooja/$slug')).data);
    if (intOf(f['statusCode']) == 200) customForm = obj(f['body']);
  } catch (_) {}

  final pr = obj((await BmpApi.singlePooja(slug, {'language': languageId, 'location': locationId})).data);
  final body = objList(pr['body']);
  if (intOf(pr['statusCode']) != 200 || body.isEmpty) {
    return _PdpData(customForm: customForm, languageName: str(lang['languageName']), locationName: str(loc['locationName']));
  }
  final item = body.first;

  dynamic packageIds = item['packages'];
  try {
    final m = obj((await BmpApi.resolvePoojaPackageMap(str(item['_id']), locationId, languageId)).data);
    if (intOf(m['statusCode']) == 200 && pick(m, ['body', 'packageId']) != null) packageIds = pick(m, ['body', 'packageId']);
  } catch (_) {}

  final isEPooja = str(loc['locationName']) == 'E-Pooja' || location.toLowerCase() == 'e-pooja';
  Json? packages;
  List<Json> faqs = [];
  await Future.wait([
    if (truthy(packageIds))
      BmpApi.poojaPackages(str(packageIds), ePooja: isEPooja).then((r) {
        final d = obj(r.data);
        if (intOf(d['statusCode']) == 200) packages = d;
      }).catchError((_) {}),
    if (list(item['poojaFAQ']).isNotEmpty)
      BmpApi.poojaFaqItems(list(item['poojaFAQ']).map((e) => '$e').toList(), isEPooja: isEPooja).then((r) {
        final d = obj(r.data);
        if (intOf(d['statusCode']) == 200) faqs = objList(d['body']);
      }).catchError((_) {}),
  ]);

  return _PdpData(
    pooja: item,
    packages: packages,
    faqs: faqs,
    customForm: customForm,
    languageName: str(lang['languageName']),
    locationName: str(loc['locationName']),
    languageId: languageId,
    locationId: locationId,
  );
});

/// pages/[language]/[location]/pooja/[slug].jsx
class PoojaDetailPage extends ConsumerStatefulWidget {
  const PoojaDetailPage({super.key, required this.language, required this.location, required this.slug});
  final String language;
  final String location;
  final String slug;

  @override
  ConsumerState<PoojaDetailPage> createState() => _PoojaDetailPageState();
}

class _PoojaDetailPageState extends ConsumerState<PoojaDetailPage> {
  String? _selectedImage;

  Future<void> _wishlist(Json pooja) async {
    final token = Cookies.get('accessToken');
    if (token == null) {
      Toast.show('You are not logged in. Please login to add items to wishlist ');
      return;
    }
    try {
      final r = await BmpApi.addToWishlist({'poojaId': pooja['_id']});
      final d = obj(r.data);
      if (r.statusCode == 201 && intOf(d['statusCode']) == 200) {
        Toast.success(str(d['message']));
      } else {
        Toast.show(str(d['error']));
      }
    } catch (_) {
      Toast.error('Error fetching wishlist API');
    }
  }

  void _share(_PdpData d) {
    final url = '${AppConfig.siteUrl}/${d.languageName}/${d.locationName}/pooja/${str(d.pooja?['slug'])}';
    openExternal('https://wa.me/?text=${Uri.encodeComponent('Hi , I am planning to book this puja $url . Please respond to me on whatsapp here')}');
  }

  Future<void> _bookNow(_PdpData d, String packageType, Json packageData) async {
    if (Cookies.get('accessToken') == null) {
      final ok = await guestLogin(ref);
      if (!ok) {
        Toast.error('Something went wrong. Please try again.');
        return;
      }
    }
    if (!mounted) return;
    openInlineCheckout(
      context,
      bookingPackage: {
        'poojaId': d.pooja!['_id'],
        'packageId': pick(d.packages, ['body', 0, '_id']),
        'packageType': packageType,
        'packageData': packageData,
      },
      poojaData: d.pooja!,
      selectedLocation: d.locationName,
      selectedLanguage: d.languageName,
      selectedLocationId: d.locationId,
      selectedLanguageId: d.languageId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_pdpProvider((widget.slug, widget.language, widget.location)));
    final exp = useFestival(ref, 'pdp', location: widget.location, language: widget.language);
    final d = async.value;
    final loading = async.isLoading && d == null;

    return SitePage(
      pageType: 'pdp',
      city: widget.location,
      language: widget.language,
      bottomBar: const StickyMobileContact(),
      children: [
        if (loading)
          const Padding(padding: EdgeInsets.symmetric(vertical: 120), child: AppSpinner())
        else if (d?.pooja == null)
          const _PoojaNotFound()
        else
          _body(d!, exp),
      ],
    );
  }

  Widget _body(_PdpData d, Json? exp) {
    final p = d.pooja!;
    final media = objList(p['media']);
    final mainImage = _selectedImage ?? (media.isNotEmpty ? str(media.first['mediaUrl']) : '/images/Poojas1.jpg');
    final pkg = obj(pick(d.packages, ['body', 0]));
    final name = str(p['name']).replaceAll('-', ' ');
    final w = MediaQuery.sizeOf(context).width;
    final imageH = w >= 425 ? 420.0 : (w >= 300 ? 330.0 : 300.0);
    const hr = Divider(height: 1, thickness: 1, color: Color(0x4D475569));

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(top: 40),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SizedBox(
            height: imageH,
            child: Stack(fit: StackFit.expand, children: [
              Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: _selectedImage != null ? Colors.black : null,
                  borderRadius: BorderRadius.circular(16),
                  border: _selectedImage == null ? Border.all(color: AppColors.gray200) : null,
                ),
                child: SiteImage(mainImage, fit: _selectedImage != null ? BoxFit.fill : BoxFit.cover),
              ),
              Positioned(
                right: 12,
                bottom: 24,
                child: Column(children: [
                  _glassButton('/icons/whiteHeart.svg', () => _wishlist(p)),
                  const SizedBox(height: 4),
                  _glassButton('/icons/share.svg', () => _share(d)),
                ]),
              ),
            ]),
          ),
        ),
        SizedBox(
          height: 104,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(24, 12, 16, 12),
            itemCount: media.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, i) => GestureDetector(
              onTap: () => setState(() => _selectedImage = str(media[i]['mediaUrl'])),
              child: Container(
                width: 76,
                height: 80,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.gray200)),
                child: SiteImage(str(media[i]['mediaUrl'])),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(name, style: AppText.poppins(size: 20, weight: FontWeight.w500, color: AppColors.defaultText, height: 32 / 20, letterSpacing: .5)),
        ),
        const Padding(padding: EdgeInsets.fromLTRB(24, 8, 24, 8), child: StarRow(rating: 4)),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
          child: Text(str(p['shortDescription']), style: AppText.poppins(size: 14, color: AppColors.defaultText, height: 20 / 14)),
        ),
        if (pkg.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Text('Pooja Packages', style: AppText.poppins(size: 16, weight: FontWeight.w500, color: AppColors.defaultText, height: 28 / 16)),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 48),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final t in const [('basic', 'Basic'), ('standard', 'Standard'), ('premium', 'Premium')])
                if (pkg[t.$1] is Map)
                  PoojaPackageCard(
                    packageData: obj(pkg[t.$1]),
                    packageName: t.$2,
                    onKnowMore: () => showKnowMore(context, obj(pkg[t.$1]), t.$2, p),
                    onBookNow: () => _bookNow(d, t.$1, obj(pkg[t.$1])),
                  ),
            ]),
          ),
        ],
        if (d.customForm != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _Downloads(customForm: d.customForm!),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Looking for a custom package? Click here to tailor your perfect pooja experience!',
                style: AppText.poppins(size: 14, color: AppColors.defaultText, height: 20 / 14)),
            const SizedBox(height: 16),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.bluntRed),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
              onPressed: () => showQuoteModal(context, p),
              child: Text('Get a Quote', style: AppText.poppins(size: 16, weight: FontWeight.w500, color: AppColors.bluntRed)),
            ),
          ]),
        ),
        RelatedFestivalPoojas(experience: exp, currentPoojaSlug: str(p['slug'])),
        hr,
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
          child: Text('Our Promise', style: AppText.poppins(size: 16, weight: FontWeight.w500, color: AppColors.defaultText, height: 28 / 16)),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final pr in const [
              ('/icons/Group7570.svg', 'Experienced Pandits'),
              ('/icons/paper.svg', 'Vedic Standards & Procedures'),
              ('/icons/star.svg', '100% Puja Benefits'),
              ('/icons/Group7565.svg', 'High Quality Samgri'),
              ('/icons/headphone-dummy.svg', 'Professional Guidance and Support'),
              ('/icons/star.svg', 'Guaranteed Punctuality'),
            ])
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: SizedBox(
                  width: 96,
                  child: Column(children: [
                    Container(
                      width: 64,
                      height: 64,
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0x338A1C23))),
                      child: SiteImage(pr.$1, width: 32, height: 32, fit: BoxFit.contain, placeholderColor: Colors.transparent),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(pr.$2,
                          textAlign: TextAlign.center, style: AppText.poppins(size: 10, color: AppColors.defaultText, height: 1.6)),
                    ),
                  ]),
                ),
              ),
          ]),
        ),
        hr,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: PoojaHtml(str(p['description']), textAlign: TextAlign.justify),
        ),
        hr,
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 36, 24, 20),
          child: Text('FAQ (Frequently Asked Questions)',
              style: AppText.poppins(size: 16, weight: FontWeight.w500, color: AppColors.defaultText, height: 28 / 16)),
        ),
        hr,
        if (d.faqs.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 48),
            child: FaqAccordion2(items: d.faqs),
          ),
        hr,
        PoojaReviews(poojaId: str(p['_id'])),
      ]),
    );
  }

  Widget _glassButton(String icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withValues(alpha: .25)),
          alignment: Alignment.center,
          child: SiteImage(icon, width: 24, height: 24, placeholderColor: Colors.transparent),
        ),
      );
}

/// PoojaStarComponent.jsx — five "★" glyphs, gold up to [rating].
class StarRow extends StatelessWidget {
  const StarRow({super.key, required this.rating, this.max = 5});
  final num rating;
  final int max;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 1; i <= max; i++)
          Padding(
            padding: const EdgeInsets.all(4),
            child: Text('★', style: TextStyle(fontSize: 15, color: i <= rating ? const Color(0xFFFFD700) : Colors.grey)),
          ),
      ]);
}

/// PoojaPackageComponent.jsx
class PoojaPackageCard extends StatelessWidget {
  const PoojaPackageCard({
    super.key,
    required this.packageData,
    required this.packageName,
    required this.onKnowMore,
    required this.onBookNow,
  });

  final Json packageData;
  final String packageName;
  final VoidCallback onKnowMore;
  final VoidCallback onBookNow;

  @override
  Widget build(BuildContext context) {
    final bg = switch (packageName) {
      'Basic' => AppColors.orange50,
      'Standard' => AppColors.red50,
      'Premium' => AppColors.red100,
      _ => Colors.white,
    };
    final price = packageData['price'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Stack(clipBehavior: Clip.none, children: [
        Container(
          width: 260,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.red100),
            boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 15, offset: Offset(0, 10), spreadRadius: -3)],
          ),
          child: Stack(clipBehavior: Clip.none, children: [
            const Positioned(
              top: -28,
              right: -36,
              child: SizedBox(width: 80, height: 48, child: SiteImage('/icons/Group6334.svg', placeholderColor: Colors.transparent)),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Container(
                padding: const EdgeInsets.only(bottom: 4, top: 12),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.gray200, style: BorderStyle.solid))),
                child: Row(children: [
                  Expanded(child: Text(packageName, style: AppText.body(size: 14, color: AppColors.gray700, letterSpacing: .4).copyWith(fontFamily: GoogleFonts.lato().fontFamily))),
                  Text('₹ ${truthy(price) ? formatAmountPutComma(price) : 'On Request'}',
                      style: AppText.poppins(size: 16, weight: FontWeight.w700, color: AppColors.bluntRed)),
                ]),
              ),
              const SizedBox(height: 24),
              for (final item in objList(packageData['inclusions'])) ...[
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: Text(str(item['name']), style: AppText.poppins(size: 14, color: AppColors.defaultText))),
                  SiteImage(
                    !item.containsKey('present') || item['present'] == true ? '/icons/tick.svg' : '/icons/cross.svg',
                    width: 20,
                    height: 20,
                    placeholderColor: Colors.transparent,
                  ),
                ]),
                const SizedBox(height: 16),
              ],
              _kv('Number Of Days', str(packageData['numberOfDays'])),
              const SizedBox(height: 16),
              _kv('Number Of Pandits', str(packageData['numberOfPandits'])),
              const SizedBox(height: 16),
              const Divider(height: 1),
              GestureDetector(
                onTap: onKnowMore,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                  child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Text('Know More', style: AppText.poppins(size: 12, weight: FontWeight.w500, color: AppColors.bluntRed)),
                    const SizedBox(width: 8),
                    const SiteImage('/icons/knowMoreArrow.svg', width: 16, height: 16, placeholderColor: Colors.transparent),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              _BookNowButton(onTap: onBookNow),
            ]),
          ]),
        ),
        const Positioned(
          top: -20,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Center(child: SiteImage('/icons/Group6903.svg', width: 112, height: 48, fit: BoxFit.contain, placeholderColor: Colors.transparent)),
          ),
        ),
      ]),
    );
  }

  Widget _kv(String k, String v) => Row(children: [
        Expanded(child: Text(k, style: AppText.poppins(size: 14, color: AppColors.defaultText))),
        Text(v, style: AppText.poppins(size: 14, color: AppColors.defaultText)),
      ]);
}

/// "Book Now" with the ping overlay and bouncing Zap icon.
class _BookNowButton extends StatefulWidget {
  const _BookNowButton({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_BookNowButton> createState() => _BookNowButtonState();
}

class _BookNowButtonState extends State<_BookNowButton> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        height: 44,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.bluntRed,
          borderRadius: BorderRadius.circular(6),
          boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 15, offset: Offset(0, 10), spreadRadius: -3)],
        ),
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) {
            final t = _c.value;
            final bounce = t < .5 ? -4 * (1 - (t * 2 - .5).abs() * 2).clamp(0, 1) : 0.0;
            return Stack(alignment: Alignment.center, children: [
              Positioned.fill(
                child: Transform.scale(
                  scale: 1 + t,
                  child: Container(color: const Color(0xFF991B1B).withValues(alpha: .2 * (1 - t))),
                ),
              ),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Transform.translate(offset: Offset(0, bounce.toDouble()), child: const Icon(LucideIcons.zap, size: 16, color: Colors.white)),
                const SizedBox(width: 8),
                Text('Book Now', style: AppText.poppins(size: 14, weight: FontWeight.w600, color: Colors.white)),
              ]),
            ]);
          },
        ),
      ),
    );
  }
}

/// productComponent/KnowMoreModal.jsx — slides up from the bottom on phones.
void showKnowMore(BuildContext context, Json pkg, String name, Json pooja) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: .5),
    builder: (ctx) {
      final h = MediaQuery.sizeOf(ctx).height;
      return Container(
        height: h - MediaQuery.paddingOf(ctx).top - 24,
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        child: Stack(children: [
          ListView(padding: const EdgeInsets.only(top: 8, bottom: 32), children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 48, 56, 16),
              child: Text(str(pooja['name']),
                  style: AppText.poppins(size: 20, weight: FontWeight.w500, color: AppColors.defaultText, height: 1.6, letterSpacing: 1)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: AppText.poppins(size: 16, weight: FontWeight.w500, color: const Color(0xFFB74502))),
                const SizedBox(height: 4),
                Text('₹ ${truthy(pkg['price']) ? formatAmountPutComma(pkg['price']) : 'On Request'}',
                    style: AppText.poppins(size: 24, weight: FontWeight.w500, color: AppColors.defaultText)),
                const SizedBox(height: 28),
                Text('Inclusions-1', style: AppText.poppins(size: 14, weight: FontWeight.w500, color: AppColors.defaultText)),
                const SizedBox(height: 8),
                for (final item in objList(pkg['inclusions']))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(children: [
                      SiteImage(
                        !item.containsKey('present') || item['present'] == true ? '/icons/tick.svg' : '/icons/cross.svg',
                        width: 20,
                        height: 20,
                        placeholderColor: Colors.transparent,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(str(item['name']), style: AppText.poppins(size: 12, color: AppColors.defaultText))),
                    ]),
                  ),
                SizedBox(
                  width: 200,
                  child: Column(children: [
                    if (truthy(pkg['numberOfDays'])) _bold('No of Days:', str(pkg['numberOfDays'])),
                    if (truthy(pkg['numberOfPandits'])) _bold('No of Pandits:', str(pkg['numberOfPandits'])),
                  ]),
                ),
                const SizedBox(height: 16),
                if (truthy(pkg['note']))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Text('Note :  ${str(pkg['note'])}',
                        style: AppText.poppins(size: 20, weight: FontWeight.w700, color: AppColors.bluntRed, letterSpacing: 1)),
                  ),
                for (final item in objList(pkg['description']))
                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: const Color(0x66CBD5E1), borderRadius: BorderRadius.circular(8)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        if (truthy(item['procedureName']))
                          Expanded(
                            child: Text(str(item['procedureName']),
                                style: AppText.poppins(size: 14, weight: FontWeight.w500, color: AppColors.defaultText)),
                          )
                        else
                          const Spacer(),
                        if (truthy(item['duration']))
                          Text.rich(
                            TextSpan(children: [
                              const TextSpan(text: 'Duration ', style: TextStyle(color: AppColors.bluntRed)),
                              TextSpan(text: str(item['duration'])),
                            ]),
                            style: AppText.poppins(size: 12, weight: FontWeight.w500, color: AppColors.defaultText),
                          ),
                      ]),
                      if (truthy(item['shortDescription']))
                        Padding(
                          padding: const EdgeInsets.only(top: 2, bottom: 8),
                          child: Text(str(item['shortDescription']), style: AppText.poppins(size: 14, color: const Color(0xFFB74502))),
                        ),
                      if (truthy(item['longDescription'])) PoojaHtml(str(item['longDescription']), fontSize: 12),
                    ]),
                  ),
              ]),
            ),
          ]),
          Positioned(
            top: 16,
            right: 16,
            child: GestureDetector(
              onTap: () => Navigator.of(ctx).pop(),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.slate100,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.slate200),
                  boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 6, offset: Offset(0, 4))],
                ),
                alignment: Alignment.center,
                child: const SiteImage('/icons/CancelDesktop.svg', width: 14, height: 14, fit: BoxFit.contain, placeholderColor: Colors.transparent),
              ),
            ),
          ),
        ]),
      );
    },
  );
}

Widget _bold(String k, String v) => Padding(
      padding: const EdgeInsets.only(bottom: 8, right: 4),
      child: Row(children: [
        Expanded(child: Text(k, style: AppText.poppins(size: 12, weight: FontWeight.w600, color: AppColors.defaultText))),
        Text(v, style: AppText.poppins(size: 12, weight: FontWeight.w600, color: AppColors.defaultText)),
      ]),
    );

/// CommonComponent/Accordian2.jsx — bordered FAQ cards, one open at a time.
class FaqAccordion2 extends StatefulWidget {
  const FaqAccordion2({super.key, required this.items, this.questionKey = 'question', this.answerKey = 'answer'});
  final List<Json> items;
  final String questionKey;
  final String answerKey;

  @override
  State<FaqAccordion2> createState() => _FaqAccordion2State();
}

class _FaqAccordion2State extends State<FaqAccordion2> {
  int? _open;

  @override
  Widget build(BuildContext context) {
    const border = Color(0x4D475569);
    return Column(children: [
      for (var i = 0; i < widget.items.length; i++) ...[
        GestureDetector(
          onTap: () => setState(() => _open = _open == i ? null : i),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _open == i ? const Color(0x40CBD5E1) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: border),
            ),
            child: Row(children: [
              Expanded(
                child: Text(str(widget.items[i][widget.questionKey]),
                    style: AppText.poppins(size: 16, color: AppColors.defaultText)),
              ),
              AnimatedRotation(
                turns: _open == i ? .5 : 0,
                duration: const Duration(milliseconds: 250),
                child: const SiteImage('/icons/down-arrow-gray.svg', width: 16, height: 16, placeholderColor: Colors.transparent),
              ),
            ]),
          ),
        ),
        if (_open == i)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: border)),
            child: PoojaHtml(str(widget.items[i][widget.answerKey]), textAlign: TextAlign.justify),
          ),
        const SizedBox(height: 16),
      ],
    ]);
  }
}

/// components/Reviews/PoojaReview.jsx
class PoojaReviews extends StatefulWidget {
  const PoojaReviews({super.key, required this.poojaId});
  final String poojaId;

  @override
  State<PoojaReviews> createState() => _PoojaReviewsState();
}

class _PoojaReviewsState extends State<PoojaReviews> {
  static const _perPage = 3;
  bool _loading = true;
  bool _error = false;
  Json _reviews = {};
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await BmpApi.poojaReviews(widget.poojaId, _page, _perPage);
      final d = obj(r.data);
      if (r.statusCode == 200 && intOf(d['statusCode']) == 200 && d['body'] is List) {
        _reviews = d;
      } else {
        _error = true;
      }
    } catch (_) {
      _error = true;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return Text('Loading...', style: AppText.poppins());
    final body = objList(_reviews['body']);
    final total = intOf(_reviews['totalCount']);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Reviews', style: AppText.poppins(size: 16, weight: FontWeight.w500, color: AppColors.defaultText, letterSpacing: .4)),
        if (body.isNotEmpty) ...[
          Row(children: [
            const StarRow(rating: 3),
            const SizedBox(width: 16),
            Text.rich(
              TextSpan(children: [
                const TextSpan(text: 'reviews '),
                TextSpan(text: '$total', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.defaultText)),
              ]),
              style: AppText.poppins(size: 12, color: AppColors.slate400),
            ),
          ]),
          for (final r in body)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  list(r['user']).isNotEmpty ? str(obj(list(r['user']).first)['userName']) : 'User',
                  style: AppText.poppins(size: 14, weight: FontWeight.w500, color: AppColors.defaultText),
                ),
                Row(children: [
                  Text(
                    'Reviewed on ${DateTime.tryParse(str(r['createdAt'])) == null ? '' : DateFormat('dd/MM/yyyy').format(DateTime.parse(str(r['createdAt'])).toLocal())}',
                    style: AppText.poppins(size: 12, color: AppColors.defaultText, height: 2),
                  ),
                  const SizedBox(width: 16),
                  const StarRow(rating: 3),
                ]),
                Text(str(r['comment']), textAlign: TextAlign.justify, style: AppText.poppins(size: 14, color: AppColors.defaultText)),
              ]),
            ),
          PaginationBar(
            nPages: (total / _perPage).ceil(),
            currentPage: _page,
            onPageChange: (p) {
              setState(() {
                _page = p;
                _loading = true;
              });
              _load();
            },
          ),
        ] else if (_error)
          Text('No reviews available', style: AppText.poppins()),
      ]),
    );
  }
}

/// DownloadbleConten/DownloadableComponent.jsx + BlogModalComponent lead form.
class _Downloads extends ConsumerWidget {
  const _Downloads({required this.customForm});
  final Json customForm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloads = objList(customForm['downlodableContentLink']);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gray200),
        boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 15, offset: Offset(0, 10), spreadRadius: -3)],
      ),
      child: Column(children: [
        Text('Download Pooja Guides', style: AppText.poppins(size: 18, weight: FontWeight.w600, color: AppColors.gray800)),
        Text('Get detailed guides for various Poojas.', style: AppText.poppins(size: 14, color: AppColors.gray600)),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (ctx, c) {
          final w = downloads.length == 1 ? c.maxWidth : (c.maxWidth - 8) / 2;
          return Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
            for (final f in downloads)
              SizedBox(
                width: w,
                child: Material(
                  color: AppColors.bluntRed,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _onDownload(context, ref, f),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(LucideIcons.download, size: 18, color: Colors.white),
                        const SizedBox(width: 8),
                        Flexible(child: Text(str(f['title']), style: AppText.poppins(size: 14, color: Colors.white))),
                      ]),
                    ),
                  ),
                ),
              ),
          ]);
        }),
      ]),
    );
  }

  static String? fileBuilder(dynamic source) {
    final ref = str(pick(source, ['asset', '_ref']));
    final m = RegExp(r'^file-([a-zA-Z0-9]+)-(.+)$').firstMatch(ref);
    if (m == null) return null;
    return 'https://cdn.sanity.io/files/${AppConfig.sanityProjectId}/production/${m.group(1)}.${m.group(2)}';
  }

  Future<void> _onDownload(BuildContext context, WidgetRef ref, Json item) async {
    final link = fileBuilder(item['File']);
    final fields = transformFields(objList(customForm['fields']));
    if (Cookies.get('accessToken') == null) {
      await showLeadDownloadForm(context, fields: fields, onSubmit: (form) => _submit(context, ref, form, link));
    } else {
      await _submit(context, ref, {for (final k in fields.keys) k: ''}, link);
    }
  }

  Future<bool> _submit(BuildContext context, WidgetRef ref, Map<String, String> form, String? link) async {
    try {
      final user = ref.read(authProvider).value;
      final r = await BmpApi.postEnquiry({
        'phone': str(user?['phone']),
        'unstructuredData': jsonEncode(form.map((k, v) => MapEntry(k, {'value': v}))),
        'leadType': 1, // FOR BLOGS IT HAS TO BE 1
        'referenceFrom': GoRouterState.of(context).uri.path,
      });
      final d = obj(r.data);
      if (r.statusCode == 201 && intOf(d['statusCode']) == 200) {
        if (link != null) openExternal(link);
        return true;
      }
      Toast.error(str(d['message'], 'Something went wrong'));
    } catch (_) {
      Toast.error('Error posting pooja leads. Please try again later.');
    }
    return false;
  }
}

/// BlogModalComponent.jsx — CMS-defined fields + "Download".
Future<void> showLeadDownloadForm(
  BuildContext context, {
  required Map<String, Json> fields,
  required Future<bool> Function(Map<String, String>) onSubmit,
}) {
  final values = {for (final k in fields.keys) k: ''};
  return showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: .5),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) {
        final valid = values.values.every((v) => v.isNotEmpty);
        return Dialog(
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Align(
                alignment: Alignment.topRight,
                child: GestureDetector(onTap: () => Navigator.of(ctx).pop(), child: const Text('✖', style: TextStyle(color: AppColors.gray500))),
              ),
              const SiteImage('/icons/book-my-pooja.svg', width: 192, height: 96, fit: BoxFit.contain, placeholderColor: Colors.transparent),
              const Divider(),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * .6),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    for (final e in fields.entries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: DynamicFormField(
                          spec: e.value,
                          value: values[e.key]!,
                          onChanged: (v) => setLocal(() => values[e.key] = v),
                        ),
                      ),
                  ]),
                ),
              ),
              const Divider(),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: Material(
                  color: valid ? AppColors.bluntRed : AppColors.gray300,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    onTap: valid
                        ? () async {
                            final ok = await onSubmit(values);
                            if (ok && ctx.mounted) Navigator.of(ctx).pop();
                          }
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Download',
                          textAlign: TextAlign.center,
                          style: AppText.poppins(size: 14, color: valid ? Colors.white : AppColors.defaultText, letterSpacing: .6)),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        );
      },
    ),
  );
}

/// modalcomponent/MainModal.jsx — "Pooja Query" (Get a Quote).
Future<void> showQuoteModal(BuildContext context, Json pooja) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: .5),
    builder: (ctx) => _QuoteModal(pooja: pooja),
  );
}

class _QuoteModal extends StatefulWidget {
  const _QuoteModal({required this.pooja});
  final Json pooja;

  @override
  State<_QuoteModal> createState() => _QuoteModalState();
}

class _QuoteModalState extends State<_QuoteModal> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _notes = TextEditingController();
  Map<String, String> _errors = {};
  bool _submitting = false;

  bool get _loggedIn => Cookies.get('accessToken') != null;

  bool _validate() {
    final e = <String, String>{};
    if (!_loggedIn) {
      if (_name.text.trim().isEmpty) e['name'] = 'Name is required';
      if (_phone.text.trim().isEmpty) {
        e['phone'] = 'Phone number is required';
      } else if (!RegExp(r'^\d{10}$').hasMatch(_phone.text)) {
        e['phone'] = 'Please enter a valid 10-digit phone number';
      }
    }
    if (_notes.text.trim().isEmpty) e['notes'] = 'Please add your comments';
    if (_email.text.trim().isNotEmpty &&
        !RegExp(r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*$").hasMatch(_email.text)) {
      e['email'] = 'Please enter a valid email address';
    }
    setState(() => _errors = e);
    return e.isEmpty;
  }

  Future<void> _submit() async {
    if (!_validate()) {
      Toast.error('Please fix the errors below');
      return;
    }
    setState(() => _submitting = true);
    try {
      final payload = createCrmLeadEnquiryBody({
        'pujaType': str(widget.pooja['name']),
        'name': _name.text,
        'phone': _phone.text,
        'email': _email.text,
        'notes': _notes.text,
        'enquiry': _notes.text,
      });
      await BmpApi.postGlobalLeadCapture({...payload, 'source': 'Website-Pooja', 'webPageLink': AppConfig.siteUrl});
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) Navigator.of(context).pop();
      Toast.show('Your enquiry has been submitted successfully!');
    } catch (_) {
      Toast.error('Failed to submit request. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _field(String label, TextEditingController c, String hint, String key,
      {TextInputType? type, int lines = 1, int? maxLength}) {
    final err = _errors[key];
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: AppText.poppins(size: 12, color: AppColors.gray600)),
        const SizedBox(height: 4),
        TextField(
          controller: c,
          keyboardType: type,
          minLines: lines,
          maxLines: lines,
          maxLength: maxLength,
          onChanged: (v) {
            if (key == 'phone') {
              final dgt = v.replaceAll(RegExp(r'\D'), '');
              if (dgt != v) c.text = dgt;
            }
            if (_errors[key] != null) setState(() => _errors.remove(key));
          },
          style: AppText.poppins(size: 16),
          decoration: InputDecoration(
            hintText: hint,
            counterText: '',
            hintStyle: AppText.poppins(size: 16, color: AppColors.gray400),
            filled: false,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: err != null ? AppColors.red500 : AppColors.gray300)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.red500, width: 2)),
          ),
        ),
        if (err != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(err, style: AppText.poppins(size: 12, color: AppColors.red500))),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final media = strOrNull(pick(widget.pooja, ['media', 0, 'mediaUrl']));
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: mq.size.height * .9),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Expanded(child: Text('Pooja Query', style: AppText.poppins(size: 16, weight: FontWeight.w500, color: Colors.black))),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: const SiteImage('/icons/Cancelbutton.svg', width: 20, height: 20, placeholderColor: Colors.transparent),
              ),
            ]),
          ),
          const Divider(height: 1, color: AppColors.gray300),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppColors.gray50, borderRadius: BorderRadius.circular(12)),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 48,
                      height: 48,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(color: AppColors.gray200, borderRadius: BorderRadius.circular(6)),
                      child: SiteImage(media ?? '/placeholder-pooja.jpg'),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(str(widget.pooja['name'], 'Pooja Name'),
                            style: AppText.poppins(size: 14, weight: FontWeight.w500, color: Colors.black)),
                        const SizedBox(height: 4),
                        Text(str(widget.pooja['shortDescription'], 'Pooja description'),
                            maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.poppins(size: 12, color: AppColors.gray600)),
                      ]),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),
                _field('Full Name *', _name, 'Enter your full name', 'name'),
                _field('Mobile Number *', _phone, 'Enter 10-digit mobile number', 'phone', type: TextInputType.phone, maxLength: 10),
                _field('Email (Optional)', _email, 'Enter your email address', 'email', type: TextInputType.emailAddress),
                _field('Your Comments *', _notes, 'Please share your requirements...', 'notes', lines: 4),
              ]),
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + mq.padding.bottom),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.gray300))),
            child: Align(
              alignment: Alignment.centerRight,
              child: Material(
                color: _submitting ? AppColors.gray400 : AppColors.bluntRed,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _submitting ? null : _submit,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: Text(_submitting ? 'Submitting...' : 'Submit',
                        style: AppText.poppins(size: 16, weight: FontWeight.w500, color: Colors.white)),
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// ErrorComponent/PoojaNotFound.jsx
class _PoojaNotFound extends StatelessWidget {
  const _PoojaNotFound();

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: BoxConstraints(minHeight: MediaQuery.sizeOf(context).height),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('404', style: AppText.poppins(size: 72, weight: FontWeight.w700, color: const Color(0xFFBD7D81))),
            const SizedBox(height: 8),
            const SiteImage('/icons/book-my-pooja.svg', width: 128, height: 96, fit: BoxFit.contain, placeholderColor: Colors.transparent),
            const SizedBox(height: 24),
            Text('No Poojas Found', style: AppText.poppins(size: 24, weight: FontWeight.w700)),
            const SizedBox(height: 16),
            FractionallySizedBox(
              widthFactor: .75,
              child: Text(
                'This Pooja is not available for the selected language and location combination.\nPlease try selecting different language',
                textAlign: TextAlign.center,
                style: AppText.poppins(size: 18, color: AppColors.gray600),
              ),
            ),
            const SizedBox(height: 16),
            Text("Let's guide you back to the main shrine",
                textAlign: TextAlign.center, style: AppText.poppins(size: 18, color: AppColors.bluntRed)),
            const SizedBox(height: 40),
            GestureDetector(
              onTap: () => context.go('/'),
              child: Text('Return Home',
                  style: AppText.poppins(size: 20, color: const Color(0xFF8A1D23)).copyWith(decoration: TextDecoration.underline)),
            ),
          ]),
        ),
      );
}
