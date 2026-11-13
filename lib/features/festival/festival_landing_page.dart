import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/api/bmp_api.dart';
import '../../core/config.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/json.dart';
import '../../core/utils/launch.dart';
import '../../core/utils/leads.dart';
import '../../core/utils/nav.dart';
import '../../core/widgets/form_fields.dart';
import '../../core/widgets/site/site_page.dart';
import '../../core/widgets/site_image.dart';
import 'festival_state.dart';
import 'festival_widgets.dart';
import 'ornaments.dart';
import '../../core/widgets/ui.dart';

// `.fxl` palette from FestivalLandingPage.jsx
const _red = Color(0xFF8A1C23);
const _gold = Color(0xFFC8942E);
const _gold2 = Color(0xFFF6D77A);
const _cream = Color(0xFFFDF6EC);
const _ink = Color(0xFF2B1A14);
const _muted = Color(0xFF7A4A3A);
const _line = Color(0xFFF0DFC0);
const _wa = Color(0xFF1FA855);
const _heroBg = Color(0xFF5E1016);

TextStyle _dm({double size = 16, FontWeight weight = FontWeight.w400, Color color = _ink, double? height = 1.6, double? ls}) =>
    GoogleFonts.dmSans(fontSize: size, fontWeight: weight, color: color, height: height, letterSpacing: ls);

TextStyle _pf({double size = 30, Color color = _red, double height = 1.1, FontStyle? style}) =>
    GoogleFonts.playfairDisplay(fontSize: size, fontWeight: FontWeight.w700, color: color, height: height, fontStyle: style);

String _waLink(String msg) => 'https://wa.me/${AppConfig.whatsappNumber}?text=${Uri.encodeComponent(msg)}';

/// pages/festival/[slug].jsx + components/festival/landing/FestivalLandingPage.jsx
class FestivalLandingScreen extends ConsumerStatefulWidget {
  const FestivalLandingScreen({super.key, required this.slug});
  final String slug;

  @override
  ConsumerState<FestivalLandingScreen> createState() => _FestivalLandingScreenState();
}

class _FestivalLandingScreenState extends ConsumerState<FestivalLandingScreen> {
  final _scroll = ScrollController();
  Timer? _arm;
  double _lastY = 0;
  double _maxDepth = 0;
  bool _armed = false;

  @override
  void initState() {
    super.initState();
    // Lead-only exit intent (FestivalNudges): after 8 s, a fast scroll back up
    // once half the page has been read; shares the session budget.
    _arm = Timer(const Duration(seconds: 8), () => _armed = true);
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _arm?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_armed || !_scroll.hasClients || fxSessionFlags.contains(exitIntentSessionKey)) return;
    final y = _scroll.position.pixels;
    _maxDepth = math.max(_maxDepth, y / math.max(1, _scroll.position.maxScrollExtent));
    if (_maxDepth > .5 && _lastY - y > 250) {
      fxSessionFlags.add(exitIntentSessionKey);
      _showExit();
    }
    _lastY = y;
  }

  void _showExit() {
    final exp = useFestivalRead();
    if (exp == null) return;
    final c = exp.fxCampaign;
    final t = exp.fxTheme;
    showFestivalDialog(
      context,
      exp,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const DiyaIcon(size: 36),
          const SizedBox(height: 12),
          Text('Before you go — still planning your ${str(c['festivalName'])} puja?', style: AppText.heading(size: 24, color: t.fg)),
          const SizedBox(height: 12),
          Text(
            'Pandit slots for the coming ${str(c['festivalName'])} days fill up fast. Leave your number and we will hold one for you — no payment needed.',
            style: AppText.sans(size: 14, color: t.muted, height: 1.6),
          ),
          const SizedBox(height: 12),
          QuickLeadForm(experience: exp, slot: 'festival.exit', ctaLabel: 'Hold a pandit slot for me', successText: "We'll call you to confirm your slot.", compact: true),
          const SizedBox(height: 4),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            GestureDetector(
              onTap: () => openExternal(festivalWaLink(campaign: c, slot: 'festival.exit')),
              child: Text('WhatsApp', style: AppText.sans(size: 12, weight: FontWeight.w600, color: const Color(0xFF5FD68C))),
            ),
            const SizedBox(width: 16),
            GestureDetector(
              onTap: () => callPhone('+91$leadPhone'),
              child: Text('Call $leadPhoneLabel', style: AppText.sans(size: 12, weight: FontWeight.w600, color: t.muted)),
            ),
          ]),
        ]),
      ),
    );
  }

  Json? useFestivalRead() {
    final e = ref.read(festivalExperienceProvider(const FxKey('festival'))).value;
    return e != null && e['primaryCampaign'] is Map ? e : null;
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(festivalLandingProvider(widget.slug));
    final exp = useFestival(ref, 'festival');
    final landing = async.value;

    return SitePage(
      pageType: 'festival',
      scrollController: _scroll,
      bottomBar: exp != null ? FestivalStickyContact(experience: exp) : const StickyMobileContact(),
      children: [
        if (async.isLoading)
          const Padding(padding: EdgeInsets.symmetric(vertical: 120), child: AppSpinner())
        else if (landing == null)
          const NotFoundBody()
        else
          _LandingBody(landing: landing, experience: exp),
      ],
    );
  }
}

