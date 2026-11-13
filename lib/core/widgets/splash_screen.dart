import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';

/// Animated launch sequence drawn over the app while it boots underneath.
///
/// Night → a comet of light sweeps an arc over the diya emblem, which lights
/// up; a wave of dawn (cream) washes outward from it with ripples echoing the
/// logo's rings; the emblem rises and the "BOOK MY Pooja" wordmark is
/// revealed with a golden shimmer and a closing twinkle. Then the overlay
/// fades away into the app.
///
/// The first frame is a flat [nativeColor], the same colour as the Android
/// launch window, so the native → Flutter hand-off is seamless.
class SplashOverlay extends StatefulWidget {
  const SplashOverlay({super.key, required this.child});
  final Widget child;

  /// Keep in sync with `@color/splash_background` (android res/values/colors.xml).
  static const nativeColor = Color(0xFF3A070D);

  @override
  State<SplashOverlay> createState() => _SplashOverlayState();
}

class _SplashOverlayState extends State<SplashOverlay> with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 3600));
  late final AnimationController _exit = AnimationController(vsync: this, duration: const Duration(milliseconds: 550));
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _intro.addStatusListener((s) async {
      if (s != AnimationStatus.completed) return;
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;
      await _exit.forward();
      if (mounted) setState(() => _done = true);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.of(context).disableAnimations) {
        _intro.value = 1;
        _exit.forward().then((_) => mounted ? setState(() => _done = true) : null);
      } else {
        _intro.forward();
      }
    });
  }

  @override
  void dispose() {
    _intro.dispose();
    _exit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return widget.child;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        AnimatedBuilder(
          animation: Listenable.merge([_intro, _exit]),
          builder: (context, _) {
            final e = Curves.easeInCubic.transform(_exit.value);
            return IgnorePointer(
              ignoring: _exit.value > 0,
              child: Opacity(
                opacity: 1 - e,
                child: Transform.scale(scale: 1 + .06 * e, child: _SplashScene(t: _intro.value)),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Timeline (fractions of the intro)
// ---------------------------------------------------------------------------

double _seg(double t, double a, double b, [Curve curve = Curves.linear]) =>
    curve.transform(((t - a) / (b - a)).clamp(0.0, 1.0));

const _arcStart = .05, _arcEnd = .40;
const _emblemIn = (.20, .44);
const _dawn = (.40, .62);
const _rise = (.50, .72);
const _wordmark = (.58, .82);
const _shimmer = (.80, .97);
const _ornament = (.76, .92);
const _twinkle = (.84, 1.0);

const _gold = Color(0xFFFFD27A);
const _goldDeep = Color(0xFFF2A93B);
const _goldPale = Color(0xFFFFF1CF);
const _nightCenter = Color(0xFF7A1622);
const _nightEdge = Color(0xFF220307);
const _flame = Color(0xFFF2582F);

/// Where everything sits for a given screen size and moment.
class _Layout {
  _Layout(Size s, double t) {
    emW = math.min(124, s.width * .32);
    emH = emW * 242 / 204;
    wmW = math.min(236, s.width * .62);
    wmH = wmW * 306 / 506;
    const gap = 20.0, ornamentH = 22.0;
    final groupH = emH + gap + wmH + ornamentH;
    final cx = s.width / 2, cy = s.height / 2 - 12;
    final start = Offset(cx, cy);
    final end = Offset(cx, cy - groupH / 2 + emH / 2);
    emblemCenter = Offset.lerp(start, end, _seg(t, _rise.$1, _rise.$2, Curves.easeInOutCubic))!;
    wordmark = Rect.fromLTWH(cx - wmW / 2, end.dy + emH / 2 + gap, wmW, wmH);
    ornamentY = wordmark.bottom + 12;
    arcCenter = start + Offset(0, emW * .12);
    arcRx = math.min(s.width * .44, 190);
    arcRy = arcRx * .86;
  }

  late double emW, emH, wmW, wmH, ornamentY, arcRx, arcRy;
  late Offset emblemCenter, arcCenter;
  late Rect wordmark;

  /// The comet's path: from lower-left, over the top, to lower-right.
  static const a0 = math.pi * .86, a1 = math.pi * 2.14;
  Offset arcPoint(double a) => arcCenter + Offset(arcRx * math.cos(a), arcRy * math.sin(a));

  /// Flame tip glow, relative to the emblem artwork.
  Offset get flame => emblemCenter + Offset(-emW * .01, emH * .1);
}

class _SplashScene extends StatelessWidget {
  const _SplashScene({required this.t});
  final double t;

  @override
  Widget build(BuildContext context) {
    final dawn = _seg(t, _dawn.$1, _dawn.$2, Curves.easeInOutCubic);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (dawn < .35 ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
          .copyWith(statusBarColor: Colors.transparent, systemNavigationBarColor: Colors.transparent),
      child: LayoutBuilder(builder: (context, c) {
        final size = c.biggest;
        final l = _Layout(size, t);
        final emIn = _seg(t, _emblemIn.$1, _emblemIn.$2);
        final wm = _seg(t, _wordmark.$1, _wordmark.$2, Curves.easeOutCubic);
        return Stack(fit: StackFit.expand, children: [
          RepaintBoundary(child: CustomPaint(painter: _BackdropPainter(t: t, l: l))),

          // Emblem
          Positioned(
            left: l.emblemCenter.dx - l.emW / 2,
            top: l.emblemCenter.dy - l.emH / 2,
            width: l.emW,
            height: l.emH,
            child: Opacity(
              opacity: Curves.easeOut.transform(emIn),
              child: Transform.scale(
                scale: .62 + .38 * Curves.easeOutBack.transform(emIn),
                child: SvgPicture.asset('assets/images/splash/emblem.svg', fit: BoxFit.contain),
              ),
            ),
          ),

          // Wordmark: soft left→right wipe, then a golden shimmer across it.
          Positioned.fromRect(
            rect: l.wordmark.shift(Offset(0, 14 * (1 - wm))),
            child: Opacity(
              opacity: Curves.easeOut.transform(_seg(t, _wordmark.$1, _wordmark.$1 + .1)),
              child: ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (r) {
                  final edge = -.15 + 1.3 * wm;
                  return LinearGradient(
                    colors: const [Colors.white, Colors.white, Colors.transparent],
                    stops: [0, edge.clamp(0.0, 1.0), (edge + .15).clamp(0.0, 1.0)],
                  ).createShader(r);
                },
                child: ShaderMask(
                  blendMode: BlendMode.srcATop,
                  shaderCallback: (r) {
                    final s = _seg(t, _shimmer.$1, _shimmer.$2, Curves.easeInOutSine);
                    final x = -.3 + 1.6 * s;
                    return LinearGradient(
                      begin: const Alignment(-1, -.4),
                      end: const Alignment(1, .4),
                      colors: [Colors.transparent, _goldDeep.withValues(alpha: .95), Colors.transparent],
                      stops: [(x - .14).clamp(0.0, 1.0), x.clamp(0.0, 1.0), (x + .14).clamp(0.0, 1.0)],
                    ).createShader(r);
                  },
                  child: SvgPicture.asset('assets/images/splash/wordmark.svg', fit: BoxFit.contain),
                ),
              ),
            ),
          ),

          RepaintBoundary(child: CustomPaint(painter: _FxPainter(t: t, l: l))),
        ]);
      }),
    );
  }
}

// ---------------------------------------------------------------------------
// Backdrop: night sky, stars, dawn wave, ripples, emblem halo
// ---------------------------------------------------------------------------

class _BackdropPainter extends CustomPainter {
  _BackdropPainter({required this.t, required this.l});
  final double t;
  final _Layout l;

  static final _stars = _seeded(7, 46);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final fadeIn = _seg(t, 0, .1, Curves.easeOut);
    final maxR = math.sqrt(size.width * size.width + size.height * size.height);

    // Night sky, ramping from the flat native launch colour.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: Alignment(0, (l.arcCenter.dy / size.height) * 2 - 1),
          radius: 1.05,
          colors: [
            Color.lerp(SplashOverlay.nativeColor, _nightCenter, fadeIn)!,
            Color.lerp(SplashOverlay.nativeColor, _nightEdge, fadeIn)!,
          ],
        ).createShader(rect),
    );

    // Twinkling stars.
    for (final s in _stars) {
      final tw = .5 + .5 * math.sin(t * 26 * s.c + s.d * 6.28);
      canvas.drawCircle(
        Offset(s.a * size.width, s.b * size.height * .9),
        .6 + s.c * 1.1,
        Paint()..color = _goldPale.withValues(alpha: fadeIn * (.15 + .55 * tw) * (.4 + .6 * s.d)),
      );
    }

    // Halo behind the emblem as it lights.
    final emIn = _seg(t, _emblemIn.$1, _emblemIn.$2, Curves.easeOut);
    final dawn = _seg(t, _dawn.$1, _dawn.$2, Curves.easeInOutCubic);
    if (emIn > 0) {
      final pulse = .85 + .15 * math.sin(t * 30);
      final r = l.emW * (1.15 + .35 * emIn) * pulse;
      canvas.drawCircle(
        l.emblemCenter,
        r,
        Paint()
          ..shader = RadialGradient(colors: [
            _gold.withValues(alpha: .55 * emIn * (1 - dawn)),
            _goldDeep.withValues(alpha: .18 * emIn * (1 - dawn)),
            Colors.transparent,
          ], stops: const [0, .45, 1]).createShader(Rect.fromCircle(center: l.emblemCenter, radius: r)),
      );
    }

    // Dawn: a cream wave washing out from the emblem, led by a band of light.
    if (dawn > 0) {
      final origin = l.arcCenter;
      final r = dawn * maxR;
      canvas.drawCircle(
        origin,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: const [Colors.white, AppColors.cream, AppColors.creamDark],
            stops: const [0, .55, 1],
          ).createShader(Rect.fromCircle(center: origin, radius: math.max(r, maxR * .6))),
      );
      final edgeA = (1 - dawn) * .9;
      canvas.drawCircle(
        origin,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 26
          ..color = _gold.withValues(alpha: edgeA)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
      );
      canvas.drawCircle(
        origin,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = _goldPale.withValues(alpha: edgeA),
      );

      // Warm glow that stays behind the logo in daylight.
      final g = l.emW * 2.2;
      canvas.drawCircle(
        l.emblemCenter,
        g,
        Paint()
          ..shader = RadialGradient(colors: [
            AppColors.saffronLight.withValues(alpha: .22 * dawn),
            Colors.transparent,
          ]).createShader(Rect.fromCircle(center: l.emblemCenter, radius: g)),
      );
    }

    // Ripples echoing the emblem's concentric rings.
    for (var i = 0; i < 3; i++) {
      final p = _seg(t, _dawn.$1 + .04 + i * .07, _dawn.$1 + .34 + i * .07, Curves.easeOutCubic);
      if (p <= 0 || p >= 1) continue;
      canvas.drawCircle(
        l.emblemCenter,
        l.emW * (.55 + 1.6 * p),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4 * (1 - p) + .6
          ..color = Color.lerp(_flame, AppColors.primary, p)!.withValues(alpha: .55 * (1 - p)),
      );
    }
  }

  @override
  bool shouldRepaint(_BackdropPainter old) => old.t != t;
}

