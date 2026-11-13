import 'package:flutter/material.dart';

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
      overlay = _UpdateCard(
        status: s,
        onUpdate: _openStore,
        onLater: () => setState(() => _softDismissed = true),
      );
    }
    if (overlay == null) return widget.child;
    return Stack(fit: StackFit.expand, children: [widget.child, overlay]);
  }
}

class _BlockingScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cream,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: const BoxDecoration(color: AppColors.creamDark, shape: BoxShape.circle),
                child: Icon(icon, size: 44, color: AppColors.primary),
              ),
              const SizedBox(height: 24),
              Text(title, textAlign: TextAlign.center, style: AppText.heading(size: 26)),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppText.body(size: 15, color: AppColors.mutedForeground, height: 1.5),
              ),
              const SizedBox(height: 32),
              AppButton(
                onPressed: onPressed,
                label: buttonLabel,
                loading: loading,
                size: BtnSize.lg,
                expand: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
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
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
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
                ]),
                const SizedBox(height: 10),
                Text(
                  status.updateMessage,
                  style: AppText.body(size: 14, color: AppColors.mutedForeground, height: 1.5),
                ),
                const SizedBox(height: 18),
                Row(children: [
                  Expanded(
                    child: AppButton(onPressed: onLater, label: 'Later', variant: BtnVariant.outline, expand: true),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: AppButton(onPressed: onUpdate, label: 'Update', expand: true)),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