class _LandingBody extends StatelessWidget {
  const _LandingBody({required this.landing, required this.experience});
  final Json landing;
  final Json? experience;

  @override
  Widget build(BuildContext context) {
    final campaign = obj(landing['campaign']);
    final sections = objList(landing['sections']);
    final children = <Widget>[
      if (str(campaign['state']) == 'ended')
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(color: Color(0xFFFFF7E6), border: Border(bottom: BorderSide(color: _line))),
          child: Text(
            '${str(campaign['name'])} has concluded — this page stays up as a guide. Pujas below can still be booked year-round.',
            textAlign: TextAlign.center,
            style: _dm(size: 14, color: _muted),
          ),
        ),
    ];
    for (final s in sections) {
      final data = obj(s['data']);
      final id = str(s['id']);
      switch (str(s['type'])) {
        case 'hero':
          children.add(_Hero(data: data, landing: landing));
        case 'countdown':
          children.add(_Countdown(data: data));
        case 'features':
          children.add(_Features(data: data));
        case 'calendar':
          children.add(_Calendar(data: data, landing: landing));
        case 'poojaReferences':
          children.add(Anchor('poojas', child: _PoojaRefs(data: data, landing: landing, id: id)));
          children.add(_InlineLead(landing: landing, experience: experience));
        case 'offerings':
          children.add(_Offerings(data: data, landing: landing, experience: experience));
        case 'trust':
          children.add(_Trust(data: data));
        case 'faq':
          children.add(_Faq(data: data));
        case 'final':
          children.add(_Final(data: data, experience: experience));
      }
    }
    return Container(color: _cream, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children));
  }
}

Widget _sectionHead(Json d) {
  if (strOrNull(d['kicker']) == null && strOrNull(d['title']) == null && strOrNull(d['sub']) == null) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.only(bottom: 34),
    child: Column(children: [
      if (strOrNull(d['kicker']) != null) _kicker(str(d['kicker'])),
      if (strOrNull(d['title']) != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 6, 0, 10),
          child: Text(str(d['title']), textAlign: TextAlign.center, style: _pf(size: 30)),
        ),
      if (strOrNull(d['sub']) != null) Text(str(d['sub']), textAlign: TextAlign.center, style: _dm(color: _muted)),
    ]),
  );
}

Widget _kicker(String t, {TextAlign align = TextAlign.center}) =>
    Text(t.toUpperCase(), textAlign: align, style: _dm(size: 12, weight: FontWeight.w600, color: _gold, ls: 3.4));

Widget _btn(String label, {required Color bg, required Color fg, Color? border, required VoidCallback onTap, List<BoxShadow>? shadow}) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: border == null ? null : Border.all(color: border, width: 1.5),
          boxShadow: shadow,
        ),
        child: Text(label, textAlign: TextAlign.center, style: _dm(size: 15, weight: FontWeight.w600, color: fg, height: 1.2)),
      ),
    );

const _sectionPad = EdgeInsets.fromLTRB(20, 64, 20, 64);

class _Hero extends StatelessWidget {
  const _Hero({required this.data, required this.landing});
  final Json data;
  final Json landing;

