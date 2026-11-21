import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Shared motion helpers for the pooja pages. Every animation plays once and
/// shows its finished still state when the device has reduced motion on
/// ([MediaQuery.disableAnimationsOf]).

bool reduceMotion(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// Reports how much of [child] is inside the nearest vertical scroll view's
/// viewport (0–1), on first layout and on every scroll.
class InView extends StatefulWidget {
  const InView({super.key, required this.child, required this.onChange});
  final Widget child;
  final ValueChanged<double> onChange;

  @override
  State<InView> createState() => _InViewState();
}

class _InViewState extends State<InView> {
  ScrollPosition? _position;
  double _last = -1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final p = Scrollable.maybeOf(context, axis: Axis.vertical)?.position;
    if (p != _position) {
      _position?.removeListener(_check);
      _position = p?..addListener(_check);
    }
    SchedulerBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    _position?.removeListener(_check);
    super.dispose();
  }

  void _check() {
    if (!mounted) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return;
    final scrollCtx = Scrollable.maybeOf(context, axis: Axis.vertical)?.context;
    final viewport = scrollCtx?.findRenderObject();
    Rect view;
    if (viewport is RenderBox && viewport.hasSize) {
      view = viewport.localToGlobal(Offset.zero) & viewport.size;
    } else {
      view = Offset.zero & MediaQuery.sizeOf(context);
    }
    final rect = box.localToGlobal(Offset.zero) & box.size;
    final overlap = rect.intersect(view);
    final h = rect.height <= 0 ? 1.0 : rect.height;
    final fraction = overlap.isEmpty || overlap.height <= 0 ? 0.0 : (overlap.height / h).clamp(0.0, 1.0);
    if ((fraction - _last).abs() < .01) return;
    _last = fraction;
    widget.onChange(fraction);
  }

  @override
  Widget build(BuildContext context) => NotificationListener<SizeChangedLayoutNotification>(
        onNotification: (_) {
          SchedulerBinding.instance.addPostFrameCallback((_) => _check());
          return false;
        },
        child: SizeChangedLayoutNotifier(child: widget.child),
      );
}

/// Fades and rises [child] in the first time it scrolls into view. Content
/// already on screen when the page lays out is shown as-is (no flicker).
class Reveal extends StatefulWidget {
  const Reveal({super.key, required this.child, this.delay = Duration.zero, this.offset = 24});
  final Widget child;
  final Duration delay;
  final double offset;

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 550));
  bool _decided = false;
  bool _firstCheck = true;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _onChange(double f) {
    if (_decided) return;
    final first = _firstCheck;
    _firstCheck = false;
    if (f <= 0) return;
    _decided = true;
    if (first || reduceMotion(context)) {
      _c.value = 1;
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return InView(
      onChange: _onChange,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, child) {
          // Before the first visibility check, keep it visible so above-the-fold
          // content never flashes.
          final t = _decided ? Curves.easeOutCubic.transform(_c.value) : (_firstCheck ? 1.0 : 0.0);
          return Opacity(
            opacity: t,
            child: Transform.translate(offset: Offset(0, widget.offset * (1 - t)), child: child),
          );
        },
        child: widget.child,
      ),
    );
  }
}

/// Plays a one-off rise-in after [delay] (used for staggered grid entrances).
class RiseIn extends StatefulWidget {
  const RiseIn({super.key, required this.child, this.delay = Duration.zero, this.offset = 16});
  final Widget child;
  final Duration delay;
  final double offset;

  @override
  State<RiseIn> createState() => _RiseInState();
}

class _RiseInState extends State<RiseIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) _c.value = 1;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, child) {
          final t = Curves.easeOutCubic.transform(_c.value);
          return Opacity(opacity: t, child: Transform.translate(offset: Offset(0, widget.offset * (1 - t)), child: child));
        },
        child: widget.child,
      );
}

/// Small press-down (scale 0.98) while [child] is touched; taps pass through.
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child, required this.onTap, this.scale = .98});
  final Widget child;
  final VoidCallback onTap;
  final double scale;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? widget.scale : 1,
          duration: const Duration(milliseconds: 120),
          child: widget.child,
        ),
      );
}

/// Counts from the previous number to [value] when it changes.
class CountUpText extends StatelessWidget {
  const CountUpText({super.key, required this.value, required this.builder, this.style});
  final int value;
  final String Function(int) builder;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return Text(builder(value), style: style);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value.toDouble()),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (_, v, _) => Text(builder(v.round()), style: style),
    );
  }
}
