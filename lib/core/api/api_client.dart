import 'dart:async';

import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../config.dart';
import '../storage/cookies.dart';

/// Port of lib/axios-util.ts + pages/api/apiUtils.js.
///
/// Every call carries `X-MUID`, `X-Request-Id` and a cached `X-Session-Token`
/// from `POST /auth/session/init`; a 401 caused by the session token is
/// retried once with a fresh token.
class ApiClient {
  ApiClient._() {
    _dio.interceptors.add(
      InterceptorsWrapper(onRequest: _onRequest, onError: _onError),
    );
  }

  static final ApiClient instance = ApiClient._();

  static const _sessionInitPath = '/auth/session/init';
  static const _sessionTokenErrorCode = 'SESSION_TOKEN_INVALID';
  static const _websiteHeaders = {'X-Client-Type': 'website'};

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );
  final _uuid = const Uuid();

  String? _sessionToken;
  DateTime _sessionExpiresAt = DateTime.fromMillisecondsSinceEpoch(0);
  Future<String>? _pendingSessionFetch;

  Dio get dio => _dio;

  String get muid {
    var m = Cookies.prefs.getString('muid');
    if (m == null || m.isEmpty) {
      m = _uuid.v4();
      Cookies.prefs.setString('muid', m);
    }
    return m;
  }

  Future<String> _fetchSessionToken() async {
    final res = await Dio().post(
      AppConfig.api(_sessionInitPath),
      options: Options(headers: {'X-MUID': muid, 'X-Request-Id': _uuid.v4()}),
    );
    final body = (res.data as Map)['body'] as Map;
    final token = body['sessionToken'] as String;
    final expiresIn = (body['expiresIn'] as num).toInt();
    _sessionToken = token;
    // Refresh a little early so a call doesn't race the token's own expiry.
    _sessionExpiresAt = DateTime.now().add(Duration(seconds: expiresIn - 30));
    return token;
  }

  Future<String> _getSessionToken() {
    if (_sessionToken != null && _sessionExpiresAt.isAfter(DateTime.now())) {
      return Future.value(_sessionToken);
    }
    return _pendingSessionFetch ??= _fetchSessionToken().whenComplete(() {
      _pendingSessionFetch = null;
    });
  }

  Future<void> _onRequest(RequestOptions o, RequestInterceptorHandler h) async {
    o.headers['X-MUID'] = muid;
    o.headers['X-Request-Id'] = _uuid.v4();
    if (!o.uri.path.contains(_sessionInitPath)) {
      try {
        o.headers['X-Session-Token'] = await _getSessionToken();
      } catch (_) {
        // Proceed without a token; a resulting 401 is retried once below.
      }
    }
    h.next(o);
  }

  bool _isSessionTokenError(DioException e) {
    final data = e.response?.data;
    if (data is! Map) return false;
    final msg = data['message'];
    return data['code'] == _sessionTokenErrorCode ||
        (msg is Map && msg['code'] == _sessionTokenErrorCode);
  }

  Future<void> _onError(DioException e, ErrorInterceptorHandler h) async {
    final req = e.requestOptions;
    final isSessionInit = req.uri.path.contains(_sessionInitPath);
    final isAuthenticated = req.headers['Authorization'] != null && !_isSessionTokenError(e);
    if (e.response?.statusCode == 401 &&
        req.extra['sessionRetried'] != true &&
        !isSessionInit &&
        !isAuthenticated) {
      req.extra['sessionRetried'] = true;
      _sessionToken = null;
      try {
        req.headers['X-Session-Token'] = await _getSessionToken();
        return h.resolve(await _dio.fetch(req));
      } catch (_) {
        // fall through to the rejection below
      }
    }
    h.next(e);
  }

  // ---- apiUtils.js -------------------------------------------------------

  static String _sanitize(String url) => url
      .replaceAll('0//', '0/')
      .replaceAll('.com//', '.com/')
      .replaceAll(':3000//', ':3000/')
      .replaceAll(':3002//', ':3002/');

  Map<String, String> _auth(String? token) => {
        if (token != null) 'Authorization': 'Bearer $token',
        ..._websiteHeaders,
      };

  Future<Response> get(String url) =>
      _dio.get(_sanitize(url), options: Options(headers: _websiteHeaders));

  Future<Response> getAuth(String url, String? token) =>
      _dio.get(_sanitize(url), options: Options(headers: _auth(token)));

  Future<Response> post(String url, Object? data, [String? token]) =>
      _dio.post(_sanitize(url), data: data, options: Options(headers: _auth(token)));

  Future<Response> patch(String url, Object? data, String? token) =>
      _dio.patch(_sanitize(url), data: data, options: Options(headers: _auth(token)));

  Future<Response> delete(String url, String? token, [Object? body]) =>
      _dio.delete(_sanitize(url), data: body ?? {}, options: Options(headers: _auth(token)));

  Future<Response> postFiles(String url, FormData data, String? token) => _dio.post(
        _sanitize(url),
        data: data,
        options: Options(headers: {..._auth(token), 'Content-Type': 'multipart/form-data'}),
      );

  Future<Response> postWithHeaders(String url, Object? data, Map<String, String> headers) =>
      _dio.post(_sanitize(url), data: data, options: Options(headers: {...headers, ..._websiteHeaders}));
}

/// The message BMP_BE put in an error response, if any.
String apiErrorMessage(Object error, [String fallback = 'Something went wrong']) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map) {
      final m = data['message'];
      if (m is String && m.isNotEmpty) return m;
      if (m is Map && m['message'] is String) return m['message'] as String;
      if (m is List && m.isNotEmpty) return '${m.first}';
    }
  }
  return fallback;
}
