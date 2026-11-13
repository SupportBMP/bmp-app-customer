import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api/bmp_api.dart';
import '../../core/config.dart';
import '../../core/storage/cookies.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/json.dart';
import '../../core/utils/launch.dart';
import '../../core/utils/leads.dart';
import '../../core/utils/nav.dart';
import '../../core/widgets/brand_icons.dart';
import '../../core/widgets/site_image.dart';
import '../../core/widgets/ui.dart';
import 'festival_state.dart';
import 'ornaments.dart';

/// Resolved experience for [pageType], or null (evergreen site).
Json? useFestival(WidgetRef ref, String pageType, {String? location, String? language}) {
  final exp = ref.watch(festivalExperienceProvider(FxKey(pageType, location, language))).value;
  if (exp == null || exp['primaryCampaign'] is! Map) return null;
  return exp;
}

Json _campaign(Json exp) => obj(exp['primaryCampaign']);
FxTheme _theme(Json exp) =>
    FxTheme.of(str(_campaign(exp)['themePreset']), strOrNull(pick(exp, ['activeDay', 'color'])));

// ---------------------------------------------------------------------------
// GlobalFestivalStrip.jsx
// ---------------------------------------------------------------------------

class GlobalFestivalStrip extends StatelessWidget {
  const GlobalFestivalStrip({super.key, required this.experience, this.onFestivalPage = false});
  final Json? experience;
  final bool onFestivalPage;

  @override
  Widget build(BuildContext context) {
    final exp = experience;
    final strip = strOrNull(pick(exp, ['copy', 'strip']));
    if (exp == null || strip == null) return const SizedBox.shrink();
    final campaign = _campaign(exp);
    final t = _theme(exp);
    final cta = strOrNull(pick(exp, ['copy', 'cta']));
    final mobileCta = cta != null && cta.length <= 10 ? cta : 'Explore';
    return GestureDetector(
      onTap: () => onFestivalPage
          ? SectionAnchors.maybeOf(context)?.scrollTo('poojas')
          : goHref(context, str(campaign['landingHref'])),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [t.bg, FxTheme.stripMid, t.bg2]),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(radius: 1.2, colors: [t.accent.o(.22), t.accent.o(0)], stops: const [0, .6]),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const DiyaIcon(size: 20),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    strip,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.sans(size: 13, weight: FontWeight.w600, color: t.fg, letterSpacing: .3),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: t.accent,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [BoxShadow(color: t.accent.o(.7), blurRadius: 10, offset: const Offset(0, 2), spreadRadius: -2)],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(mobileCta, style: AppText.sans(size: 12, weight: FontWeight.w700, color: t.accentFg)),
                      const SizedBox(width: 4),
                      Icon(LucideIcons.chevronRight, size: 14, color: t.accentFg),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// FestivalHeroDecor.jsx (only the motifs the website shows below `md`)
// ---------------------------------------------------------------------------

class FestivalHeroDecor extends StatelessWidget {
  const FestivalHeroDecor({super.key, required this.experience});
  final Json? experience;

  @override
  Widget build(BuildContext context) {
    final decorations = list(pick(experience, ['primaryCampaign', 'hero', 'decorations'])).map((e) => '$e').toSet();
    if (decorations.isEmpty) return const SizedBox.shrink();
    final reduce = MediaQuery.of(context).disableAnimations;
    return Positioned.fill(
      child: IgnorePointer(
        child: ClipRect(
          child: Stack(
            children: [
              if (decorations.contains('rangoli'))
                Positioned(
                  left: -96,
                  bottom: -96,
                  child: Opacity(opacity: .16, child: SvgPicture.string(rangoliSvg(), width: 288, height: 288)),
                ),
              if (decorations.contains('toran')) const Positioned(left: 0, right: 0, top: 0, child: ToranGarland(height: 24)),
              if (decorations.contains('diyas'))
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [for (var i = 0; i < 5; i++) DiyaIcon(size: i.isOdd ? 24 : 32, glow: true)],
                  ),
                ),
              if (decorations.contains('petals') && !reduce) const Positioned.fill(child: _FallingPetals()),
            ],
          ),
        ),
      ),
    );
  }
}

class _FallingPetals extends StatefulWidget {
  const _FallingPetals();
  @override
  State<_FallingPetals> createState() => _FallingPetalsState();
}

class _FallingPetalsState extends State<_FallingPetals> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 60))..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  // Paints every frame over the hero; its own layer keeps that from
  // repainting the hero images underneath.
  Widget build(BuildContext context) => RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) => CustomPaint(painter: _PetalPainter(_c.value * 60)),
        ),
      );
}

class _PetalPainter extends CustomPainter {
  _PetalPainter(this.seconds);
  final double seconds;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 12; i++) {
      final left = ((i * 83) % 100) / 100 * size.width;
      final delay = (i * 1.7) % 9;
      final duration = 9 + (i % 5) * 1.6;
      final color = i % 3 == 0 ? const Color(0xFFEA580C) : i % 3 == 1 ? const Color(0xFFF59E0B) : const Color(0xFFFCD34D);
      final s = 8.0 + (i % 3) * 3;
      final t = seconds - delay;
      if (t < 0) continue;
      final p = (t % duration) / duration;
      // fx-fall: translate(0,-10)→(40,720), rotate 0→540°, fade in by 10%
      final opacity = (p < .1 ? p / .1 * .8 : .8 - (p - .1) / .9 * .8) * .75 / .8;
      canvas.save();
      canvas.translate(left + 40 * p, -16 - 10 + 730 * p);
      canvas.rotate(540 * p * math.pi / 180);
      final r = RRect.fromRectAndCorners(
        Rect.fromLTWH(-s / 2, -s / 2, s, s),
        topLeft: Radius.elliptical(s * .6, s * .6),
        bottomRight: Radius.elliptical(s * .6, s * .6),
      );
      canvas.drawRRect(r, Paint()..color = color.withValues(alpha: opacity.clamp(0, 1)));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _PetalPainter old) => old.seconds != seconds;
}

