import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/format.dart';
import '../../core/utils/json.dart';
import '../../core/utils/launch.dart';
import '../../core/utils/ritual_steps.dart';
import '../../core/widgets/brand_icons.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/site_image.dart';
import '../festival/ornaments.dart';

/// Pooja detail page pieces ported from bmp_fe components/PoojaComponent/
/// (PoojaGallery, RitualTimeline, PdpStickyBookBar, RecentBookingToast).

const pdpCream = Color(0xFFFFF8EE);
const pdpInk = Color(0xFF2B1A14);
const pdpMutedInk = Color(0xFF7A4A3A);

// ---------------------------------------------------------------------------
// PoojaGallery.jsx — warm photo stage
// ---------------------------------------------------------------------------

class PoojaGallery extends StatefulWidget {
  const PoojaGallery({super.key, required this.media, required this.onWishlist, required this.onShare});
  final List<Json> media;
  final VoidCallback onWishlist;
  final VoidCallback onShare;

  @override
  State<PoojaGallery> createState() => _PoojaGalleryState();
}

class _PoojaGalleryState extends State<PoojaGallery> with SingleTickerProviderStateMixin {
  int _index = 0;
  late final AnimationController _spin = AnimationController(vsync: this, duration: const Duration(seconds: 90));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _spin.stop();
    } else if (!_spin.isAnimating) {
      _spin.repeat();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  String get _current => widget.media.isEmpty
      ? '/images/Poojas1.jpg'
      : str(widget.media[_index.clamp(0, widget.media.length - 1)]['mediaUrl']);

  @override
  Widget build(BuildContext context) {
    final media = widget.media;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AspectRatio(
        aspectRatio: 1,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFF3D9B1)),
            gradient: const RadialGradient(
              center: Alignment(0, .1),
              radius: .9,
              colors: [Color(0xFFFFFBF3), Color(0xFFFDE7C4), Color(0xFFF9C98A)],
              stops: [0, .6, 1],
            ),
            boxShadow: const [BoxShadow(color: Color(0x33B4541A), blurRadius: 30, offset: Offset(0, 14), spreadRadius: -12)],
          ),
          child: Stack(fit: StackFit.expand, children: [
            // Faint, slowly turning mandala behind the photo.
            Center(
              child: RotationTransition(
                turns: _spin,
                child: const MandalaWatermark(size: 340, color: Color(0xFFB4541A), opacity: .08),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 28, 22, 40),
              child: AnimatedSwitcher(
                duration: reduceMotion(context) ? Duration.zero : const Duration(milliseconds: 350),
                child: ClipRRect(
                  key: ValueKey(_current),
                  borderRadius: BorderRadius.circular(12),
                  child: SiteImage(_current, fit: BoxFit.contain, placeholderColor: Colors.transparent),
                ),
              ),
            ),
            const Positioned(top: 0, left: 0, right: 0, child: IgnorePointer(child: ToranGarland(height: 18))),
            const Positioned(left: 10, bottom: 8, child: IgnorePointer(child: DiyaIcon(size: 30))),
            const Positioned(right: 10, bottom: 8, child: IgnorePointer(child: DiyaIcon(size: 30))),
            Positioned(
              right: 12,
              top: 30,
              child: Column(children: [
                _PopButton(icon: LucideIcons.heart, label: 'Add to wishlist', onTap: widget.onWishlist),
                const SizedBox(height: 8),
                _PopButton(icon: LucideIcons.share2, label: 'Share', onTap: widget.onShare),
              ]),
            ),
          ]),
        ),
      ),
      if (media.length > 1)
        SizedBox(
          height: 84,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: media.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final on = i == _index;
              return GestureDetector(
                onTap: () => setState(() => _index = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 60,
                  height: 60,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: on ? AppColors.bluntRed : AppColors.gray200, width: on ? 2 : 1),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: SiteImage(str(media[i]['mediaUrl']), fit: BoxFit.cover),
                  ),
                ),
              );
            },
          ),
        ),
    ]);
  }
}