// ---------------------------------------------------------------------------
// Foreground effects: comet arc + sparks, flame flicker, embers, ornament,
// closing twinkle
// ---------------------------------------------------------------------------

class _FxPainter extends CustomPainter {
  _FxPainter({required this.t, required this.l});
  final double t;
  final _Layout l;

  static final _sparks = _seeded(11, 70);
  static final _embers = _seeded(23, 34);
  static const _headCurve = Curves.easeInOutSine;

  /// Comet progress along the arc (0..1) at intro time [time].
  static double _head(double time) => _seg(time, _arcStart, _arcEnd, _headCurve);

  /// Intro time at which the comet reaches arc progress [p].
  static double _timeAt(double p) {
    var lo = _arcStart, hi = _arcEnd;
    for (var i = 0; i < 18; i++) {
      final mid = (lo + hi) / 2;
      if (_head(mid) < p) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final dawn = _seg(t, _dawn.$1, _dawn.$2, Curves.easeInOutCubic);
    _paintEmbers(canvas, size, dawn);
    _paintArc(canvas);
    _paintFlame(canvas, dawn);
    _paintOrnament(canvas);
    _paintTwinkle(canvas);
  }

  void _paintEmbers(Canvas canvas, Size size, double dawn) {
    final fadeIn = _seg(t, .02, .14, Curves.easeOut);
    for (final e in _embers) {
      final travel = (e.d + t * (.55 + e.c * .7)) % 1.0;
      final y = size.height * (1.05 - travel * 1.15);
      final x = size.width * e.a + math.sin(t * 9 * e.c + e.b * 6.28) * 14;
      final life = math.sin(travel * math.pi);
      final a = fadeIn * life * (.35 + .5 * e.b) * (1 - .55 * dawn);
      if (a <= .01) continue;
      final color = Color.lerp(_gold, AppColors.saffron, dawn)!;
      final r = 1.2 + e.c * 2.2;
      canvas.drawCircle(Offset(x, y), r * 2.6,
          Paint()..color = color.withValues(alpha: a * .25)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
      canvas.drawCircle(Offset(x, y), r, Paint()..color = color.withValues(alpha: a));
    }
  }

  void _paintArc(Canvas canvas) {
    final head = _head(t);
    if (head <= 0) return;
    final fade = 1 - _seg(t, _arcEnd - .02, _dawn.$1 + .12, Curves.easeIn);
    if (fade <= 0) return;
    const a0 = _Layout.a0, a1 = _Layout.a1;
    final headA = a0 + (a1 - a0) * head;

    // The lingering arc of light behind the comet.
    final path = Path();
    const steps = 90;
    for (var i = 0; i <= steps; i++) {
      final a = a0 + (headA - a0) * i / steps;
      final p = l.arcPoint(a);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round
        ..color = _goldDeep.withValues(alpha: .28 * fade)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round
        ..color = _goldPale.withValues(alpha: .55 * fade),
    );

    // Tapered bright trail just behind the head.
    const trail = .9;
    const segs = 28;
    for (var i = 0; i < segs; i++) {
      final f0 = i / segs, f1 = (i + 1) / segs;
      final s0 = math.max(a0, headA - trail * (1 - f0));
      final s1 = math.max(a0, headA - trail * (1 - f1));
      if (s1 <= s0) continue;
      canvas.drawLine(
        l.arcPoint(s0),
        l.arcPoint(s1),
        Paint()
          ..strokeWidth = .8 + 3.6 * f1
          ..strokeCap = StrokeCap.round
          ..color = Color.lerp(_goldDeep, _goldPale, f1)!.withValues(alpha: f1 * fade),
      );
    }

    // Shed sparks drifting off the arc.
    for (var i = 0; i < _sparks.length; i++) {
      final s = _sparks[i];
      final p = i / _sparks.length;
      if (p > head) break;
      final age = (t - _timeAt(p)) / .16;
      if (age < 0 || age > 1) continue;
      final a = a0 + (a1 - a0) * p;
      final dir = (s.a - .5) * math.pi * 2;
      final dist = 26 * s.b * age;
      final pos = l.arcPoint(a) + Offset(math.cos(dir) * dist, math.sin(dir) * dist + 18 * age * age);
      final alpha = (1 - age) * fade;
      final r = (.8 + 1.8 * s.c) * (1 - age * .6);
      canvas.drawCircle(pos, r * 3,
          Paint()..color = _gold.withValues(alpha: alpha * .3)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
      canvas.drawCircle(pos, r, Paint()..color = _goldPale.withValues(alpha: alpha));
    }

    // The comet head.
    if (head < 1) {
      final hp = l.arcPoint(headA);
      canvas.drawCircle(hp, 22,
          Paint()..color = _gold.withValues(alpha: .45 * fade)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14));
      _star(canvas, hp, 11, t * 14, _goldPale.withValues(alpha: fade));
      canvas.drawCircle(hp, 3.2, Paint()..color = Colors.white.withValues(alpha: fade));
    }
  }

  void _paintFlame(Canvas canvas, double dawn) {
    final on = _seg(t, _emblemIn.$1 + .08, _emblemIn.$2 + .06, Curves.easeOut);
    if (on <= 0) return;
    final flicker = .78 + .12 * math.sin(t * 61) + .1 * math.sin(t * 97 + 1.3);
    final r = l.emW * .32 * flicker;
    canvas.drawCircle(
      l.flame,
      r,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(colors: [
          _goldPale.withValues(alpha: .55 * on * (1 - .5 * dawn)),
          _flame.withValues(alpha: .18 * on * (1 - .5 * dawn)),
          Colors.transparent,
        ], stops: const [0, .4, 1]).createShader(Rect.fromCircle(center: l.flame, radius: r)),
    );
  }

  void _paintOrnament(Canvas canvas) {
    final p = _seg(t, _ornament.$1, _ornament.$2, Curves.easeOutCubic);
    if (p <= 0) return;
    final c = Offset(l.wordmark.center.dx, l.ornamentY);
    final half = l.wmW * .34 * p;
    final line = Paint()
      ..strokeWidth = 1.2
      ..shader = LinearGradient(colors: [
        AppColors.saffron.withValues(alpha: 0),
        AppColors.saffron.withValues(alpha: .9),
        AppColors.saffron.withValues(alpha: 0),
      ]).createShader(Rect.fromCenter(center: c, width: half * 2 + 1, height: 2));
    canvas.drawLine(c - Offset(half, 0), c + Offset(half, 0), line);
    final d = 4.5 * p;
    final diamond = Path()
      ..moveTo(c.dx, c.dy - d)
      ..lineTo(c.dx + d, c.dy)
      ..lineTo(c.dx, c.dy + d)
      ..lineTo(c.dx - d, c.dy)
      ..close();
    canvas.drawPath(diamond, Paint()..color = AppColors.primary.withValues(alpha: p));
  }

  void _paintTwinkle(Canvas canvas) {
    final p = _seg(t, _twinkle.$1, _twinkle.$2);
    if (p <= 0 || p >= 1) return;
    // Just above the "a" that ends the wordmark.
    final at = Offset(l.wordmark.right - l.wmW * .04, l.wordmark.top + l.wmH * .38);
    final pop = math.sin(p * math.pi);
    canvas.drawCircle(at, 18 * pop,
        Paint()..color = _gold.withValues(alpha: .6 * pop)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
    _star(canvas, at, 14 * pop, p * 3, _goldDeep.withValues(alpha: pop));
    _star(canvas, at, 7 * pop, p * 3, Colors.white.withValues(alpha: pop));
  }

  /// Four-pointed sparkle.
  static void _star(Canvas canvas, Offset c, double r, double rot, Color color) {
    if (r <= 0) return;
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final a = rot + i * math.pi / 4;
      final rr = i.isEven ? r : r * .22;
      final p = c + Offset(math.cos(a) * rr, math.sin(a) * rr);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path..close(), Paint()..color = color);
  }

  @override
  bool shouldRepaint(_FxPainter old) => old.t != t;
}

/// Deterministic random particles (four 0..1 values each).
class _P {
  const _P(this.a, this.b, this.c, this.d);
  final double a, b, c, d;
}

List<_P> _seeded(int seed, int n) {
  final r = math.Random(seed);
  return List.generate(n, (_) => _P(r.nextDouble(), r.nextDouble(), r.nextDouble(), r.nextDouble()));
}
