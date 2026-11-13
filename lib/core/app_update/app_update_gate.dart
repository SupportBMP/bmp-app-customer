import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../utils/launch.dart';
import '../widgets/ui.dart';
import 'app_update_status.dart';

/// Wraps the app and, based on `GET /pooja-global/app-config`:
///  * maintenance  → full-screen block with a Retry button
///  * forceUpdate  → full-screen block with an Update button (no way past it)
///  * updateAvailable → dismissible "Update available" card
///
/// It sits *under* [SplashOverlay], so the check runs while the splash
/// animates and whatever it shows appears once the splash fades out.
/// Blocking states are re-checked when the app returns to the foreground
/// (e.g. after the user comes back from the Play Store).
class AppUpdateGate extends StatefulWidget {
  const AppUpdateGate({super.key, required this.child});
  final Widget child;

  @override
  State<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends State<AppUpdateGate> with WidgetsBindingObserver {
  AppUpdateStatus? _status;
  bool _softDismissed = false;
  bool _checking = false;

  bool get _blocked => _status != null && (_status!.maintenance || _status!.forceUpdate);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _blocked) _check();
  }

  Future<void> _check() async {
    if (_checking) return;
    setState(() => _checking = true);
    final status = await AppUpdateStatus.fetch();
    if (!mounted) return;
    setState(() {
      _checking = false;
      // A failed re-check keeps the current state rather than unblocking.
      if (status != null || _status == null) _status = status;
    });
  }

  void _openStore() {
    final url = _status?.storeUrl ?? '';
    if (url.isNotEmpty) openExternal(url);
  }

  @override
  Widget build(BuildContext context) {
    final s = _status;
    Widget? overlay;
    if (s != null && s.maintenance) {
      overlay = _BlockingScreen(
        icon: Icons.construction_rounded,
        title: 'Under Maintenance',
        message: s.maintenanceMessage,
        buttonLabel: 'Retry',
        loading: _checking,
        onPressed: _check,
      );
    } else if (s != null && s.forceUpdate) {
      overlay = _BlockingScreen(
        icon: Icons.system_update_rounded,
        title: 'Update Required',
        message: s.updateMessage,
        buttonLabel: 'Update Now',
        onPressed: _openStore,
      );
    } else if (s != null && s.updateAvailable && !_softDismissed) {
      overlay = _UpdateCard(status: s, onUpdate: _openStore, onLater: () => setState(() => _softDismissed = true));
    }
    if (overlay == null) return widget.child;
    return Stack(fit: StackFit.expand, children: [widget.child, overlay]);
  }
}

// Splash night-sky palette (see core/widgets/splash_screen.dart).
const _gold = Color(0xFFFFD27A);
const _goldDeep = Color(0xFFF2A93B);
const _goldPale = Color(0xFFFFF1CF);
const _nightCenter = Color(0xFF7A1622);
const _nightEdge = Color(0xFF220307);

/// Full-screen block (maintenance / force update) styled like the splash's
/// night scene: maroon sky with twinkling stars, the diya emblem with a
/// breathing gold halo, and the wordmark in gold.
class _BlockingScreen extends StatefulWidget {
  const _BlockingScreen({
    required this.icon,
    required this.title,
    required this.message,
    required this.buttonLabel,
    required this.onPressed,
    this.loading = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final String buttonLabel;
  final VoidCallback onPressed;
  final bool loading;

  @override
  State<_BlockingScreen> createState() => _BlockingScreenState();
}

class _BlockingScreenState extends State<_BlockingScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(vsync: this, duration: const Duration(seconds: 6))
    ..repeat();

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: _nightEdge,
      ),
      child: Material(
        color: _nightEdge,
        child: Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(
              child: AnimatedBuilder(
                animation: _loop,
                builder: (_, _) => CustomPaint(painter: _NightSkyPainter(reduceMotion ? 0 : _loop.value)),
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, c) {
                  final emW = math.min(112.0, c.maxWidth * .3);
                  final wmW = math.min(190.0, c.maxWidth * .5);
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: c.maxHeight),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _GlowingEmblem(width: emW, loop: reduceMotion ? null : _loop),
                            const SizedBox(height: 28),
                            SizedBox(
                              width: wmW,
                              child: SvgPicture.asset(
                                'assets/images/splash/wordmark.svg',
                                colorFilter: const ColorFilter.mode(_gold, BlendMode.srcIn),
                              ),
                            ),
                            const SizedBox(height: 14),
                            const _Ornament(),
                            const SizedBox(height: 28),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(widget.icon, size: 22, color: _gold),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    widget.title,
                                    textAlign: TextAlign.center,
                                    style: AppText.heading(size: 26, color: _goldPale),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              widget.message,
                              textAlign: TextAlign.center,
                              style: AppText.body(size: 15, color: _goldPale.withValues(alpha: .75), height: 1.55),
                            ),
                            const SizedBox(height: 32),
                            _GoldButton(
                              label: widget.buttonLabel,
                              loading: widget.loading,
                              onPressed: widget.onPressed,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Diya emblem with the splash's pulsing gold halo behind it.
class _GlowingEmblem extends StatelessWidget {
  const _GlowingEmblem({required this.width, this.loop});
  final double width;
  final Animation<double>? loop;

  @override
  Widget build(BuildContext context) {
    final h = width * 242 / 204;
    final halo = width * 2.1;
    // Sized to the emblem; the halo spills past it without taking layout space.
    return SizedBox(
      width: width,
      height: h,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          OverflowBox(
            maxWidth: halo * 1.2,
            maxHeight: halo * 1.2,
            child: AnimatedBuilder(
              animation: loop ?? const AlwaysStoppedAnimation(0),
              builder: (_, _) {
                final pulse = .88 + .12 * math.sin((loop?.value ?? 0) * math.pi * 6);
                return Container(
                  width: halo * pulse,
                  height: halo * pulse,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [_gold.withValues(alpha: .5), _goldDeep.withValues(alpha: .16), Colors.transparent],
                      stops: const [0, .45, 1],
                    ),
                  ),
                );
              },
            ),
          ),
          SvgPicture.asset('assets/images/splash/emblem.svg', width: width, height: h),
        ],
      ),
    );
  }
}