/// FestivalHeroBadge — chip above the homepage hero headline.
class FestivalHeroBadge extends StatelessWidget {
  const FestivalHeroBadge({super.key, required this.experience});
  final Json? experience;

  @override
  Widget build(BuildContext context) {
    final exp = experience;
    if (exp == null) return const SizedBox.shrink();
    final campaign = _campaign(exp);
    final activeDay = exp['activeDay'];
    final text = activeDay is Map
        ? '${str(campaign['festivalName'])} · ${str(activeDay['label'])} · ${str(activeDay['name']).split(' · ').first}'
        : (strOrNull(pick(exp, ['copy', 'eyebrow'])) ?? str(campaign['name']));
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Align(
        alignment: Alignment.centerLeft,
        child: GestureDetector(
          onTap: () => goHref(context, str(campaign['landingHref'])),
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: const LinearGradient(colors: [Color(0xFF5E1016), Color(0xFFB4401A)]),
              boxShadow: const [BoxShadow(color: Color(0xB3B4401A), blurRadius: 20, offset: Offset(0, 6), spreadRadius: -6)],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const DiyaIcon(size: 20),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.sans(size: 12, weight: FontWeight.w600, color: const Color(0xFFFDF0D5)),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(LucideIcons.chevronRight, size: 16, color: Color(0xFFF6D77A)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// FestivalHero.jsx (homepage layer 2)
// ---------------------------------------------------------------------------

class FestivalHero extends ConsumerWidget {
  const FestivalHero({super.key, required this.experience});
  final Json? experience;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exp = experience;
    if (exp == null) return const SizedBox.shrink();
    final ll = festivalLocLang(ref);
    final campaign = _campaign(exp);
    final t = _theme(exp);
    final copy = obj(exp['copy']);
    final activeDay = exp['activeDay'] is Map ? obj(exp['activeDay']) : null;
    final poojas = objList(exp['poojas']).take(4).toList();
    final days = objList(exp['days']);
    final next = exp['nextObservance'] is Map ? obj(exp['nextObservance']) : null;
    final browseHref = '/${ll.language}/${ll.location}/pooja';
    final size = MediaQuery.sizeOf(context);

    return Anchor(
      'festival',
      child: Container(
        color: t.bg,
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(.7, -.8),
                    radius: .9,
                    colors: [t.bg2.o(.85), t.bg2.o(0)],
                    stops: const [0, .7],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-.8, 1),
                    radius: .7,
                    colors: [t.accent.o(.18), t.accent.o(0)],
                    stops: const [0, .7],
                  ),
                ),
              ),
            ),
            Positioned(right: -160, top: -160, child: MandalaWatermark(size: 640, color: t.accent, opacity: .10)),
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 48, 32, 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (strOrNull(copy['eyebrow']) != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: t.accent.o(.12),
                        border: Border.all(color: t.accent.o(.45)),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const DiyaIcon(size: 16),
                        const SizedBox(width: 8),
                        Flexible(child: Text(str(copy['eyebrow']), style: AppText.sans(size: 12, weight: FontWeight.w600, color: t.accent))),
                      ]),
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (strOrNull(copy['headline']) != null) ...[
                    Text(str(copy['headline']), style: AppText.heading(size: 30, color: t.fg)),
                    const SizedBox(height: 20),
                  ],
                  if (strOrNull(copy['sub']) != null) ...[
                    Text(str(copy['sub']), style: AppText.sans(size: 16, color: t.muted, height: 1.6)),
                    const SizedBox(height: 24),
                  ],
                  _FxButton(
                    label: strOrNull(copy['cta']) ?? 'Explore ${str(campaign['festivalName'])}',
                    trailing: LucideIcons.arrowRight,
                    background: t.accent,
                    foreground: t.accentFg,
                    shadowColor: t.accent.o(.6),
                    onTap: () => goHref(context, str(campaign['landingHref'])),
                  ),
                  const SizedBox(height: 12),
                  FxWhatsAppButton(
                    experience: exp,
                    slot: 'home.hero',
                    label: 'Ask a pandit on WhatsApp',
                    height: 48,
                    fontSize: 16,
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text('or ', style: AppText.sans(size: 14, color: t.muted)),
                      GestureDetector(
                        onTap: () => callPhone('+91$leadPhone'),
                        child: Text(
                          'call $leadPhoneLabel',
                          style: AppText.sans(size: 14, weight: FontWeight.w600, color: t.fg, decoration: TextDecoration.underline)
                              .copyWith(decorationColor: t.accent),
                        ),
                      ),
                      Text(' · ', style: AppText.sans(size: 14, color: t.muted)),
                      GestureDetector(
                        onTap: () => goHref(context, browseHref),
                        child: Text('browse all pujas', style: AppText.sans(size: 14, color: t.muted)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  // Day card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: t.card.o(.55),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: t.border.o(.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (activeDay != null ? 'Today' : str(campaign['name'])).toUpperCase(),
                                    style: AppText.sans(size: 11, weight: FontWeight.w700, color: t.muted, letterSpacing: 2),
                                  ),
                                  Text(festivalTodayLine(exp), style: AppText.heading(size: 18, color: t.fg, height: 1.4)),
                                ],
                              ),
                            ),
                            if (parseHexColor(strOrNull(activeDay?['color'])) != null)
                              Container(
                                width: 40,
                                height: 40,
                                margin: const EdgeInsets.only(left: 12),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: parseHexColor(str(activeDay?['color'])),
                                  border: Border.all(color: t.accent, width: 2),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (days.isNotEmpty) ObservanceDayModule(experience: exp),
                        if (next != null) ...[
                          const SizedBox(height: 16),
                          GestureDetector(
                            onTap: () => openExternal(festivalWaLink(
                              campaign: campaign,
                              slot: 'home.next',
                              intent:
                                  "I'd like to book a pandit in advance for ${str(next['name'])} (${str(next['shortDate'])})",
                              city: ll.location,
                            )),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1FA855).o(.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF1FA855).o(.5)),
                              ),
                              child: Row(
                                children: [
                                  const WhatsAppIcon(size: 20, color: Color(0xFF5FD68C)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Book ahead for ${str(next['name']).split(' · ').last} · ${str(next['shortDate'])}',
                                          style: AppText.sans(size: 14, weight: FontWeight.w600, color: t.fg),
                                        ),
                                        Text(
                                          'Pandit slots fill up fast — reserve yours on WhatsApp',
                                          style: AppText.sans(size: 12, color: t.muted),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Icon(LucideIcons.arrowRight, size: 16, color: Color(0xFF5FD68C)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.only(top: 12),
                            decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.white.o(.1)))),
                            child: Row(
                              children: [
                                Icon(LucideIcons.calendarDays, size: 16, color: t.accent),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text.rich(
                                    TextSpan(children: [
                                      const TextSpan(text: 'Next: '),
                                      TextSpan(text: str(next['name']), style: TextStyle(fontWeight: FontWeight.w600, color: t.fg)),
                                      TextSpan(text: ' · ${str(next['shortDate'])}'),
                                    ]),
                                    style: AppText.sans(size: 12, color: t.muted),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (poojas.isNotEmpty) ...[
                    const SizedBox(height: 40),
                    Text(festivalPoojaHeading(exp), style: AppText.heading(size: 20, color: t.fg)),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: math.min(size.width * .7, 280) + 150,
                      child: OverflowBox(
                        maxWidth: size.width,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          // Line the first card up with the section's 32px content inset.
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          itemCount: poojas.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 16),
                          itemBuilder: (_, i) => SizedBox(
                            width: math.min(size.width * .7, 280),
                            child: FestivalPoojaCard(experience: exp, pooja: poojas[i], slotKey: 'home.hero'),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: () => openFestivalCallback(context, exp, slot: 'home.hero.consult'),
                      child: CustomPaint(
                        painter: _DashedBorderPainter(t.accent.o(.6), 16),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          decoration: BoxDecoration(color: t.accent.o(.08), borderRadius: BorderRadius.circular(16)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text.rich(
                                TextSpan(children: [
                                  TextSpan(
                                    text: 'Not sure which puja is right for your family? ',
                                    style: TextStyle(fontWeight: FontWeight.w700, color: t.fg),
                                  ),
                                  TextSpan(text: 'A pandit will guide you — free, no obligation.', style: TextStyle(color: t.muted)),
                                ]),
                                style: AppText.sans(size: 14),
                              ),
                              const SizedBox(height: 4),
                              Row(mainAxisSize: MainAxisSize.min, children: [
                                Text('Get a free consultation', style: AppText.sans(size: 14, weight: FontWeight.w700, color: t.accent)),
                                const SizedBox(width: 4),
                                Icon(LucideIcons.arrowRight, size: 16, color: t.accent),
                              ]),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter(this.color, this.radius);
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final m in path.computeMetrics()) {
      for (double d = 0; d < m.length; d += 7) {
        canvas.drawPath(m.extractPath(d, math.min(d + 4, m.length)), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) => old.color != color;
}

class _FxButton extends StatelessWidget {
  const _FxButton({
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
    this.trailing,
    this.shadowColor,
  });

  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;
  final IconData? trailing;
  final Color? shadowColor;

  @override
  Widget build(BuildContext context) => Container(
        height: 48,
        width: double.infinity,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
          boxShadow: shadowColor == null
              ? null
              : [BoxShadow(color: shadowColor!, blurRadius: 30, offset: const Offset(0, 8), spreadRadius: -6)],
        ),
        child: Tap(
          radius: 12,
          onTap: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(child: Text(label, style: AppText.sans(size: 16, weight: FontWeight.w700, color: foreground))),
              if (trailing != null) ...[const SizedBox(width: 8), Icon(trailing, size: 16, color: foreground)],
            ],
          ),
        ),
      );
}

/// leadCtas.jsx `WhatsAppButton`.
class FxWhatsAppButton extends ConsumerWidget {
  const FxWhatsAppButton({
    super.key,
    required this.experience,
    required this.slot,
    this.pooja,
    this.label = 'Ask on WhatsApp',
    this.intent,
    this.height = 44,
    this.fontSize = 14,
  });

  final Json? experience;
  final String slot;
  final String? pooja;
  final String label;
  final String? intent;
  final double height;
  final double fontSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ll = festivalLocLang(ref);
    final campaign = experience == null ? null : _campaign(experience!);
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1FA855),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Color(0xB31FA855), blurRadius: 24, offset: Offset(0, 8), spreadRadius: -8)],
      ),
      child: Tap(
        radius: 12,
        onTap: () => openExternal(festivalWaLink(campaign: campaign, slot: slot, pooja: pooja, city: ll.location, intent: intent)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const WhatsAppIcon(size: 20),
            const SizedBox(width: 8),
            Flexible(child: Text(label, style: AppText.sans(size: fontSize, weight: FontWeight.w700, color: Colors.white))),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ObservanceDayModule.jsx
// ---------------------------------------------------------------------------

class ObservanceDayModule extends StatefulWidget {
  const ObservanceDayModule({super.key, required this.experience});
  final Json experience;

  @override
  State<ObservanceDayModule> createState() => _ObservanceDayModuleState();
}

class _ObservanceDayModuleState extends State<ObservanceDayModule> with SingleTickerProviderStateMixin {
  String? _picked;
  final _scroll = ScrollController();
  late final AnimationController _pulse;

  static const _lightColors = ['#FFFFFF', '#F2C230'];

  String _deviName(String name) => name.split(' · ').last.replaceFirst(RegExp('^Maa '), '');

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final days = objList(widget.experience['days']);
      final i = days.indexWhere((d) => str(d['state']) == 'today');
      if (i < 0 || !_scroll.hasClients) return;
      final vw = _scroll.position.viewportDimension;
      final target = i * 50.0 - vw / 2 + 25;
      _scroll.jumpTo(target.clamp(0, _scroll.position.maxScrollExtent));
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = _theme(widget.experience);
    final days = objList(widget.experience['days']);
    if (days.isEmpty) return const SizedBox.shrink();
    final fallback = days.firstWhere(
      (d) => str(d['state']) == 'today',
      orElse: () => days.firstWhere((d) => str(d['state']) != 'past', orElse: () => days.last),
    );
    final shown = days.firstWhere((d) => str(d['key']) == _picked, orElse: () => fallback);
    final reduce = MediaQuery.of(context).disableAnimations;

    return Column(
      children: [
        SingleChildScrollView(
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(top: 16, bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < days.length; i++)
                _dayDot(days[i], i, days.length, t, shown, reduce),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 20),
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: str(shown['label']), style: TextStyle(fontWeight: FontWeight.w600, color: t.fg)),
              const TextSpan(text: ' · '),
              TextSpan(
                text: _deviName(str(shown['name'])),
                style: TextStyle(
                  fontWeight: str(shown['state']) == 'today' ? FontWeight.w700 : FontWeight.w600,
                  color: str(shown['state']) == 'today' ? t.accent : t.fg,
                ),
              ),
              TextSpan(text: ' · ${str(shown['shortDate'])}'),
              if (strOrNull(shown['colorName']) != null) TextSpan(text: ' · ${str(shown['colorName'])}'),
            ]),
            textAlign: TextAlign.center,
            style: AppText.sans(size: 12, color: t.muted),
          ),
        ),
      ],
    );
  }

  Widget _dayDot(Json d, int i, int count, FxTheme t, Json shown, bool reduce) {
    final today = str(d['state']) == 'today';
    final past = str(d['state']) == 'past';
    final hex = str(d['color'], '#C8942E');
    final color = parseHexColor(hex) ?? const Color(0xFFC8942E);
    final textColor = _lightColors.contains(hex.toUpperCase()) ? const Color(0xFF4A1016) : Colors.white;
    final selected = str(shown['key']) == str(d['key']) && !today;

    Widget dot = Container(
      width: today ? 48 : 36,
      height: today ? 48 : 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: today ? t.accent : Colors.white.o(.25), width: 2),
        boxShadow: today ? [BoxShadow(color: color.o(.75), blurRadius: 22)] : null,
      ),
      child: past
          ? Icon(LucideIcons.check, size: 16, color: textColor)
          : Text('${i + 1}', style: AppText.sans(size: today ? 16 : 12, weight: FontWeight.w700, color: textColor)),
    );
    if (past) {
      dot = ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          .45, .1, .05, 0, 0, //
          .05, .45, .1, 0, 0,
          .05, .1, .45, 0, 0,
          0, 0, 0, 1, 0,
        ]),
        child: dot,
      );
    }
    if (selected) {
      dot = Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: t.accent, width: 2)),
        child: dot,
      );
    }

    return GestureDetector(
      onTap: () => setState(() => _picked = str(d['key'])),
      child: SizedBox(
        width: 50,
        child: Column(
          children: [
            SizedBox(
              height: 48,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  if (i < count - 1)
                    Positioned(
                      left: 25,
                      right: -25,
                      child: Container(height: 2, color: past ? t.accent.o(.7) : Colors.white.o(.15)),
                    ),
                  if (today && !reduce)
                    AnimatedBuilder(
                      animation: _pulse,
                      builder: (_, _) {
                        Widget ring(double v) => Transform.scale(
                              scale: 1 + .7 * v,
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: color.o(.75 * (1 - v)), width: 2),
                                ),
                              ),
                            );
                        return Stack(alignment: Alignment.center, children: [
                          ring(_pulse.value),
                          ring((_pulse.value + .5) % 1),
                        ]);
                      },
                    ),
                  if (today && !reduce)
                    AnimatedBuilder(
                      animation: _pulse,
                      builder: (_, child) =>
                          Transform.scale(scale: 1 + .07 * math.sin(_pulse.value * math.pi), child: child),
                      child: dot,
                    )
                  else
                    dot,
                ],
              ),
            ),
            if (today) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                decoration: BoxDecoration(color: t.accent, borderRadius: BorderRadius.circular(999)),
                child: Text('TODAY', style: AppText.sans(size: 9, weight: FontWeight.w700, color: t.accentFg, letterSpacing: 1)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// FestivalPoojaCard.jsx
// ---------------------------------------------------------------------------

class FestivalPoojaCard extends ConsumerWidget {
  const FestivalPoojaCard({
    super.key,
    required this.experience,
    required this.pooja,
    required this.slotKey,
    this.compact = false,
  });

  final Json experience;
  final Json pooja;
  final String slotKey;
  final bool compact;

  static String formatPrice(num n) => '₹${formatIndianNumber(n)}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = _theme(experience);
    final ll = festivalLocLang(ref);
    final campaign = _campaign(experience);
    final href = buildPoojaHref(pooja, ll.language, ll.location);
    final name = str(pooja['name']);
    final image = Stack(
      fit: StackFit.expand,
      children: [
        SiteImage(strOrNull(pooja['image']) ?? '/images/Poojas1.jpg', alignment: Alignment.topCenter),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [t.bg, t.bg.o(0), Colors.transparent],
              stops: const [0, .5, 1],
            ),
          ),
        ),
      ],
    );

    return Stack(
      children: [
        GestureDetector(
          onTap: () => goHref(context, href),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: t.card.o(.7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: t.border.o(.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (compact) SizedBox(height: 112, child: image) else AspectRatio(aspectRatio: 1, child: image),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (strOrNull(pooja['label']) != null) ...[
                        Row(children: [
                          Container(width: 16, height: 1, color: t.accent.o(.7)),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              str(pooja['label']).toUpperCase(),
                              style: AppText.sans(size: 10.5, weight: FontWeight.w600, color: t.accent, letterSpacing: 1.7, height: 1.3),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 6),
                      ],
                      Text(name, style: AppText.heading(size: 16, color: t.fg, height: 1.35)),
                      if (numOf(pooja['startingPrice']) > 0) ...[
                        const SizedBox(height: 6),
                        Text.rich(
                          TextSpan(children: [
                            const TextSpan(text: 'From '),
                            TextSpan(
                              text: formatPrice(numOf(pooja['startingPrice'])),
                              style: TextStyle(fontWeight: FontWeight.w600, color: t.fg),
                            ),
                          ]),
                          style: AppText.sans(size: 12, color: t.muted),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Text('View packages', style: AppText.body(size: 14, weight: FontWeight.w600, color: t.accent)),
                        const SizedBox(width: 4),
                        Icon(LucideIcons.arrowRight, size: 16, color: t.accent),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          right: 10,
          top: 10,
          child: GestureDetector(
            onTap: () => openExternal(festivalWaLink(
              campaign: campaign,
              slot: '$slotKey.card',
              pooja: name,
              city: strOrNull(pooja['linkLocation']) ?? ll.location,
              intent:
                  "I'd like help planning $name for ${str(campaign['festivalName'])} — muhurat, samagri and what's included",
            )),
            child: Container(
              padding: const EdgeInsets.fromLTRB(6, 4, 10, 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1FA855),
                borderRadius: BorderRadius.circular(999),
                boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 10, offset: Offset(0, 4))],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const WhatsAppIcon(size: 16),
                const SizedBox(width: 4),
                Text('Plan This Puja', style: AppText.sans(size: 11, weight: FontWeight.w700, color: Colors.white)),
              ]),
            ),
          ),
        ),
      ],
    );
  }
}