  @override
  Widget build(BuildContext context) {
    final withForm = boolOf(data['showLeadForm']);
    final campaign = obj(landing['campaign']);
    final pills = list(data['pills']).map((e) => '$e').toList();
    final emblem = strOrNull(data['emblemUrl']);
    final w = MediaQuery.sizeOf(context).width;

    final copy = Column(children: [
      if (strOrNull(data['kicker']) != null) _kicker(str(data['kicker'])),
      Padding(
        padding: const EdgeInsets.fromLTRB(0, 10, 0, 14),
        child: Text.rich(
          TextSpan(children: [
            TextSpan(text: strOrNull(data['title']) ?? str(campaign['name'])),
            if (strOrNull(data['titleEmphasis']) != null)
              TextSpan(text: ' ${str(data['titleEmphasis'])}', style: const TextStyle(color: _gold2, fontStyle: FontStyle.italic)),
          ]),
          textAlign: TextAlign.center,
          style: _pf(size: 38, color: Colors.white),
        ),
      ),
      if (strOrNull(data['sub']) != null)
        Opacity(opacity: .95, child: Text(str(data['sub']), textAlign: TextAlign.center, style: _dm(size: 18, color: Colors.white))),
      if (pills.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 20, 0, 26),
          child: Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
            for (final p in pills)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), border: Border.all(color: _gold2.withValues(alpha: .6))),
                child: Text('✓ $p', style: _dm(size: 13, weight: FontWeight.w500, color: _gold2, height: 1.3)),
              ),
          ]),
        ),
      if (withForm)
        Padding(
          padding: const EdgeInsets.only(top: 22),
          child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (var i = 0; i < 7; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: DiyaIcon(size: i == 3 ? 32 : (i == 2 || i == 4 ? 28 : 24), glow: true),
              ),
          ]),
        )
      else
        _btn(strOrNull(data['ctaLabel']) ?? 'Book a puja',
            bg: _gold2, fg: _red, onTap: () => goHref(context, strOrNull(data['ctaHref']) ?? '#poojas')),
    ]);

    return Container(
      color: _heroBg,
      child: Stack(clipBehavior: Clip.hardEdge, children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(.7, -.8),
                radius: .9,
                colors: [const Color(0xBFB4401A), const Color(0xBFB4401A).withValues(alpha: 0)],
                stops: const [0, .7],
              ),
            ),
          ),
        ),
        Positioned(
          left: w / 2 - 280,
          top: -180,
          child: const MandalaWatermark(size: 560, color: _gold2, opacity: .12),
        ),
        Column(children: [
          const ToranGarland(height: 22),
          Padding(
            padding: EdgeInsets.fromLTRB(20, withForm ? 24 : 20, 20, 44),
            child: Column(children: [
              if (!withForm) ...[
                if (emblem != null)
                  SiteImage(emblem, width: 220, height: 220, fit: BoxFit.contain, placeholderColor: Colors.transparent)
                else
                  Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [_gold2.withValues(alpha: .25), Colors.transparent], stops: const [0, .7]),
                    ),
                    child: const Center(child: DiyaIcon(size: 160)),
                  ),
                const SizedBox(height: 10),
              ],
              copy,
              if (withForm) ...[
                const SizedBox(height: 18),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Stack(clipBehavior: Clip.none, alignment: Alignment.topCenter, children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 38),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(20, 44, 20, 20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: const Border(top: BorderSide(color: _gold2, width: 3)),
                          boxShadow: const [BoxShadow(color: Color(0x59280508), blurRadius: 60, offset: Offset(0, 24))],
                        ),
                        child: FestivalLeadForm(
                          config: obj(data['leadForm']),
                          festivalName: str(campaign['festivalName']),
                        ),
                      ),
                    ),
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const RadialGradient(center: Alignment(0, -.2), colors: [Color(0xFF7A1A20), Color(0xFF4A0B10)]),
                        border: Border.all(color: _gold2, width: 2),
                        boxShadow: [
                          BoxShadow(color: _gold2.withValues(alpha: .14), spreadRadius: 6),
                          const BoxShadow(color: Color(0x8CFFB020), blurRadius: 34),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: emblem != null
                          ? ClipOval(child: SiteImage(emblem, width: 56, height: 56, fit: BoxFit.contain, placeholderColor: Colors.transparent))
                          : const DiyaIcon(size: 44),
                    ),
                  ]),
                ),
              ],
            ]),
          ),
        ]),
      ]),
    );
  }
}

class _Countdown extends StatefulWidget {
  const _Countdown({required this.data});
  final Json data;
  @override
  State<_Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<_Countdown> {
  Timer? _t;
  ({String label, int d, int h, int m})? _state;

  @override
  void initState() {
    super.initState();
    _tick();
    _t = Timer.periodic(const Duration(seconds: 30), (_) => _tick());
  }

  void _tick() {
    final now = DateTime.now();
    final targets = objList(widget.data['targets'])
        .map((t) => (DateTime.tryParse(str(t['at'])), str(t['label'])))
        .where((t) => t.$1 != null)
        .toList();
    final target = targets.where((t) => t.$1!.isAfter(now)).firstOrNull;
    setState(() {
      if (target == null) {
        _state = null;
      } else {
        final s = target.$1!.difference(now).inSeconds;
        _state = (label: target.$2, d: s ~/ 86400, h: (s % 86400) ~/ 3600, m: (s % 3600) ~/ 60);
      }
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = _state;
    if (s == null) return const SizedBox.shrink();
    Widget cell(int v, String l) => Container(
          constraints: const BoxConstraints(minWidth: 62),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          margin: const EdgeInsets.symmetric(horizontal: 5),
          decoration: BoxDecoration(color: _red, borderRadius: BorderRadius.circular(10)),
          child: Column(children: [
            Text('$v', style: _dm(size: 24, weight: FontWeight.w700, color: Colors.white, height: 1.1)),
            Opacity(opacity: .85, child: Text(l.toUpperCase(), style: _dm(size: 11, color: Colors.white, ls: 1.1))),
          ]),
        );
    return Container(
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: _line))),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, spacing: 22, runSpacing: 12, children: [
        Text(s.label, style: _dm(weight: FontWeight.w600, color: _red)),
        Row(mainAxisSize: MainAxisSize.min, children: [cell(s.d, 'days'), cell(s.h, 'hrs'), cell(s.m, 'min')]),
      ]),
    );
  }
}

class _Features extends StatelessWidget {
  const _Features({required this.data});
  final Json data;

  @override
  Widget build(BuildContext context) => Padding(
        padding: _sectionPad,
        child: Column(children: [
          _sectionHead(data),
          for (final f in objList(data['items']))
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _line)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 42,
                  height: 42,
                  margin: const EdgeInsets.only(bottom: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: const Color(0xFFFBEFD9), borderRadius: BorderRadius.circular(12)),
                  child: Text(str(f['icon']), style: const TextStyle(fontSize: 22)),
                ),
                Text(str(f['title']), style: _dm(size: 16, weight: FontWeight.w600, color: _red)),
                const SizedBox(height: 4),
                Text(str(f['text']), style: _dm(size: 14, color: _muted)),
              ]),
            ),
        ]),
      );
}