/// Small gold divider: line · diamond · line.
class _Ornament extends StatelessWidget {
  const _Ornament();

  @override
  Widget build(BuildContext context) {
    Widget line(bool leftFade) => Container(
      width: 46,
      height: 1.2,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: leftFade ? [Colors.transparent, _gold] : [_gold, Colors.transparent]),
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        line(true),
        const SizedBox(width: 8),
        Transform.rotate(
          angle: math.pi / 4,
          child: Container(width: 6, height: 6, color: _gold),
        ),
        const SizedBox(width: 8),
        line(false),
      ],
    );
  }
}

class _GoldButton extends StatelessWidget {
  const _GoldButton({required this.label, required this.onPressed, this.loading = false});
  final String label;
  final VoidCallback onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: const LinearGradient(colors: [_gold, _goldDeep]),
        boxShadow: [BoxShadow(color: _goldDeep.withValues(alpha: .35), blurRadius: 18, offset: const Offset(0, 6))],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: loading ? null : onPressed,
          child: SizedBox(
            height: 50,
            width: double.infinity,
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.maroonDark),
                    )
                  : Text(
                      label,
                      style: AppText.body(size: 16, weight: FontWeight.w700, color: AppColors.maroonDark),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Maroon radial sky with slowly twinkling stars, as in the splash.
class _NightSkyPainter extends CustomPainter {
  _NightSkyPainter(this.t);
  final double t;

  static final _stars = () {
    final r = math.Random(7);
    return List.generate(46, (_) => (r.nextDouble(), r.nextDouble(), r.nextDouble(), r.nextDouble()));
  }();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -.35),
          radius: 1.05,
          colors: [_nightCenter, _nightEdge],
        ).createShader(rect),
    );
    for (final (a, b, c, d) in _stars) {
      final tw = .5 + .5 * math.sin(t * math.pi * 2 * (1 + 2 * c) + d * 6.28);
      canvas.drawCircle(
        Offset(a * size.width, b * size.height * .9),
        .6 + c * 1.1,
        Paint()..color = _goldPale.withValues(alpha: (.15 + .55 * tw) * (.4 + .6 * d)),
      );
    }
  }

  @override
  bool shouldRepaint(_NightSkyPainter old) => old.t != t;
}

class _UpdateCard extends StatelessWidget {
  const _UpdateCard({required this.status, required this.onUpdate, required this.onLater});

  final AppUpdateStatus status;
  final VoidCallback onUpdate;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      child: SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.system_update_rounded, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        status.latestVersion.isEmpty
                            ? 'Update Available'
                            : 'Update Available (v${status.latestVersion})',
                        style: AppText.body(size: 17, weight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  status.updateMessage,
                  style: AppText.body(size: 14, color: AppColors.mutedForeground, height: 1.5),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(onPressed: onLater, label: 'Later', variant: BtnVariant.outline, expand: true),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppButton(onPressed: onUpdate, label: 'Update', expand: true),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
