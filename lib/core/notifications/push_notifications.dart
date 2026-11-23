import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';

import '../api/bmp_api.dart';
import '../storage/cookies.dart';
import '../utils/json.dart';

/// Runs in its own isolate when a message arrives while the app is in the
/// background or terminated. Messages with a `notification` block are shown
/// by the OS itself, so there is nothing to draw here; the handler only has to
/// exist (and be a top-level entry point) for FCM to deliver data messages.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

/// FCM device token lifecycle for Android and iOS (BMP-16).
///
/// * [init] once at startup: Firebase + refresh listener. If the Firebase
///   config files are missing it logs and stays off instead of crashing.
/// * [syncWithUser] whenever the signed-in user changes: asks for permission
///   and registers the token with BMP_BE (`POST /device-tokens`) for real,
///   signed-in users (not guests).
/// * [unregister] on logout, *before* the access token is dropped:
///   `DELETE /device-tokens`, then the token is deleted on the device so the
///   next account to sign in gets a fresh one.
///
/// The backend upserts by token, so registering twice never duplicates.
class PushNotifications {
  PushNotifications._();

  static final PushNotifications instance = PushNotifications._();

  static const _installIdKey = 'pushInstallId';

  bool _enabled = false;
  bool _signedIn = false;

  /// FCM token + access token last registered, to skip identical calls.
  String? _registeredToken;
  String? _registeredWith;
  Future<void>? _pending;

  bool get enabled => _enabled;

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  Future<void> init() async {
    try {
      await Firebase.initializeApp();
    } catch (e) {
      // No google-services.json / GoogleService-Info.plist in this build.
      debugPrint('[push] disabled, Firebase is not configured: $e');
      return;
    }
    _enabled = true;
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    _messaging.onTokenRefresh.listen((token) {
      if (_signedIn) _register(token);
    });
  }

  /// [user] is `authProvider`'s value: null when signed out, `{}` when the
  /// profile could not be loaded (offline), `userType == 3` for guests.
  Future<void> syncWithUser(Json? user) async {
    final accessToken = Cookies.get('accessToken');
    _signedIn = user != null &&
        user.isNotEmpty &&
        intOf(user['userType']) != 3 &&
        accessToken != null &&
        accessToken.isNotEmpty;
    if (!_enabled || !_signedIn) return;
    // One sync at a time; the auth provider can emit twice around sign-in.
    _pending ??= _syncToken().whenComplete(() => _pending = null);
    await _pending;
  }

  Future<void> _syncToken() async {
    try {
      final settings = await _messaging.requestPermission();
      final allowed = settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      if (!allowed) {
        debugPrint('[push] permission ${settings.authorizationStatus}, not registering');
        return;
      }
      final token = await _getToken();
      if (token != null) await _register(token);
    } catch (e) {
      debugPrint('[push] token sync failed: $e');
    }
  }

  /// On iOS the FCM token only exists once APNs has handed one over.
  Future<String?> _getToken() async {
    if (!kIsWeb && Platform.isIOS) {
      String? apns;
      for (var i = 0; i < 10 && apns == null; i++) {
        apns = await _messaging.getAPNSToken();
        if (apns == null) await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      if (apns == null) {
        debugPrint('[push] no APNs token (simulator, or push capability missing)');
        return null;
      }
    }
    return _messaging.getToken();
  }

  Future<void> _register(String token) async {
    final accessToken = Cookies.get('accessToken');
    if (accessToken == null || accessToken.isEmpty) return;
    if (token == _registeredToken && accessToken == _registeredWith) return;
    try {
      final res = await BmpApi.registerDeviceToken({
        'token': token,
        'platform': Platform.isIOS ? 'ios' : 'android',
        'deviceId': _installId(),
        'appVersion': await _appVersion(),
      });
      if (intOf(obj(res.data)['statusCode']) == 200) {
        _registeredToken = token;
        _registeredWith = accessToken;
      } else {
        debugPrint('[push] register rejected: ${res.data}');
      }
    } catch (e) {
      // Retried on the next sign-in, app start or token refresh.
      debugPrint('[push] register failed: $e');
    }
  }

  /// Call with the access token that is about to be dropped.
  Future<void> unregister(String? accessToken) async {
    _signedIn = false;
    if (!_enabled) return;
    final token = _registeredToken;
    _registeredToken = null;
    _registeredWith = null;
    try {
      final current = token ?? await _messaging.getToken();
      if (current != null && accessToken != null && accessToken.isNotEmpty) {
        await BmpApi.removeDeviceToken(current, accessToken);
      }
    } catch (e) {
      debugPrint('[push] unregister failed: $e');
    }
    try {
      // A fresh token for whoever signs in next on this device.
      await _messaging.deleteToken();
    } catch (e) {
      debugPrint('[push] deleteToken failed: $e');
    }
  }

  String _installId() {
    var id = Cookies.prefs.getString(_installIdKey);
    if (id == null || id.isEmpty) {
      id = const Uuid().v4();
      Cookies.prefs.setString(_installIdKey, id);
    }
    return id;
  }

  Future<String> _appVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return '${info.version}+${info.buildNumber}';
    } catch (_) {
      return '';
    }
  }
}
