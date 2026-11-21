import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/json.dart';
import '../../core/utils/launch.dart';
import '../../core/widgets/brand_icons.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/site_image.dart';

/// Port of bmp_fe components/PoojaComponent/ListingDecor.jsx and the
/// swastik from TempleMotifs.jsx.

// ---------------------------------------------------------------------------
// Header band: cream gradient, faint dot grid, scalloped temple-arch edge,
// animated swastik on tablet and up.
// ---------------------------------------------------------------------------

class ListingHeaderBand extends StatelessWidget {
  const ListingHeaderBand({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 600;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFFF4E2), Color(0xFFFFFBF5)]),
      ),
      child: Stack(children: [
        const Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _DotGridPainter()))),
        if (wide) const Positioned(right: 16, top: 12, child: AnimatedSwastik(size: 104)),
        Padding(
          padding: EdgeInsets.only(bottom: 20, right: wide ? 120 : 0),
          child: child,
        ),
        const Positioned(left: 0, right: 0, bottom: 0, height: 12, child: IgnorePointer(child: CustomPaint(painter: _ArchEdgePainter()))),
      ]),
    );
  }
}

/// Dots fading out towards the left (`mask-image: linear-gradient(to left…)`).
class _DotGridPainter extends CustomPainter {
  const _DotGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const step = 20.0;
    final p = Paint();
    for (var x = step / 2; x < size.width; x += step) {
      final fade = (1 - (size.width - x) / (size.width * .7)).clamp(0.0, 1.0);
      if (fade <= 0) continue;
      p.color = const Color(0xFFB4541A).withValues(alpha: .14 * fade);
      for (var y = step / 2; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 1.2, p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ArchEdgePainter extends CustomPainter {
  const _ArchEdgePainter();

  @override
  void paint(Canvas canvas, Size size) {
    const w = 28.0;
    final fill = Paint()..color = Colors.white;
    final stroke = Paint()
      ..color = const Color(0xFFE8C48A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final h = size.height;
    for (var x = 0.0; x < size.width; x += w) {
      final arch = Path()
        ..moveTo(x, h)
        ..quadraticBezierTo(x + w / 2, -h / 3, x + w, h);
      canvas.drawPath(Path.from(arch)..close(), fill);
      canvas.drawPath(arch, stroke);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Upright, clockwise Hindu swastik (卐) in kumkum red with four bindus.
/// Lines trace in, bindus pop in one by one, then a golden light runs along
/// the lines, bindus twinkle in turn, a ray halo turns slowly behind it and
/// the symbol breathes gently. Never tilted or spun. Tap redraws it.
class AnimatedSwastik extends StatefulWidget {
  const AnimatedSwastik({super.key, this.size = 104});
  final double size;

  @override
  State<AnimatedSwastik> createState() => _AnimatedSwastikState();
}

class _AnimatedSwastikState extends State<AnimatedSwastik> with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));
  late final AnimationController _ambient = AnimationController(vsync: this, duration: const Duration(seconds: 6));

  @override
  void initState() {
    super.initState();
    _intro.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted && !reduceMotion(context)) _ambient.repeat();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _intro.value = 1;
      _ambient.stop();
    } else if (_intro.value == 0 && !_intro.isAnimating) {
      _intro.forward();
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _ambient.dispose();
    super.dispose();
  }

  void _redraw() {
    if (reduceMotion(context)) return;
    _ambient.stop();
    _intro.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: GestureDetector(
          onTap: _redraw,
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: Listenable.merge([_intro, _ambient]),
              builder: (_, _) => CustomPaint(
                size: Size.square(widget.size),
                painter: _SwastikPainter(intro: _intro.value, ambient: _ambient.isAnimating ? _ambient.value : -1),
              ),
            ),
          ),
        ),
      );
}

class _SwastikPainter extends CustomPainter {
  _SwastikPainter({required this.intro, required this.ambient});
  final double intro;

  /// 0–1 loop position after the intro, or -1 when idle.
  final double ambient;

  static const _kumkum = Color(0xFFC81E1E);
  static const _gold = Color(0xFFFBBF24);

