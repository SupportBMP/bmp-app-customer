import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/state/app_state.dart';
import 'core/storage/cookies.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/splash_screen.dart';
import 'core/widgets/toast.dart';
import 'router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Cookies.init();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const ProviderScope(child: BmpApp()));
}

class BmpApp extends ConsumerStatefulWidget {
  const BmpApp({super.key});

  @override
  ConsumerState<BmpApp> createState() => _BmpAppState();
}

class _BmpAppState extends ConsumerState<BmpApp> {
  /// Pings the router whenever sign-in state changes so its redirect re-runs
  /// (sign-in completes, logout, or an expired token).
  final _authChanges = ValueNotifier(0);
  late final GoRouter _router = buildRouter(ref, _authChanges);

  @override
  void initState() {
    super.initState();
    ref.listenManual(authProvider, (_, _) => _authChanges.value++);
  }

  @override
  void dispose() {
    _router.dispose();
    _authChanges.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'BookMyPooja',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      scaffoldMessengerKey: Toast.messengerKey,
      routerConfig: _router,
      builder: (context, child) => SplashOverlay(child: child ?? const SizedBox.shrink()),
    );
  }
}