class _Calendar extends StatelessWidget {
  const _Calendar({required this.data, required this.landing});
  final Json data;
  final Json landing;

  @override
  Widget build(BuildContext context) {
    final days = objList(landing['days']);
    final keyDates = objList(data['keyDates']);
    return Padding(
      padding: _sectionPad.copyWith(top: 0),
      child: Column(children: [
        _sectionHead(data),
        if (days.isNotEmpty)
          LayoutBuilder(builder: (ctx, c) {
            final w = (c.maxWidth - 10) / 2;
            return Wrap(spacing: 10, runSpacing: 10, children: [for (final d in days) SizedBox(width: w, child: _day(d))]);
          }),
        if (keyDates.isNotEmpty) ...[
          const SizedBox(height: 20),
          for (final k in keyDates)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(color: _red, borderRadius: BorderRadius.circular(16)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(str(k['k']).toUpperCase(), style: _dm(size: 12, weight: FontWeight.w600, color: _gold2, ls: 1.9)),
                const SizedBox(height: 2),
                Text(str(k['v']), style: _dm(size: 18, weight: FontWeight.w600, color: Colors.white)),
                if (strOrNull(k['x']) != null) Opacity(opacity: .85, child: Text(str(k['x']), style: _dm(size: 13, color: Colors.white))),
              ]),
            ),
        ],
        if (strOrNull(data['note']) != null)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text(str(data['note']), textAlign: TextAlign.center, style: _dm(size: 13, color: _muted)),
          ),
      ]),
    );
  }

  Widget _day(Json d) {
    final today = str(d['state']) == 'today';
    final past = str(d['state']) == 'past';
    final color = parseHexColor(strOrNull(d['color'])) ?? _gold;
    final inner = Column(children: [
      Container(
        height: today ? 12 : 10,
        decoration: BoxDecoration(
          color: color,
          border: str(d['color']) == '#FFFFFF' ? const Border(bottom: BorderSide(color: Color(0xFFEEEEEE))) : null,
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(10, 14, 10, 16),
        child: Column(children: [
          if (today)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.fromLTRB(8, 3, 10, 3),
              decoration: BoxDecoration(color: _gold2, borderRadius: BorderRadius.circular(999)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 7, height: 7, decoration: const BoxDecoration(color: Color(0xFFD6262F), shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text('TODAY', style: _dm(size: 10.5, weight: FontWeight.w700, color: _red, ls: 1.5, height: 1.2)),
              ]),
            ),
          Text.rich(
            TextSpan(children: [
              if (past) const TextSpan(text: '✓ ', style: TextStyle(color: _wa)),
              TextSpan(text: str(d['label']).toUpperCase()),
            ]),
            style: _dm(size: 11, weight: FontWeight.w600, color: today ? _gold2 : _gold, ls: 1.5),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(str(d['name']).split(' · ').last.replaceFirst(RegExp('^Maa '), ''),
                textAlign: TextAlign.center, style: _pf(size: 16, color: today ? Colors.white : _red, height: 1.2)),
          ),
          Text(
            '${str(d['shortDate'])}${strOrNull(d['colorName']) != null ? '\n${str(d['colorName'])}' : ''}',
            textAlign: TextAlign.center,
            style: _dm(size: 12, color: today ? const Color(0xFFF6E3C0) : _muted),
          ),
        ]),
      ),
    ]);
    final card = Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: today ? null : Colors.white,
        gradient: today ? const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFA3242D), _red, _heroBg]) : null,
        borderRadius: BorderRadius.circular(14),
        border: today ? null : Border.all(color: _line),
        boxShadow: today ? const [BoxShadow(color: Color(0x478A1C23), blurRadius: 26, offset: Offset(0, 12))] : null,
      ),
      child: inner,
    );
    if (past) return Opacity(opacity: .62, child: card);
    if (today) return Transform.translate(offset: const Offset(0, -6), child: Transform.scale(scale: 1.04, child: card));
    return card;
  }
}

class _PoojaRefs extends ConsumerWidget {
  const _PoojaRefs({required this.data, required this.landing, required this.id});
  final Json data;
  final Json landing;
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ll = festivalLocLang(ref);
    final days = objList(landing['days']);
    final activeKey = str(pick(landing, ['activeDay', 'key']));
    final today = days.where((d) => str(d['key']) == activeKey).firstOrNull;
    final parent = list(landing['parentPoojaSlugs']).map((e) => '$e').toList();
    final scope = str(data['scope']);
    List<String>? slugs;
    if (scope == 'parent') {
      slugs = parent;
    } else if (scope == 'today') {
      final t = list(today?['poojaSlugs']).map((e) => '$e').toList();
      slugs = t.isNotEmpty ? t : parent;
    }
    final all = objList(landing['poojas']);
    final poojas = slugs == null ? all : all.where((p) => slugs!.contains(str(p['slug']))).toList();
    final campaign = obj(landing['campaign']);