/// Round white button on the photo; the icon pops when tapped.
class _PopButton extends StatefulWidget {
  const _PopButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  State<_PopButton> createState() => _PopButtonState();
}

class _PopButtonState extends State<_PopButton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: widget.label,
        child: GestureDetector(
          onTap: () {
            if (!reduceMotion(context)) _c.forward(from: 0);
            widget.onTap();
          },
          child: Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xE6FFFFFF),
              boxShadow: [BoxShadow(color: Color(0x26000000), blurRadius: 8, offset: Offset(0, 3))],
            ),
            alignment: Alignment.center,
            child: ScaleTransition(
              scale: TweenSequence([
                TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 40),
                TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 60),
              ]).animate(CurvedAnimation(parent: _c, curve: Curves.easeOut)),
              child: Icon(widget.icon, size: 18, color: AppColors.bluntRed),
            ),
          ),
        ),
      );
}

// ---------------------------------------------------------------------------
// Title chips: From ₹X · {Language} pandit · {City}
// ---------------------------------------------------------------------------

class PdpFactChips extends StatelessWidget {
  const PdpFactChips({super.key, required this.fromPrice, required this.language, required this.city});
  final num? fromPrice;
  final String language;
  final String city;

  @override
  Widget build(BuildContext context) {
    Widget chip(IconData icon, String label, {bool strong = false}) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: strong ? const Color(0xFFFDF1E0) : Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFF0D9B5)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 13, color: AppColors.bluntRed),
            const SizedBox(width: 5),
            Text(label,
                style: AppText.body(size: 12, weight: strong ? FontWeight.w700 : FontWeight.w600, color: strong ? AppColors.bluntRed : pdpInk)),
          ]),
        );
    return Wrap(spacing: 8, runSpacing: 8, children: [
      if (fromPrice != null && fromPrice! > 0) chip(LucideIcons.indianRupee, 'From ₹${formatAmountPutComma(fromPrice)}', strong: true),
      if (language.isNotEmpty) chip(LucideIcons.languages, '${titleCaseWords(language)} pandit'),
      if (city.isNotEmpty) chip(LucideIcons.mapPin, titleCaseWords(city)),
    ]);
  }
}

String titleCaseWords(String s) =>
    s.replaceAll('-', ' ').replaceAllMapped(RegExp(r'\b\w'), (m) => m.group(0)!.toUpperCase());

/// Lowest non-zero package price (basic / standard / premium).
num? lowestPackagePrice(Json pkg) {
  final prices = <num>[];
  for (final k in const ['basic', 'standard', 'premium']) {
    final v = pkg[k] is Map ? obj(pkg[k])['price'] : null;
    final n = v is num ? v : num.tryParse('${v ?? ''}'.replaceAll(',', ''));
    if (n != null && n > 0) prices.add(n);
  }
  if (prices.isEmpty) return null;
  prices.sort();
  return prices.first;
}

// ---------------------------------------------------------------------------
// RitualTimeline.jsx — "What happens during {pooja}"
// ---------------------------------------------------------------------------

