import 'package:bmp_app/core/api/api_client.dart';
import 'package:bmp_app/core/state/app_state.dart';
import 'package:bmp_app/core/storage/cookies.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The router's sign-in gate across the sign-in / sign-out transitions.
void main() {
  var userType = 1;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (_) async => null,
    );
    await Cookies.init();
    ApiClient.instance.dio.interceptors.insert(
      0,
      InterceptorsWrapper(
        onRequest: (o, h) => h.resolve(Response(
          requestOptions: o,
          statusCode: 200,
          data: {
            'statusCode': 200,
            'body': {'userType': userType, 'userName': 'Test'},
          },
        )),
      ),
    );
  });

  test('signing in lets the user through while the profile reloads', () async {
    Cookies.remove('accessToken');
    final c = ProviderContainer();
    addTearDown(c.dispose);

    expect(await c.read(authProvider.future), isNull);
    expect(isSignedIn(c.read(authProvider)), isFalse);

    // What the login page does after a successful OTP verify.
    Cookies.set('accessToken', 'token');
    c.invalidate(authProvider);
    final reloading = c.read(authProvider);
    expect(reloading.isLoading, isTrue);
    expect(isSignedIn(reloading), isTrue, reason: 'the stale signed-out value must not bounce back to /auth');

    await c.read(authProvider.future);
    expect(isSignedIn(c.read(authProvider)), isTrue);

    c.read(authProvider.notifier).logout();
    expect(isSignedIn(c.read(authProvider)), isFalse);
  });

  test('a guest-only session is sent to sign in', () async {
    userType = 3;
    addTearDown(() => userType = 1);
    Cookies.set('accessToken', 'guest-token');
    final c = ProviderContainer();
    addTearDown(c.dispose);

    await c.read(authProvider.future);
    expect(isSignedIn(c.read(authProvider)), isFalse);
  });
}