    return Container(
      decoration: const BoxDecoration(color: Colors.white, border: Border.symmetric(horizontal: BorderSide(color: _line))),
      padding: _sectionPad,
      child: Column(children: [
        _sectionHead(data),
        if (boolOf(landing['cityKnown']))
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Text.rich(
              TextSpan(children: [
                const TextSpan(text: 'Showing live packages for '),
                TextSpan(text: titleCase(ll.language), style: const TextStyle(fontWeight: FontWeight.w700)),
                const TextSpan(text: ' pandits in '),
                TextSpan(text: titleCase(ll.location), style: const TextStyle(fontWeight: FontWeight.w700)),
                const TextSpan(text: ' · '),
                WidgetSpan(
                  child: GestureDetector(
                    onTap: () => context.push('/${ll.language}/${ll.location}/pooja'),
                    child: Text('browse all pujas', style: _dm(size: 14, color: _red).copyWith(decoration: TextDecoration.underline)),
                  ),
                ),
              ]),
              textAlign: TextAlign.center,
              style: _dm(size: 14, color: _muted),
            ),
          ),
        if (poojas.isNotEmpty)
          for (final p in poojas)
            GestureDetector(
              onTap: () => goHref(context, buildPoojaHref(p, ll.language, ll.location)),
              child: Container(
                margin: const EdgeInsets.only(bottom: 18),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(color: _cream, borderRadius: BorderRadius.circular(18), border: Border.all(color: _line)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  AspectRatio(aspectRatio: 1, child: SiteImage(strOrNull(p['image']) ?? '/images/Poojas1.jpg', alignment: Alignment.topCenter)),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if (strOrNull(p['label']) != null)
                        Row(children: [
                          Container(width: 18, height: 1, color: _gold.withValues(alpha: .7)),
                          const SizedBox(width: 8),
                          Flexible(child: Text(str(p['label']).toUpperCase(), style: _dm(size: 11, weight: FontWeight.w600, color: _gold, ls: 1.8, height: 1.4))),
                        ]),
                      const SizedBox(height: 4),
                      Text(str(p['name']), style: _pf(size: 21, height: 1.15)),
                      if (numOf(p['startingPrice']) > 0) ...[
                        const SizedBox(height: 4),
                        Text.rich(
                          TextSpan(children: [
                            const TextSpan(text: 'From '),
                            TextSpan(
                              text: FestivalPoojaCard.formatPrice(numOf(p['startingPrice'])),
                              style: const TextStyle(fontWeight: FontWeight.w700, color: _ink),
                            ),
                          ]),
                          style: _dm(size: 14, color: _muted),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text('View packages →', style: _dm(size: 14, weight: FontWeight.w600, color: _red)),
                    ]),
                  ),
                ]),
              ),
            )
        else
          Column(children: [
            Text(strOrNull(data['emptyText']) ?? 'These pujas are not available for your city and language yet.',
                textAlign: TextAlign.center, style: _dm(color: _muted)),
            const SizedBox(height: 14),
            _btn('WhatsApp 9869 92 92 92',
                bg: _wa,
                fg: Colors.white,
                onTap: () => openExternal(_waLink("Namaste BookMyPooja 🙏 I'd like help with a ${str(campaign['festivalName'])} puja."))),
          ]),
      ]),
    );
  }
}

class _InlineLead extends StatelessWidget {
  const _InlineLead({required this.landing, required this.experience});
  final Json landing;
  final Json? experience;

  @override
  Widget build(BuildContext context) {
    final campaign = obj(landing['campaign']);
    final t = FxTheme.of(str(campaign['themePreset']));
    return Padding(
      padding: _sectionPad.copyWith(top: 0),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: t.bg, borderRadius: BorderRadius.circular(24)),
        child: Stack(children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(center: const Alignment(1, -1), radius: 1, colors: [t.bg2.withValues(alpha: .8), t.bg2.withValues(alpha: 0)], stops: const [0, .7]),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const DiyaIcon(size: 40),
              const SizedBox(height: 12),
              Text("Didn't find your puja, or want a custom ${str(campaign['festivalName'])} package?",
                  style: AppText.heading(size: 24, color: t.fg)),
              const SizedBox(height: 12),
              Text(
                'Tell us what you need — our pandit team will call you with muhurat, samagri and a price for your city. Free, no obligation.',
                style: AppText.sans(size: 14, color: t.muted, height: 1.6),
              ),
              const SizedBox(height: 12),
              for (final l in const ['✓ Verified pandits in your language', '✓ Samagri included, on-time arrival', '✓ Call back within 10 minutes'])
                Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(l, style: AppText.sans(size: 14, color: t.fg))),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: t.card.withValues(alpha: .6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: t.border.withValues(alpha: .35)),
                ),
                child: Column(children: [
                  QuickLeadForm(experience: experience, slot: 'festival.inline', ctaLabel: 'Get my free puja plan', compact: true),
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.only(top: 12),
                    decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.white.withValues(alpha: .1)))),
                    child: Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, runSpacing: 8, children: [
                      SizedBox(width: 140, child: FxWhatsAppButton(experience: experience, slot: 'festival.inline', label: 'WhatsApp', height: 36)),
                      GestureDetector(
                        onTap: () => callPhone('+91$leadPhone'),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.phone_outlined, size: 16, color: t.fg),
                          const SizedBox(width: 6),
                          Text('Call $leadPhoneLabel', style: AppText.sans(size: 14, weight: FontWeight.w600, color: t.fg)),
                        ]),
                      ),
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