class RitualTimeline extends StatelessWidget {
  const RitualTimeline({super.key, required this.steps, required this.poojaName});
  final List<RitualStep> steps;
  final String poojaName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [pdpCream, Color(0xFFFDEBD3)]),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('PUJA VIDHI', style: AppText.body(size: 12, weight: FontWeight.w700, color: const Color(0xFFB4541A), letterSpacing: 2.2)),
        const SizedBox(height: 4),
        Semantics(
          header: true,
          child: Text('What happens during ${poojaName.isEmpty ? 'the puja' : poojaName}',
              style: AppText.heading(size: 20, color: AppColors.defaultText)),
        ),
        const SizedBox(height: 24),
        Stack(children: [
          // Connecting thread behind the markers.
          Positioned(
            left: 17,
            top: 16,
            bottom: 16,
            child: Container(
              width: 2,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFBBF24), Color(0xFFFDBA74), Color(0xFFFDE68A)],
                ),
              ),
            ),
          ),
          Column(children: [
            for (var i = 0; i < steps.length; i++)
              Padding(
                padding: EdgeInsets.only(bottom: i == steps.length - 1 ? 0 : 20),
                child: _StepRow(n: i + 1, step: steps[i]),
              ),
          ]),
        ]),
      ]),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.n, required this.step});
  final int n;
  final RitualStep step;

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: Alignment(-.3, -.4),
            colors: [Color(0xFFFCD34D), Color(0xFFF59E0B), Color(0xFFEA580C)],
            stops: [0, .55, 1],
          ),
          boxShadow: [
            BoxShadow(color: pdpCream, spreadRadius: 4),
            BoxShadow(color: Color(0xCCC2410C), blurRadius: 14, offset: Offset(0, 6), spreadRadius: -6),
          ],
        ),
        child: Text('$n', style: AppText.body(size: 14, weight: FontWeight.w700, color: const Color(0xFF5A1A0C))),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (step.title.isNotEmpty) ...[
              Text(step.title, style: AppText.body(size: 15, weight: FontWeight.w600, color: pdpInk, height: 1.35)),
              if (step.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(step.text, style: AppText.body(size: 14, color: const Color(0xFF6B4A3C), height: 1.55)),
                ),
            ] else
              Text(step.text, style: AppText.body(size: 15, color: pdpInk, height: 1.35)),
            if (step.sub.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final s in step.sub)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xCCFFFFFF),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0xFFFED7AA)),
                      ),
                      child: Text('🔥 ${s.title.isNotEmpty ? s.title : s.text}',
                          style: AppText.body(size: 12, weight: FontWeight.w600, color: AppColors.bluntRed)),
                    ),
                ]),
              ),
          ]),
        ),
      ),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Our Promise — tiles on a cream panel
// ---------------------------------------------------------------------------

class PromiseGrid extends StatelessWidget {
  const PromiseGrid({super.key});

  static const items = [
    ('/icons/Group7570.svg', 'Experienced Pandits'),
    ('/icons/paper.svg', 'Vedic Standards & Procedures'),
    ('/icons/star.svg', '100% Puja Benefits'),
    ('/icons/Group7565.svg', 'High Quality Samagri'),
    ('/icons/headphone-dummy.svg', 'Professional Guidance and Support'),
    ('/icons/star.svg', 'Guaranteed Punctuality'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: pdpCream, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFF3E3C8))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Semantics(
          header: true,
          child: Text('Our Promise', style: AppText.heading(size: 20, color: AppColors.defaultText)),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(builder: (ctx, c) {
          final cols = c.maxWidth >= 520 ? 3 : 2;
          final w = (c.maxWidth - 10 * (cols - 1)) / cols;
          return Wrap(spacing: 10, runSpacing: 10, children: [
            for (final p in items)
              Container(
                width: w,
                constraints: const BoxConstraints(minHeight: 64),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFF3E3C8)),
                ),
                child: Row(children: [
                  Container(
                    width: 38,
                    height: 38,
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFDF1E0)),
                    child: SiteImage(p.$1, fit: BoxFit.contain, placeholderColor: Colors.transparent),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(p.$2, style: AppText.body(size: 12.5, weight: FontWeight.w600, color: pdpInk, height: 1.3)),
                  ),
                ]),
              ),
          ]);
        }),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// PdpStickyBookBar.jsx — mobile bottom booking bar
// ---------------------------------------------------------------------------

class PdpStickyBookBar extends StatelessWidget {
  const PdpStickyBookBar({
    super.key,
    required this.startingPrice,
    required this.poojaName,
    required this.hidden,
    required this.onBookNow,
    required this.pageReference,
  });