  // 100×100 design space.
  static final _strokes = <List<Offset>>[
    [const Offset(50, 22), const Offset(50, 78)],
    [const Offset(22, 50), const Offset(78, 50)],
    [const Offset(50, 22), const Offset(78, 22)], // top arm bends right
    [const Offset(78, 50), const Offset(78, 78)], // right arm bends down
    [const Offset(50, 78), const Offset(22, 78)], // bottom arm bends left
    [const Offset(22, 50), const Offset(22, 22)], // left arm bends up
  ];
  static const _bindus = [Offset(64, 36), Offset(64, 64), Offset(36, 64), Offset(36, 36)];

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;
    canvas.save();
    canvas.scale(s);
    final c = const Offset(50, 50);

    final idle = ambient >= 0;
    final breathe = idle ? 1 + .025 * math.sin(ambient * 2 * math.pi) : 1.0;
    canvas.translate(c.dx, c.dy);
    canvas.scale(breathe);
    canvas.translate(-c.dx, -c.dy);

    // Ray halo, turning slowly (the rays turn, the symbol never does).
    final haloT = (intro - .6).clamp(0.0, .4) / .4;
    if (haloT > 0) {
      final rays = Paint()
        ..color = _gold.withValues(alpha: .22 * haloT)
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round;
      final turn = idle ? ambient * 2 * math.pi / 6 : 0.0;
      for (var i = 0; i < 24; i++) {
        final a = turn + i * math.pi / 12;
        final r1 = i.isEven ? 40.0 : 43.0;
        canvas.drawLine(c + Offset(math.cos(a), math.sin(a)) * r1, c + Offset(math.cos(a), math.sin(a)) * 48, rays);
      }
      canvas.drawCircle(
        c,
        38,
        Paint()
          ..shader = ui.Gradient.radial(c, 38, [_gold.withValues(alpha: .18 * haloT), _gold.withValues(alpha: 0)]),
      );
    }

    // Lines trace in over the first 55% of the intro.
    final line = Paint()
      ..color = _kumkum
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final traceT = (intro / .55).clamp(0.0, 1.0);
    for (var i = 0; i < _strokes.length; i++) {
      final local = ((traceT * _strokes.length) - i).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final a = _strokes[i][0], b = _strokes[i][1];
      canvas.drawLine(a, Offset.lerp(a, b, local)!, line);
    }

    // A golden light runs along the lines.
    if (idle) {
      final runT = (ambient * 1.5).clamp(0.0, 1.0);
      if (runT < 1) {
        final idx = (runT * _strokes.length).floor().clamp(0, _strokes.length - 1);
        final local = runT * _strokes.length - idx;
        final a = _strokes[idx][0], b = _strokes[idx][1];
        final pos = Offset.lerp(a, b, local)!;
        canvas.drawCircle(pos, 5, Paint()..shader = ui.Gradient.radial(pos, 5, [_gold, _gold.withValues(alpha: 0)]));
      }
    }

    // Bindus pop in one by one, then twinkle in turn.
    for (var i = 0; i < _bindus.length; i++) {
      final popStart = .55 + i * .1;
      final pop = ((intro - popStart) / .1).clamp(0.0, 1.0);
      if (pop <= 0) continue;
      final overshoot = pop < 1 ? Curves.easeOutBack.transform(pop) : 1.0;
      var r = 4.2 * overshoot;
      var glow = 0.0;
      if (idle) {
        final phase = ((ambient * 4) - i) % 4;
        if (phase >= 0 && phase < 1) {
          glow = math.sin(phase * math.pi);
          r += .8 * glow;
        }
      }
      if (glow > 0) {
        canvas.drawCircle(_bindus[i], r + 4, Paint()..color = _gold.withValues(alpha: .35 * glow));
      }
      canvas.drawCircle(_bindus[i], r, Paint()..color = _kumkum);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SwastikPainter old) => old.intro != intro || old.ambient != ambient;
}

// ---------------------------------------------------------------------------
// Category quick-chips
// ---------------------------------------------------------------------------

class CategoryChips extends StatelessWidget {
  const CategoryChips({super.key, required this.categories, required this.selected, required this.onToggle});
  final List<Json> categories;
  final List<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 50,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 4),
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final cat = categories[i];
          final slug = str(cat['slug']);
          final on = selected.contains(slug);
          final image = strOrNull(cat['imageLink']);
          return RiseIn(
            delay: Duration(milliseconds: i * 35),
            offset: 10,
            child: Semantics(
              button: true,
              selected: on,
              child: PressScale(
                scale: .95,
                onTap: () => onToggle(slug),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.fromLTRB(4, 4, 14, 4),
                  decoration: BoxDecoration(
                    color: on ? AppColors.bluntRed : Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: on ? AppColors.bluntRed : const Color(0xFFFDE68A)),
                    boxShadow: on
                        ? const [BoxShadow(color: Color(0xE68A1C23), blurRadius: 18, offset: Offset(0, 8), spreadRadius: -10)]
                        : null,
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 32,
                      height: 32,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFFEF3C7),
                        border: Border.all(color: on ? Colors.white.withValues(alpha: .6) : const Color(0xFFFEF3C7), width: 2),
                      ),
                      child: image == null ? null : SiteImage(image, fit: BoxFit.cover),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      strOrNull(cat['subCategoryName']) ?? slug,
                      style: AppText.body(size: 12, weight: FontWeight.w600, color: on ? Colors.white : const Color(0xFF5A3A2C)),
                    ),
                  ]),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Trust band (dropped into the grid after the first 8 cards)
