import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// FestivalOrnaments.jsx + the motif registry in FestivalHeroDecor.jsx,
/// drawn from the same SVG source.

class DiyaIcon extends StatefulWidget {
  const DiyaIcon({super.key, this.size = 20, this.glow = false});
  final double size;
  final bool glow;

  @override
  State<DiyaIcon> createState() => _DiyaIconState();
}

class _DiyaIconState extends State<DiyaIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat();
  }

  static const _base = '<svg viewBox="0 0 32 32" xmlns="http://www.w3.org/2000/svg">'
      '<path d="M3 17h26c-1.2 6.2-6.4 10-13 10S4.2 23.2 3 17z" fill="#C2410C"/>'
      '<path d="M3 17h26c-.3 1.4-.8 2.6-1.5 3.7H4.5C3.8 19.6 3.3 18.4 3 17z" fill="#EA7A2B"/></svg>';
  static const _flame = '<svg viewBox="0 0 32 32" xmlns="http://www.w3.org/2000/svg">'
      '<path d="M16 3c2.6 3.4 3.6 6 3.6 8a3.6 3.6 0 0 1-7.2 0c0-2 1-4.6 3.6-8z" fill="#FFB020"/>'
      '<path d="M16 7.5c1.2 1.8 1.6 3.1 1.6 4a1.6 1.6 0 0 1-3.2 0c0-.9.4-2.2 1.6-4z" fill="#FFF1C1"/></svg>';

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final reduce = MediaQuery.of(context).disableAnimations;
    Widget icon = SizedBox(
      width: s,
      height: s,
      child: Stack(
        children: [
          SvgPicture.string(_base, width: s, height: s),
          AnimatedBuilder(
            animation: _c,
            builder: (_, child) {
              if (reduce) return child!;
              // fx-flicker: scaleY 1 → 1.08 → .95, rotate 0 → -2° → 2°
              final t = _c.value;
              double sy, rot;
              if (t < .3) {
                sy = 1 + .08 * (t / .3);
                rot = -2 * (t / .3);
              } else if (t < .6) {
                final k = (t - .3) / .3;
                sy = 1.08 - .13 * k;
                rot = -2 + 4 * k;
              } else {
                final k = (t - .6) / .4;
                sy = .95 + .05 * k;
                rot = 2 - 2 * k;
              }
              return Transform(
                alignment: Alignment.bottomCenter,
                transform: Matrix4.identity()
                  ..rotateZ(rot * math.pi / 180)
                  ..scaleByDouble(1, sy, 1, 1),
                child: child,
              );
            },
            child: SvgPicture.string(_flame, width: s, height: s),
          ),
        ],
      ),
    );
    if (widget.glow) {
      icon = DecoratedBox(
        decoration: BoxDecoration(
          boxShadow: [BoxShadow(color: const Color(0xA6FFB020), blurRadius: 10, spreadRadius: -s / 4)],
        ),
        child: icon,
      );
    }
    // The flame flickers every frame; keep it from repainting its parent.
    return RepaintBoundary(child: icon);
  }
}

/// Marigold toran: the 44×18 pattern tile repeated across the width.
class ToranGarland extends StatelessWidget {
  const ToranGarland({super.key, this.height = 16});
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        width: double.infinity,
        child: ClipRect(child: CustomPaint(painter: _ToranPainter())),
      );
}