  final num? startingPrice;
  final String poojaName;
  final bool hidden;
  final VoidCallback onBookNow;
  final String pageReference;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final dur = reduceMotion(context) ? Duration.zero : const Duration(milliseconds: 300);
    // Slides down and collapses its slot, so no empty strip is left behind.
    return ClipRect(
      child: AnimatedAlign(
        alignment: Alignment.topCenter,
        heightFactor: hidden ? 0 : 1,
        duration: dur,
        curve: Curves.easeOut,
        child: _bar(context, bottom, dur),
      ),
    );
  }

  Widget _bar(BuildContext context, double bottom, Duration dur) {
    return AnimatedSlide(
      offset: hidden ? const Offset(0, 1) : Offset.zero,
      duration: dur,
      curve: Curves.easeOut,
      child: IgnorePointer(
        ignoring: hidden,
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xF2FFFFFF),
            border: Border(top: BorderSide(color: Color(0xFFFEF3C7))),
            boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 30, offset: Offset(0, -10))],
          ),
          padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + bottom),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text('Starting from', style: AppText.body(size: 11, weight: FontWeight.w500, color: AppColors.gray500, height: 1.2)),
                Text(
                  startingPrice != null && startingPrice! > 0 ? '₹${formatAmountPutComma(startingPrice)}' : 'On request',
                  style: AppText.body(size: 18, weight: FontWeight.w700, color: AppColors.bluntRed, height: 1.2),
                ),
              ]),
            ),
            _circle(
              label: 'Call Puja Seva team',
              onTap: () => callPhone(),
              color: Colors.white,
              border: AppColors.gray200,
              child: const Icon(LucideIcons.phone, size: 20, color: AppColors.bluntRed),
            ),
            const SizedBox(width: 8),
            _circle(
              label: 'Ask on WhatsApp',
              onTap: () => openWhatsApp(
                  'Namaste BookMyPooja 🙏 I have a question about ${poojaName.isEmpty ? 'a puja' : poojaName}.\n\n$pageReference'),
              color: AppColors.whatsappBrand,
              child: const WhatsAppIcon(size: 20),
            ),
            const SizedBox(width: 8),
            PressScale(
              scale: .95,
              onTap: onBookNow,
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.bluntRed,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [BoxShadow(color: Color(0xCC8A1C23), blurRadius: 20, offset: Offset(0, 8), spreadRadius: -8)],
                ),
                child: Text('Book Now', style: AppText.body(size: 14, weight: FontWeight.w700, color: Colors.white)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _circle({required String label, required VoidCallback onTap, required Color color, Color? border, required Widget child}) =>
      Semantics(
        button: true,
        label: label,
        child: PressScale(
          scale: .95,
          onTap: onTap,
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: border == null ? null : Border.all(color: border)),
            child: child,
          ),
        ),
      );
}

// ---------------------------------------------------------------------------
// RecentBookingToast.jsx
// ---------------------------------------------------------------------------

/// Session flag: the visitor closed the recently-booked toast.
bool recentBookingDismissed = false;

class RecentBookingToast extends StatefulWidget {
  const RecentBookingToast({super.key, required this.latestOrders, required this.paused});
  final List<Json> latestOrders;

  /// True while a popup/sheet is open over the page.
  final bool Function() paused;

  @override
  State<RecentBookingToast> createState() => _RecentBookingToastState();
}

class _RecentBookingToastState extends State<RecentBookingToast> {
  static const _firstDelay = Duration(seconds: 20);
  static const _show = Duration(seconds: 6);
  static const _gap = Duration(seconds: 25);