class _Offerings extends StatelessWidget {
  const _Offerings({required this.data, required this.landing, required this.experience});
  final Json data;
  final Json landing;
  final Json? experience;

  @override
  Widget build(BuildContext context) => Padding(
        padding: _sectionPad.copyWith(top: 0),
        child: Column(children: [
          _sectionHead(data),
          for (final p in objList(data['items'])) _card(context, p),
          if (boolOf(data['showGuidanceCard']))
            _card(context, {
              'when': 'Not sure?',
              'title': 'Free guidance',
              'text': 'Talk to our Puja Seva Team about muhurat, vidhi, or which puja suits your family. No obligation.',
            }, guidance: true),
        ]),
      );

  Widget _card(BuildContext context, Json p, {bool guidance = false}) {
    final feature = boolOf(p['feature']);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: feature ? _red : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: feature ? null : Border.all(color: _line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (strOrNull(p['when']) != null)
          Text(str(p['when']).toUpperCase(), style: _dm(size: 12, weight: FontWeight.w600, color: feature ? _gold2 : _gold, ls: 1.7)),
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
          child: Text(str(p['title']), style: _pf(size: 25, color: feature ? _gold2 : _red)),
        ),
        Text(str(p['text']), style: _dm(size: 14.5, color: feature ? const Color(0xFFF6E3C0) : _muted)),
        const SizedBox(height: 16),
        if (guidance) ...[
          _btn('Call 9869 92 92 92', bg: Colors.transparent, fg: _red, border: _red, onTap: () => callPhone('9869929292')),
          const SizedBox(height: 10),
          _btn('Request a callback',
              bg: _red,
              fg: Colors.white,
              shadow: const [BoxShadow(color: Color(0x478A1C23), blurRadius: 18, offset: Offset(0, 6))],
              onTap: () => openFestivalCallback(context, experience, slot: 'festival.guidance')),
        ] else
          _btn(strOrNull(p['cta']) ?? 'Book on WhatsApp',
              bg: feature ? _gold2 : Colors.transparent,
              fg: _red,
              border: feature ? null : _red,
              onTap: () => openExternal(_waLink(strOrNull(p['waMessage']) ?? 'Namaste BookMyPooja 🙏 ${str(p['title'])}'))),
      ]),
    );
  }
}

class _Trust extends StatelessWidget {
  const _Trust({required this.data});
  final Json data;

  @override
  Widget build(BuildContext context) {
    final stats = objList(data['stats']);
    return Container(
      decoration: const BoxDecoration(color: Colors.white, border: Border.symmetric(horizontal: BorderSide(color: _line))),
      padding: _sectionPad,
      child: Column(children: [
        LayoutBuilder(builder: (ctx, c) {
          final w = (c.maxWidth - 24) / 2;
          return Wrap(spacing: 24, runSpacing: 24, children: [
            for (final s in stats)
              SizedBox(
                width: w,
                child: Column(children: [
                  Text(str(s['value']), style: _pf(size: 40, height: 1)),
                  Text(str(s['label']), textAlign: TextAlign.center, style: _dm(size: 14, color: _muted)),
                ]),
              ),
          ]);
        }),
        if (strOrNull(data['seen']) != null)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Text(str(data['seen']), textAlign: TextAlign.center, style: _dm(size: 14, color: _muted)),
          ),
      ]),
    );
  }
}

class _Faq extends StatelessWidget {
  const _Faq({required this.data});
  final Json data;

  @override
  Widget build(BuildContext context) => Padding(
        padding: _sectionPad,
        child: Column(children: [
          _sectionHead(data),
          for (final f in objList(data['items'])) _FaqItem(q: str(f['q']), a: str(f['a'])),
        ]),
      );
}

class _FaqItem extends StatefulWidget {
  const _FaqItem({required this.q, required this.a});
  final String q;
  final String a;
  @override
  State<_FaqItem> createState() => _FaqItemState();
}

class _FaqItemState extends State<_FaqItem> {
  bool _open = false;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => setState(() => _open = !_open),
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: _line)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Text(widget.q, style: _dm(weight: FontWeight.w600, color: _red))),
              const SizedBox(width: 12),
              Text(_open ? '–' : '+', style: _dm(size: 22, color: _red, height: 1)),
            ]),
            if (_open) Padding(padding: const EdgeInsets.only(top: 8), child: Text(widget.a, style: _dm(size: 15, color: _muted))),
          ]),
        ),
      );
}

class _Final extends StatelessWidget {
  const _Final({required this.data, required this.experience});
  final Json data;
  final Json? experience;