/// `Number(n).toLocaleString("en-IN")` — Indian digit grouping.
String formatIndianNumber(num n) {
  final neg = n < 0;
  final parts = n.abs().toString().split('.');
  var whole = parts[0];
  final frac = parts.length > 1 && int.tryParse(parts[1]) != 0 ? '.${parts[1]}' : '';
  if (whole.length > 3) {
    final last3 = whole.substring(whole.length - 3);
    var rest = whole.substring(0, whole.length - 3);
    final groups = <String>[];
    while (rest.length > 2) {
      groups.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) groups.insert(0, rest);
    whole = '${groups.join(',')},$last3';
  }
  return '${neg ? '-' : ''}$whole$frac';
}

// ---------------------------------------------------------------------------
// leadCtas.jsx — QuickLeadForm + callback dialog
// ---------------------------------------------------------------------------

class QuickLeadForm extends ConsumerStatefulWidget {
  const QuickLeadForm({
    super.key,
    required this.experience,
    required this.slot,
    this.pooja,
    this.ctaLabel = 'Get a call back',
    this.successText,
    this.light = false,
    this.compact = false,
    this.onDone,
  });

  final Json? experience;
  final String slot;
  final String? pooja;
  final String ctaLabel;
  final String? successText;
  final bool light;
  final bool compact;
  final VoidCallback? onDone;