class _ToranPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // The SVG uses preserveAspectRatio="none" on a userSpaceOnUse pattern, so
    // tiles keep their 44×18 size and simply repeat.
    for (double x = 0; x < size.width; x += 44) {
      for (double y = 0; y < size.height; y += 18) {
        canvas.save();
        canvas.translate(x, y);
        final rope = Path()
          ..moveTo(0, 3)
          ..quadraticBezierTo(11, 9, 22, 3)
          ..quadraticBezierTo(33, -3, 44, 3);
        canvas.drawPath(
          rope,
          Paint()
            ..color = const Color(0xFF7A4A12)
            ..style = PaintingStyle.stroke
            ..strokeWidth = .8,
        );
        canvas.drawCircle(const Offset(11, 6.2), 3.6, Paint()..color = const Color(0xFFF59E0B));
        canvas.drawCircle(const Offset(11, 6.2), 1.7, Paint()..color = const Color(0xFFFCD34D));
        canvas.drawCircle(const Offset(33, 6.2), 3.6, Paint()..color = const Color(0xFFEA580C));
        canvas.drawCircle(const Offset(33, 6.2), 1.7, Paint()..color = const Color(0xFFFDBA74));
        final leaf = Path()
          ..moveTo(22, 3)
          ..relativeQuadraticBezierTo(-2.4, 6, 0, 12)
          ..relativeQuadraticBezierTo(2.4, -6, 0, -12)
          ..close();
        canvas.drawPath(leaf, Paint()..color = const Color(0xFF3F7D32));
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

String rangoliSvg() {
  final b = StringBuffer('<svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">');
  const colors = ['#C62828', '#F59E0B', '#7C3AED'];
  for (var ring = 0; ring < 3; ring++) {
    for (var i = 0; i < 12; i++) {
      b.write('<ellipse cx="100" cy="${100 - 30 - ring * 22}" rx="${9 - ring * 1.5}" ry="${18 - ring * 3}" '
          'fill="${colors[ring]}" opacity="0.9" transform="rotate(${i * 30 + ring * 15} 100 100)"/>');
    }
  }
  b.write('<circle cx="100" cy="100" r="22" fill="#EA580C"/><circle cx="100" cy="100" r="11" fill="#FCD34D"/></svg>');
  return b.toString();
}

/// MandalaWatermark.jsx.
class MandalaWatermark extends StatelessWidget {
  const MandalaWatermark({super.key, required this.size, required this.color, this.opacity = 1});
  final double size;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Opacity(
          opacity: opacity,
          child: CustomPaint(size: Size.square(size), painter: _MandalaPainter(color)),
        ),
      );
}

class _MandalaPainter extends CustomPainter {
  _MandalaPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 800;
    canvas.scale(s);
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = .8;
    const c = Offset(400, 400);
    for (final r in [380.0, 320, 260, 200, 140, 80]) {
      canvas.drawCircle(c, r.toDouble(), p);
    }
    Offset at(double r, double rad) => Offset(400 + r * math.cos(rad), 400 + r * math.sin(rad));
    for (var i = 0; i < 16; i++) {
      final rad = (i * 360 / 16) * math.pi / 180;
      canvas.drawLine(at(260, rad), at(380, rad), p);
    }
    for (var i = 0; i < 12; i++) {
      final rad = (i * 360 / 12) * math.pi / 180;
      canvas.drawCircle(at(230, rad), 18, p);
    }
    for (var i = 0; i < 8; i++) {
      final angle = i * 360 / 8;
      final rad = angle * math.pi / 180;
      final next = (angle + 45) * math.pi / 180;
      final a = at(80, rad);
      final cp = at(160, (rad + next) / 2);
      final b = at(80, next);
      canvas.drawPath(Path()..moveTo(a.dx, a.dy)..quadraticBezierTo(cp.dx, cp.dy, b.dx, b.dy), p);
    }
    for (var i = 0; i < 16; i++) {
      final rad = ((i * 360 / 16) + 11.25) * math.pi / 180;
      canvas.drawLine(at(140, rad), at(200, rad), p);
    }
    canvas.drawCircle(c, 6, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _MandalaPainter old) => old.color != color;
}

/// OrnamentalDivider.jsx — line, dots and an 8-petal lotus.
class OrnamentalDivider extends StatelessWidget {
  const OrnamentalDivider({super.key, this.color});
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 448),
            child: AspectRatio(
              aspectRatio: 600 / 40,
              child: SizedBox(
                height: 32,
                child: CustomPaint(painter: _DividerPainter(color ?? const Color(0x4091121D))),
              ),
            ),
          ),
        ),
      );
}

class _DividerPainter extends CustomPainter {
  _DividerPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 600, size.height / 40);
    final fill = Paint()..color = color;
    final line = Paint()
      ..color = color
      ..strokeWidth = 1;
    canvas.drawLine(const Offset(0, 20), const Offset(240, 20), line);
    canvas.drawCircle(const Offset(245, 20), 2, fill);
    canvas.drawCircle(const Offset(255, 20), 2, fill);
    canvas.save();
    canvas.translate(300, 20);
    final petal = Paint()..color = color.withValues(alpha: color.a * .6);
    for (var i = 0; i < 8; i++) {
      canvas.save();
      canvas.rotate(i * 45 * math.pi / 180);
      canvas.drawOval(Rect.fromCenter(center: const Offset(0, -8), width: 8, height: 16), petal);
      canvas.restore();
    }
    canvas.drawCircle(Offset.zero, 3, fill);
    canvas.restore();
    canvas.drawCircle(const Offset(345, 20), 2, fill);
    canvas.drawCircle(const Offset(355, 20), 2, fill);
    canvas.drawLine(const Offset(360, 20), const Offset(600, 20), line);
  }

  @override
  bool shouldRepaint(covariant _DividerPainter old) => old.color != color;
}