  @override
  Widget build(BuildContext context) => Container(
        color: _heroBg,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 64),
        child: Column(children: [
          Text(str(data['title']), textAlign: TextAlign.center, style: _pf(size: 30, color: _gold2)),
          const SizedBox(height: 10),
          if (strOrNull(data['sub']) != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Opacity(opacity: .92, child: Text(str(data['sub']), textAlign: TextAlign.center, style: _dm(color: Colors.white))),
            ),
          Wrap(alignment: WrapAlignment.center, spacing: 12, runSpacing: 12, children: [
            if (strOrNull(data['primaryLabel']) != null)
              _btn(str(data['primaryLabel']), bg: _gold2, fg: _red, onTap: () => goHref(context, strOrNull(data['primaryHref']) ?? '#poojas')),
            if (strOrNull(data['whatsappMessage']) != null)
              _btn('WhatsApp 9869 92 92 92', bg: _wa, fg: Colors.white, onTap: () => openExternal(_waLink(str(data['whatsappMessage'])))),
            _btn('Request a callback',
                bg: Colors.transparent,
                fg: Colors.white,
                border: Colors.white.withValues(alpha: .6),
                onTap: () => openFestivalCallback(context, experience, slot: 'festival.final')),
          ]),
        ]),
      );
}

// ---------------------------------------------------------------------------
// landing/FestivalLeadForm.jsx
// ---------------------------------------------------------------------------

class FestivalLeadForm extends StatefulWidget {
  const FestivalLeadForm({super.key, required this.config, required this.festivalName});
  final Json config;
  final String festivalName;

  @override
  State<FestivalLeadForm> createState() => _FestivalLeadFormState();
}

class _FestivalLeadFormState extends State<FestivalLeadForm> {
  static const _ccs = ['91', '1', '44', '971', '65', '61', 'other'];
  static const _defaultCities = ['Bengaluru', 'Mumbai', 'Pune', 'Hyderabad', 'Chennai', 'Delhi NCR', 'Other city in India', 'Outside India'];
  static const _defaultLangs = ['Kannada', 'Hindi', 'Marathi', 'Tamil', 'Telugu', 'Malayalam', 'Gujarati', 'Bengali', 'Odia', 'Marwari'];

  final _name = TextEditingController();
  final _phone = TextEditingController();
  String _cc = '91';
  String? _city;
  String? _lang;
  final List<String> _interests = [];
  bool _consent = true;
  bool _submitting = false;
  ({String name, String interests})? _done;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  String get _phoneError {
    final p = _phone.text;
    if (p.isEmpty) return '';
    if (_cc == '91' && !RegExp(r'^[6-9]\d{9}$').hasMatch(p)) return 'Please enter a valid 10-digit Indian mobile number.';
    if (_cc != '91' && p.length < 7) return 'Please enter a valid WhatsApp number.';
    return '';
  }

  bool get _complete => _name.text.trim().length >= 2 && _phone.text.isNotEmpty && _phoneError.isEmpty && _city != null && _consent;

  Future<void> _submit() async {
    if (!_complete || _submitting) return;
    setState(() => _submitting = true);
    final c = widget.config;
    final code = str(c['campaignCode'], 'FEST');
    final name = _name.text.trim();
    final phone = _cc == '91' || _cc == 'other' ? _phone.text : '+$_cc${_phone.text}';
    final chosen = _interests.join(', ');
    final source = strOrNull(c['source']) ?? '${widget.festivalName} festival page';
    try {
      final payload = createCrmLeadEnquiryBody({
        'name': name,
        'phone': phone,
        'city': _city,
        'language': _lang ?? 'Any / not sure',
        'enquiry': '$source - Campaign: $code - Interested in: ${chosen.isEmpty ? 'NA' : chosen}',
      });
      await BmpApi.postGlobalLeadCapture({
        ...payload,
        crmLeadsFieldMap['pujaType']!: chosen.isEmpty ? '${widget.festivalName} enquiry' : chosen,
        'source': source,
        'webPageLink': AppConfig.siteUrl,
      });
    } catch (_) {}
    final guide = strOrNull(c['guideDownloadUrl']);
    if (guide != null) openExternal(guide);
    setState(() {
      _submitting = false;
      _done = (name: name, interests: chosen);
    });
  }