  @override
  ConsumerState<QuickLeadForm> createState() => _QuickLeadFormState();
}

class _QuickLeadFormState extends ConsumerState<QuickLeadForm> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  bool _busy = false;
  String? _doneName;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
    _phone.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final campaign = widget.experience == null ? null : _campaign(widget.experience!);
    final ll = festivalLocLang(ref);
    final phone = _phone.text;
    setState(() => _busy = true);
    try {
      final payload = createCrmLeadEnquiryBody({
        'name': _name.text.trim(),
        'phone': phone,
        'city': titleCase(ll.location),
        'language': 'Any / not sure',
        'enquiry':
            '${strOrNull(campaign?['name']) ?? 'Festival'} - Ref: ${leadRefOf(campaign, widget.slot)} - Slot: ${widget.slot}${widget.pooja != null ? ' - Pooja: ${widget.pooja}' : ''}',
      });
      await BmpApi.postGlobalLeadCapture({
        ...payload,
        crmLeadsFieldMap['pujaType']!: widget.pooja ?? '${strOrNull(campaign?['festivalName']) ?? 'Festival'} enquiry',
        'source': '${strOrNull(campaign?['festivalName']) ?? 'Festival'} campaign · ${widget.slot}',
        'webPageLink': '${AppConfig.siteUrl}/',
      });
    } catch (_) {
      // Fails soft like the website: the visitor still sees the thank-you.
    }
    if (!mounted) return;
    setState(() {
      _doneName = _name.text.trim().split(' ').first;
      _busy = false;
    });
    widget.onDone?.call();
  }

  @override
  Widget build(BuildContext context) {
    final exp = widget.experience;
    final t = exp == null ? FxTheme.of(null) : _theme(exp);
    final light = widget.light;
    final campaign = exp == null ? null : _campaign(exp);
    final ll = festivalLocLang(ref);
    final phone = _phone.text;
    final err = phone.isNotEmpty && !isValidIndianMobile(phone) ? 'Enter a valid 10-digit mobile number.' : null;
    final ready = _name.text.trim().length >= 2 && phone.length == 10 && err == null;
    final fg = light ? const Color(0xFF2B1A14) : t.fg;

    if (_doneName != null) {
      return Column(
        children: [
          Icon(LucideIcons.circleCheck, size: 36, color: light ? const Color(0xFF1FA855) : t.accent),
          const SizedBox(height: 12),
          Text(
            'Thank you, $_doneName! ${widget.successText ?? 'Our Puja Seva team will call you shortly (8 AM – 9 PM).'}',
            textAlign: TextAlign.center,
            style: AppText.sans(size: 14, weight: FontWeight.w600, color: fg),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => openExternal(festivalWaLink(campaign: campaign, slot: widget.slot, pooja: widget.pooja, city: ll.location)),
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(color: const Color(0xFF1FA855), borderRadius: BorderRadius.circular(12)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const WhatsAppIcon(size: 20),
                const SizedBox(width: 8),
                Text('Continue on WhatsApp', style: AppText.sans(size: 14, weight: FontWeight.w700, color: Colors.white)),
              ]),
            ),
          ),
        ],
      );
    }

    final fieldBorder = light ? const Color(0xFFE6D3B3) : Colors.white.o(.2);
    final fieldBg = light ? Colors.white : Colors.white.o(.1);
    final hint = light ? const Color(0xFFA08070) : t.muted.o(.8);
    InputDecoration deco(String h) => InputDecoration(
          hintText: h,
          hintStyle: AppText.sans(size: 14, color: hint),
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 44,
          decoration: BoxDecoration(color: fieldBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: fieldBorder)),
          child: TextField(
            controller: _name,
            style: AppText.sans(size: 14, color: fg),
            textCapitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.name],
            decoration: deco('Your name'),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 44,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(color: fieldBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: fieldBorder)),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                color: light ? const Color(0xFFFDF6EC) : Colors.white.o(.1),
                child: Text('+91', style: AppText.sans(size: 14, color: light ? const Color(0xFF7A4A3A) : fg)),
              ),
              Expanded(
                child: TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  style: AppText.sans(size: 14, color: fg),
                  autofillHints: const [AutofillHints.telephoneNumberNational],
                  onChanged: (v) {
                    final digits = v.replaceAll(RegExp(r'\D'), '');
                    if (digits != v) _phone.value = TextEditingValue(text: digits, selection: TextSelection.collapsed(offset: digits.length));
                  },
                  decoration: deco('10-digit mobile').copyWith(counterText: ''),
                ),
              ),
            ],
          ),
        ),
        if (err != null) ...[
          const SizedBox(height: 8),
          Text(err, style: AppText.sans(size: 12, color: const Color(0xFFFCA5A5))),
        ],
        const SizedBox(height: 10),
        Opacity(
          opacity: ready && !_busy ? 1 : .6,
          child: Container(
            height: 46,
            decoration: BoxDecoration(color: light ? const Color(0xFF8A1C23) : t.accent, borderRadius: BorderRadius.circular(12)),
            child: Tap(
              radius: 12,
              onTap: ready && !_busy ? _submit : null,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.phoneCall, size: 16, color: light ? Colors.white : t.accentFg),
                  const SizedBox(width: 8),
                  Text(
                    _busy ? 'Sending…' : widget.ctaLabel,
                    style: AppText.sans(size: 14, weight: FontWeight.w700, color: light ? Colors.white : t.accentFg),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Free consultation · No spam · Reply within 10 min',
          textAlign: TextAlign.center,
          style: AppText.sans(size: 11, color: light ? const Color(0xFF7A4A3A) : t.muted),
        ),
      ],
    );
  }
}