  Timer? _first;
  Timer? _loop;
  Timer? _hide;
  int _index = 0;
  Json? _current;
  bool _visible = false;
  late final AppLifecycleListener _life;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    _life = AppLifecycleListener(onStateChange: (s) => _foreground = s == AppLifecycleState.resumed);
    _start();
  }

  @override
  void didUpdateWidget(covariant RecentBookingToast oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.latestOrders.isEmpty && widget.latestOrders.isNotEmpty) _start();
  }

  void _start() {
    if (recentBookingDismissed || widget.latestOrders.isEmpty || _first != null) return;
    _first = Timer(_firstDelay, () {
      _next();
      _loop = Timer.periodic(_gap, (_) => _next());
    });
  }

  void _next() {
    if (!mounted || recentBookingDismissed || !_foreground || widget.paused()) return;
    final orders = widget.latestOrders;
    if (orders.isEmpty) return;
    setState(() {
      _current = orders[_index % orders.length];
      _visible = true;
    });
    _index++;
    _hide?.cancel();
    _hide = Timer(_show, () {
      if (mounted) setState(() => _visible = false);
    });
  }

  void _dismiss() {
    recentBookingDismissed = true;
    _cancel();
    setState(() => _visible = false);
  }

  void _cancel() {
    _first?.cancel();
    _loop?.cancel();
    _hide?.cancel();
  }

  @override
  void dispose() {
    _cancel();
    _life.dispose();
    super.dispose();
  }

  static String timeAgo(String createdAt) {
    final d = DateTime.tryParse(createdAt);
    if (d == null) return '';
    final mins = DateTime.now().difference(d).inMinutes.abs().clamp(1, 1 << 30);
    if (mins < 60) return '$mins min ago';
    final hours = mins ~/ 60;
    if (hours < 24) return '$hours hour${hours > 1 ? 's' : ''} ago';
    final days = hours ~/ 24;
    return '$days day${days > 1 ? 's' : ''} ago';
  }

  @override
  Widget build(BuildContext context) {
    final o = _current;
    if (o == null || recentBookingDismissed) return const SizedBox.shrink();
    final name = strOrNull(o['userName']) ?? strOrNull(o['customerName']) ?? 'A devotee';
    final pooja = strOrNull(o['poojaName']) ?? 'Pooja';
    final city = strOrNull(o['locationName']);
    final language = strOrNull(o['languageName']);
    final ago = timeAgo(str(o['createdAt']));
    final dur = reduceMotion(context) ? Duration.zero : const Duration(milliseconds: 500);
    return IgnorePointer(
      ignoring: !_visible,
      child: AnimatedOpacity(
        opacity: _visible ? 1 : 0,
        duration: dur,
        curve: Curves.easeOut,
        child: AnimatedSlide(
          offset: _visible ? Offset.zero : const Offset(0, .25),
          duration: dur,
          curve: Curves.easeOut,
          child: Semantics(
            liveRegion: true,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 320),
              padding: const EdgeInsets.fromLTRB(12, 12, 30, 12),
              decoration: BoxDecoration(
                color: const Color(0xF2FFF8EE),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFDE68A)),
                boxShadow: const [BoxShadow(color: Color(0x738A1C23), blurRadius: 34, offset: Offset(0, 14), spreadRadius: -14)],
              ),
              child: Stack(clipBehavior: Clip.none, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Padding(padding: EdgeInsets.only(top: 2), child: DiyaIcon(size: 28)),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text.rich(
                        TextSpan(children: [
                          TextSpan(text: name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          const TextSpan(text: ' booked '),
                          TextSpan(text: pooja, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.bluntRed)),
                          if (city != null) TextSpan(text: ' in $city'),
                        ]),
                        style: AppText.body(size: 14, color: pdpInk, height: 1.35),
                      ),
                      const SizedBox(height: 2),
                      Text('${language != null ? '$language pandit · ' : ''}$ago',
                          style: AppText.body(size: 11, color: pdpMutedInk)),
                    ]),
                  ),
                ]),
                Positioned(
                  right: -24,
                  top: -6,
                  child: Semantics(
                    button: true,
                    label: 'Dismiss',
                    child: GestureDetector(
                      onTap: _dismiss,
                      child: const Padding(padding: EdgeInsets.all(6), child: Icon(LucideIcons.x, size: 14, color: Color(0xFFA08070))),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
