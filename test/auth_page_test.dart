import 'package:bmp_app/core/api/api_client.dart';
import 'package:bmp_app/core/storage/cookies.dart';
import 'package:bmp_app/features/auth/auth_page.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Walks the login screen through phone → OTP → profile with the API faked,
/// so each step's layout is exercised without sending a real SMS.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (_) async => null,
    );
    await Cookies.init();

    // Answer every request before the session interceptor runs.
    ApiClient.instance.dio.interceptors.insert(
      0,
      InterceptorsWrapper(onRequest: (o, h) {
        final path = o.uri.path;
        final Object body = switch (path) {
          _ when path.endsWith('/send-otp') => {'statusCode': 200, 'message': 'OTP sent'},
          _ when path.endsWith('/verify-otp') => {
              'statusCode': 200,
              'body': {'accessToken': 'test-token'},
            },
          _ => {'statusCode': 200, 'body': {'userType': 1, 'userName': '', 'isEmailVerified': false}},
        };
        h.resolve(Response(requestOptions: o, statusCode: path.endsWith('/auth') ? 200 : 201, data: body));
      }),
    );
  });

  testWidgets('login screen renders all three steps', (tester) async {
    // Fonts can't load offline in tests; that is not what this test checks.
    final onError = FlutterError.onError;
    FlutterError.onError = (d) {
      if (d.exception.toString().contains('GoogleFonts')) return;
      onError?.call(d);
    };
    addTearDown(() => FlutterError.onError = onError);

    await tester.binding.setSurfaceSize(const Size(412, 915));
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: AuthPage())));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to BookMyPooja'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '9876543210');
    await tester.pump();
    await tester.tap(find.text('Send OTP'));
    await tester.pumpAndSettle();
    expect(find.text('Verify your number'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.enterText(find.byType(EditableText).first, '123456');
    await tester.pumpAndSettle();
    expect(find.text('Complete your profile'), findsOneWidget);
    expect(find.text('Finish'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Let the resend countdown's periodic timer settle.
    await tester.pump(const Duration(seconds: 61));
  });
}