/// Festival-themed dialog shell (DialogContent + toran + close X).
Future<void> showFestivalDialog(BuildContext context, Json exp, {required WidgetBuilder builder}) {
  final t = _theme(exp);
  return showAppDialog(
    context,
    background: t.bg,
    padding: EdgeInsets.zero,
    radius: 16,
    maxWidth: 448,
    closeColor: t.fg,
    builder: (ctx) => SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ToranGarland(height: 20),
          builder(ctx),
        ],
      ),
    ),
  );
}

/// `openFestivalCallback` — the FestivalCallbackHost dialog.
void openFestivalCallback(BuildContext context, Json? exp, {String slot = 'callback', String? pooja, String? title}) {
  if (exp == null) return;
  final campaign = _campaign(exp);
  final t = _theme(exp);
  showFestivalDialog(
    context,
    exp,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DiyaIcon(size: 36),
          const SizedBox(height: 12),
          Text(
            title ?? 'Free ${str(campaign['festivalName'])} puja consultation',
            style: AppText.heading(size: 24, color: t.fg),
          ),
          const SizedBox(height: 12),
          Text(
            pooja != null
                ? 'Share your number and our pandit team will call you about $pooja — muhurat, samagri and package options.'
                : 'Share your number — our Puja Seva team will help you pick the right puja, muhurat and pandit for your family.',
            style: AppText.sans(size: 14, color: t.muted, height: 1.6),
          ),
          const SizedBox(height: 12),
          QuickLeadForm(experience: exp, slot: slot, pooja: pooja, ctaLabel: 'Call me back', compact: true),
        ],
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// FestivalStickyContact.jsx (mobile bar)
// ---------------------------------------------------------------------------

class FestivalStickyContact extends ConsumerWidget {
  const FestivalStickyContact({super.key, required this.experience});
  final Json? experience;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exp = experience;
    if (exp == null) return const SizedBox.shrink();
    final campaign = _campaign(exp);
    final t = _theme(exp);
    final ll = festivalLocLang(ref);
    const slot = 'festival.sticky';
    Widget btn({required Widget icon, required String label, required Color bg, required Color fg, Color? border, required VoidCallback onTap}) =>
        Expanded(
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
              border: border == null ? null : Border.all(color: border),
            ),
            child: Tap(
              radius: 12,
              onTap: onTap,
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                icon,
                const SizedBox(width: 6),
                Text(label, style: AppText.sans(size: 12, weight: FontWeight.w700, color: fg)),
              ]),
            ),
          ),
        );
    return Container(
      decoration: BoxDecoration(
        color: t.bg,
        border: Border(top: BorderSide(color: t.border.o(.4))),
        boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 30, offset: Offset(0, -10))],
      ),
      padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const DiyaIcon(size: 16),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '${str(campaign['festivalName'])} pujas — talk to a pandit, free',
                style: AppText.sans(size: 12, weight: FontWeight.w600, color: t.fg),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            btn(
              icon: const WhatsAppIcon(size: 16),
              label: 'WhatsApp',
              bg: const Color(0xFF1FA855),
              fg: Colors.white,
              onTap: () => openExternal(festivalWaLink(campaign: campaign, slot: slot, city: ll.location)),
            ),
            const SizedBox(width: 8),
            btn(
              icon: Icon(LucideIcons.phone, size: 16, color: t.fg),
              label: 'Call',
              bg: Colors.transparent,
              fg: t.fg,
              border: Colors.white.o(.3),
              onTap: () => callPhone('+91$leadPhone'),
            ),
            const SizedBox(width: 8),
            btn(
              icon: Icon(LucideIcons.phoneCall, size: 16, color: t.accentFg),
              label: 'Call me',
              bg: t.accent,
              fg: t.accentFg,
              onTap: () => openFestivalCallback(context, exp, slot: slot),
            ),
          ]),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// RelatedFestivalPoojas.jsx (PDP)