  InputDecoration _deco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: _dm(size: 15, color: _muted.withValues(alpha: .7)),
        filled: true,
        fillColor: const Color(0xFFFFFDF8),
        counterText: '',
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE6D3B3), width: 1.5)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _red, width: 1.5)),
      );

  Widget _label(String t) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(t, style: _dm(size: 13, weight: FontWeight.w600, color: _red)));

  Widget _select(String? value, List<String> options, String placeholder, ValueChanged<String> onChanged) => AppSelectField<String>(
        value: value,
        placeholder: placeholder,
        options: options,
        labelOf: (v) => v,
        minHeight: 46,
        radius: 12,
        fill: const Color(0xFFFFFDF8),
        borderColor: const Color(0xFFE6D3B3),
        textStyle: _dm(size: 15),
        onChanged: onChanged,
      );

  @override
  Widget build(BuildContext context) {
    final c = widget.config;
    final cities = list(c['cities']).isNotEmpty ? list(c['cities']).map((e) => '$e').toList() : _defaultCities;
    final langs = list(c['languages']).isNotEmpty ? list(c['languages']).map((e) => '$e').toList() : _defaultLangs;
    final interests = list(c['interests']).map((e) => '$e').toList();
    final code = str(c['campaignCode'], 'FEST');
    final guide = strOrNull(c['guideDownloadUrl']);

    if (_done != null) {
      final d = _done!;
      final waMsg =
          'Namaste BookMyPooja 🙏 ${guide != null ? 'Please send me the ${widget.festivalName} guide.' : "I'd like help with a ${widget.festivalName} puja."}\nName: ${d.name}\nCity: $_city'
          '${_lang != null ? '\nLanguage: $_lang' : ''}${d.interests.isNotEmpty ? '\nInterested in: ${d.interests}' : ''}\n[$code]';
      return Column(children: [
        Container(
          width: 62,
          height: 62,
          margin: const EdgeInsets.fromLTRB(0, 6, 0, 10),
          decoration: const BoxDecoration(color: Color(0xFFE8F6EC), shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text('✓', style: _dm(size: 30, color: _wa)),
        ),
        Text('Thank you, ${d.name.split(' ').first}!', textAlign: TextAlign.center, style: _pf(size: 30)),
        Text(
          guide != null
              ? 'Your guide is downloading. Get it on WhatsApp too so it stays saved in your chats.'
              : 'Our Puja Seva team will reach out shortly. You can also message us on WhatsApp right away.',
          textAlign: TextAlign.center,
          style: _dm(size: 13, color: _muted),
        ),
        if (guide != null) ...[
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: _btn('⬇ Download the PDF', bg: _red, fg: Colors.white, onTap: () => openExternal(guide))),
        ],
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, child: _btn('Continue on WhatsApp', bg: _wa, fg: Colors.white, onTap: () => openExternal(_waLink(waMsg)))),
      ]);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(strOrNull(c['title']) ?? 'Get a callback', textAlign: TextAlign.center, style: _pf(size: 30)),
      if (strOrNull(c['sub']) != null) Text(str(c['sub']), textAlign: TextAlign.center, style: _dm(size: 13, color: _muted)),
      const SizedBox(height: 16),
      _label('Your name'),
      TextField(
        controller: _name,
        onChanged: (_) => setState(() {}),
        style: _dm(size: 15),
        textCapitalization: TextCapitalization.words,
        decoration: _deco('e.g. Priya Sharma'),
      ),
      const SizedBox(height: 12),
      _label('WhatsApp number'),
      Row(children: [
        SizedBox(width: 96, child: _select(_cc, _ccs, '+91', (v) => setState(() => _cc = v))),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            maxLength: _cc == '91' ? 10 : 15,
            onChanged: (v) {
              final dgt = v.replaceAll(RegExp(r'\D'), '');
              if (dgt != v) _phone.text = dgt;
              setState(() {});
            },
            style: _dm(size: 15),
            decoration: _deco('10-digit mobile'),
          ),
        ),
      ]),
      const SizedBox(height: 12),
      _label('City'),
      _select(_city, cities, 'Select city', (v) => setState(() => _city = v)),
      const SizedBox(height: 12),
      _label('Pandit language'),
      _select(_lang, langs, 'Any / not sure', (v) => setState(() => _lang = v)),
      if (interests.isNotEmpty) ...[
        const SizedBox(height: 12),
        _label('Interested in a puja? (optional)'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final v in interests)
            GestureDetector(
              onTap: () => setState(() => _interests.contains(v) ? _interests.remove(v) : _interests.add(v)),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _interests.contains(v) ? const Color(0xFFFDECEB) : const Color(0xFFFFFDF8),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: _interests.contains(v) ? _red : const Color(0xFFE6D3B3), width: 1.5),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  AppCheckbox(value: _interests.contains(v), color: _red, onChanged: (_) {}),
                  const SizedBox(width: 6),
                  Text(v, style: _dm(size: 13, weight: FontWeight.w500, color: _interests.contains(v) ? _red : _ink)),
                ]),
              ),
            ),
        ]),
      ],
      const SizedBox(height: 12),
      GestureDetector(
        onTap: () => setState(() => _consent = !_consent),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(top: 4), child: AppCheckbox(value: _consent, color: _red, onChanged: (v) => setState(() => _consent = v))),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              strOrNull(c['consentText']) ?? 'I agree to be contacted by BookMyPooja on WhatsApp. Reply STOP anytime.',
              style: _dm(size: 12.5, color: _muted),
            ),
          ),
        ]),
      ),
      if (_phoneError.isNotEmpty) ...[
        const SizedBox(height: 12),
        Text(_phoneError, style: _dm(size: 13, color: const Color(0xFFC62828))),
      ],
      const SizedBox(height: 12),
      Opacity(
        opacity: _complete && !_submitting ? 1 : .5,
        child: GestureDetector(
          onTap: _complete && !_submitting ? _submit : null,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: BoxDecoration(
              color: _red,
              borderRadius: BorderRadius.circular(999),
              boxShadow: const [BoxShadow(color: Color(0x478A1C23), blurRadius: 18, offset: Offset(0, 6))],
            ),
            child: Text(_submitting ? 'Sending…' : (strOrNull(c['submitLabel']) ?? 'Submit →'),
                textAlign: TextAlign.center, style: _dm(weight: FontWeight.w600, color: Colors.white, height: 1.2)),
          ),
        ),
      ),
    ]);
  }
}