// ---------------------------------------------------------------------------

class TrustBand extends StatelessWidget {
  const TrustBand({super.key, required this.language, required this.location, required this.pageReference});
  final String language;
  final String location;
  final String pageReference;

  static const _promises = [
    ('/icons/Group7570.svg', 'Experienced Pandits'),
    ('/icons/paper.svg', 'Vedic Standards & Procedures'),
    ('/icons/Group7565.svg', 'High Quality Samagri'),
    ('/icons/star.svg', 'Guaranteed Punctuality'),
  ];

  String _t(String s) => s.replaceAll('-', ' ').replaceAllMapped(RegExp(r'\b\w'), (m) => m.group(0)!.toUpperCase());

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8A1C23), Color(0xFF9E2A1F), Color(0xFFC2410C)],
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        LayoutBuilder(builder: (ctx, c) {
          final cols = c.maxWidth >= 560 ? 4 : 2;
          final w = (c.maxWidth - 12 * (cols - 1)) / cols;
          return Wrap(spacing: 12, runSpacing: 12, children: [
            for (final p in _promises)
              SizedBox(
                width: w,
                child: Row(children: [
                  Container(
                    width: 40,
                    height: 40,
                    padding: const EdgeInsets.all(9),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: SiteImage(p.$1, fit: BoxFit.contain, placeholderColor: Colors.transparent),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(p.$2, style: AppText.body(size: 12, weight: FontWeight.w600, color: Colors.white, height: 1.3))),
                ]),
              ),
          ]);
        }),
        const SizedBox(height: 20),
        Text('Not sure which puja?', style: AppText.heading(size: 18, weight: FontWeight.w700, color: Colors.white)),
        const SizedBox(height: 8),
        Row(children: [
          _pill(
            color: Colors.white,
            onTap: () => callPhone(),
            icon: const Icon(LucideIcons.phone, size: 16, color: AppColors.bluntRed),
            label: 'Call',
            fg: AppColors.bluntRed,
          ),
          const SizedBox(width: 8),
          _pill(
            color: AppColors.whatsappBrand,
            onTap: () => openWhatsApp(
              'Namaste BookMyPooja 🙏 I need help choosing a puja'
              '${location.isNotEmpty ? ' in ${_t(location)}' : ''}${language.isNotEmpty ? ' (${_t(language)} pandit)' : ''}.\n\n$pageReference',
            ),
            icon: const WhatsAppIcon(size: 16),
            label: 'WhatsApp',
            fg: Colors.white,
          ),
        ]),
      ]),
    );
  }

  Widget _pill({required Color color, required VoidCallback onTap, required Widget icon, required String label, required Color fg}) =>
      PressScale(
        scale: .95,
        onTap: onTap,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            icon,
            const SizedBox(width: 6),
            Text(label, style: AppText.body(size: 14, weight: FontWeight.w700, color: fg)),
          ]),
        ),
      );
}