// ---------------------------------------------------------------------------

class RelatedFestivalPoojas extends StatelessWidget {
  const RelatedFestivalPoojas({super.key, required this.experience, required this.currentPoojaSlug});
  final Json? experience;
  final String currentPoojaSlug;

  @override
  Widget build(BuildContext context) {
    final exp = experience;
    if (exp == null || currentPoojaSlug.isEmpty) return const SizedBox.shrink();
    final all = objList(exp['poojas']);
    if (!all.any((p) => str(p['slug']) == currentPoojaSlug)) return const SizedBox.shrink();
    final poojas = all.where((p) => str(p['slug']) != currentPoojaSlug).take(3).toList();
    if (poojas.isEmpty) return const SizedBox.shrink();
    final campaign = _campaign(exp);
    final t = _theme(exp);
    final activeDay = exp['activeDay'];
    final link = activeDay is Map
        ? '${str(activeDay['label'])} · See all'
        : (strOrNull(pick(exp, ['copy', 'cta'])) ?? 'See all');
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: t.bg, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const DiyaIcon(size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text('Also this ${str(campaign['festivalName'])}', style: AppText.heading(size: 18, color: t.fg))),
            GestureDetector(
              onTap: () => goHref(context, str(campaign['landingHref'])),
              child: Text('$link →', style: AppText.sans(size: 12, weight: FontWeight.w600, color: t.accent)),
            ),
          ]),
          const SizedBox(height: 12),
          for (final p in poojas) ...[
            FestivalPoojaCard(experience: exp, pooja: p, slotKey: 'pdp.related', compact: true),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// FestivalNudges.jsx — campaign popup + toast
// ---------------------------------------------------------------------------

/// Mount once per eligible page (home, listing, category, other). Shows the
/// campaign popup after its delay (frequency-capped) and the toast after
/// scrolling past 20%/500px.
class FestivalNudges extends StatefulWidget {
  const FestivalNudges({
    super.key,
    required this.experience,
    required this.pageType,
    required this.scrollController,
    required this.child,
  });

  final Json? experience;
  final String pageType;
  final ScrollController scrollController;
  final Widget child;

  @override
  State<FestivalNudges> createState() => _FestivalNudgesState();
}

class _FestivalNudgesState extends State<FestivalNudges> {
  Timer? _popupTimer;
  Timer? _toastTimer;
  bool _toastArmed = false;
  bool _toastVisible = false;
  bool _popupOpen = false;
  String? _startedFor;

  static const _nudgePages = ['home', 'listing', 'category', 'other'];

  Json? get _campaign => widget.experience == null ? null : obj(widget.experience!['primaryCampaign']);

  @override
  void didUpdateWidget(covariant FestivalNudges oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybeStart();
  }

  @override
  void initState() {
    super.initState();
    _maybeStart();
  }

  void _maybeStart() {
    final c = _campaign;
    final id = strOrNull(c?['id']);
    if (id == null || _startedFor == id || !_nudgePages.contains(widget.pageType)) return;
    _startedFor = id;
    final popup = obj(pick(c, ['nudges', 'popup']));
    final toast = obj(pick(c, ['nudges', 'toast']));

    if (boolOf(popup['enabled'])) {
      final freq = str(popup['frequency'], 'daily');
      if (_popupAllowed(id, str(c?['version']), freq)) {
        final delay = math.max(2, intOf(popup['delaySeconds'], 8));
        _popupTimer = Timer(Duration(seconds: delay), () {
          if (!mounted || fxSessionFlags.contains(exitIntentSessionKey)) return;
          _markPopupShown(id, str(c?['version']), freq);
          _showPopup();
        });
      }
    }

    if (boolOf(toast['enabled'])) {
      final dismissKey = 'fx_toast_${id}_${istDate()}';
      // Skipped on the mobile homepage (live feed + sticky CTA own the bottom).
      if (Cookies.prefs.getString(dismissKey) == null && widget.pageType != 'home') {
        final delay = math.max(1, intOf(toast['delaySeconds'], 4));
        _toastTimer = Timer(Duration(seconds: delay), () {
          _toastArmed = true;
          _onScroll();
        });
        widget.scrollController.addListener(_onScroll);
      }
    }
  }

  bool _popupAllowed(String id, String version, String frequency) {
    if (fxSessionFlags.contains(exitIntentSessionKey)) return false;
    final key = 'fx_popup_${id}_v$version';
    if (frequency == 'session') return !fxSessionFlags.contains(key);
    final last = Cookies.prefs.getString(key);
    if (last == null) return true;
    return frequency == 'daily' ? last != istDate() : false;
  }

  void _markPopupShown(String id, String version, String frequency) {
    final key = 'fx_popup_${id}_v$version';
    if (frequency == 'session') {
      fxSessionFlags.add(key);
    } else {
      Cookies.prefs.setString(key, istDate());
    }
    fxSessionFlags.add(exitIntentSessionKey);
  }

  void _onScroll() {
    if (!_toastArmed || _toastVisible || !widget.scrollController.hasClients) return;
    final pos = widget.scrollController.position;
    final depth = pos.pixels / math.max(1, pos.maxScrollExtent);
    if (depth > .2 || pos.pixels > 500) {
      setState(() => _toastVisible = true);
      widget.scrollController.removeListener(_onScroll);
    }
  }

  void _dismissToast() {
    setState(() => _toastVisible = false);
    final id = str(_campaign?['id']);
    Cookies.prefs.setString('fx_toast_${id}_${istDate()}', '1');
  }

  Future<void> _showPopup() async {
    final exp = widget.experience!;
    final campaign = obj(exp['primaryCampaign']);
    final popup = obj(pick(campaign, ['nudges', 'popup']));
    final t = _theme(exp);
    setState(() => _popupOpen = true);
    await showFestivalDialog(
      context,
      exp,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(.6, -1),
            radius: .9,
            colors: [t.bg2.o(.7), t.bg2.o(0)],
            stops: const [0, .7],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (strOrNull(popup['imageUrl']) != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 192,
                  width: double.infinity,
                  child: Stack(fit: StackFit.expand, children: [
                    Opacity(
                      opacity: .6,
                      child: ImageFiltered(
                        imageFilter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                        child: Transform.scale(scale: 1.1, child: SiteImage(str(popup['imageUrl']))),
                      ),
                    ),
                    SiteImage(str(popup['imageUrl']), fit: BoxFit.contain, placeholderColor: Colors.transparent),
                  ]),
                ),
              )
            else
              const DiyaIcon(size: 40),
            const SizedBox(height: 12),
            Text(strOrNull(popup['title']) ?? str(campaign['name']), style: AppText.heading(size: 24, color: t.fg)),
            if (strOrNull(popup['body']) != null) ...[
              const SizedBox(height: 12),
              Text(str(popup['body']), style: AppText.sans(size: 14, color: t.muted, height: 1.6)),
            ],
            const SizedBox(height: 16),
            Text(
              'FREE MUHURAT + PUJA PLAN FOR YOUR FAMILY',
              style: AppText.sans(size: 12, weight: FontWeight.w700, color: t.accent, letterSpacing: 1.7),
            ),
            const SizedBox(height: 12),
            QuickLeadForm(
              experience: exp,
              slot: 'nudge.popup',
              ctaLabel: 'Get my free puja plan',
              successText: 'Our pandit team will call you with your muhurat and puja plan.',
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.white.o(.1)))),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => openExternal(festivalWaLink(campaign: campaign, slot: 'nudge.popup')),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const WhatsAppIcon(size: 16, color: Color(0xFF5FD68C)),
                      const SizedBox(width: 6),
                      Text('Chat on WhatsApp', style: AppText.sans(size: 12, weight: FontWeight.w600, color: const Color(0xFF5FD68C))),
                    ]),
                  ),
                  const Spacer(),
                  Flexible(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.of(ctx).pop();
                        goHref(context, strOrNull(popup['ctaHref']) ?? str(campaign['landingHref']));
                      },
                      child: Text(
                        'Just browsing → ${strOrNull(popup['ctaLabel']) ?? 'Explore'}',
                        textAlign: TextAlign.right,
                        style: AppText.sans(size: 12, weight: FontWeight.w600, color: t.muted),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (mounted) setState(() => _popupOpen = false);
  }

  @override
  void dispose() {
    _popupTimer?.cancel();
    _toastTimer?.cancel();
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final exp = widget.experience;
    final showToast = _toastVisible && !_popupOpen && exp != null;
    return Stack(
      children: [
        widget.child,
        // The page body already ends above a bottom bar (the sticky "Have
        // Questions?" contact bar), so sit just above it rather than 84 px up
        // over the content. Without a bottom bar the Scaffold keeps the
        // system inset in the body's padding, which keeps the toast clear of
        // the gesture bar.
        if (showToast)
          Positioned(left: 12, right: 12, bottom: 12 + MediaQuery.paddingOf(context).bottom, child: _toast(exp)),
      ],
    );
  }

  Widget _toast(Json exp) {
    final campaign = obj(exp['primaryCampaign']);
    final toast = obj(pick(campaign, ['nudges', 'toast']));
    final t = _theme(exp);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 448),
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            decoration: BoxDecoration(
              color: t.bg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: t.border.o(.4)),
              boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 50, offset: Offset(0, 25), spreadRadius: -12)],
            ),
            child: Row(
              children: [
                const DiyaIcon(size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    strOrNull(toast['message']) ?? strOrNull(pick(exp, ['copy', 'strip'])) ?? str(campaign['name']),
                    style: AppText.sans(size: 14, weight: FontWeight.w600, color: t.fg, height: 1.35),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () {
                    openExternal(festivalWaLink(campaign: campaign, slot: 'nudge.toast'));
                    setState(() => _toastVisible = false);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: const Color(0xFF1FA855), borderRadius: BorderRadius.circular(999)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const WhatsAppIcon(size: 16),
                      const SizedBox(width: 6),
                      Text('Ask us', style: AppText.sans(size: 12, weight: FontWeight.w700, color: Colors.white)),
                    ]),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: _dismissToast,
                  icon: Icon(LucideIcons.x, size: 16, color: t.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Festival accent line used by listing/category rails.
extension FxThemeOfExperience on Json {
  FxTheme get fxTheme => _theme(this);
  Json get fxCampaign => _campaign(this);
}

/// Keep [AppColors] import used for files that only need the theme helper.
const fxFallbackAccent = AppColors.gold;
