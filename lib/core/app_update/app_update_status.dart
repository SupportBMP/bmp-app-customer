import 'dart:io' show Platform;

import 'package:package_info_plus/package_info_plus.dart';

import '../api/bmp_api.dart';

/// Response of `GET /pooja-global/app-config` (BMP_BE).
class AppUpdateStatus {
  const AppUpdateStatus({
    required this.maintenance,
    required this.maintenanceMessage,
    required this.updateAvailable,
    required this.forceUpdate,
    required this.updateMessage,
    required this.latestVersion,
    required this.storeUrl,
  });

  final bool maintenance;
  final String maintenanceMessage;
  final bool updateAvailable;
  final bool forceUpdate;
  final String updateMessage;
  final String latestVersion;
  final String storeUrl;

  factory AppUpdateStatus.fromJson(Map json) => AppUpdateStatus(
        maintenance: json['maintenance'] == true,
        maintenanceMessage: (json['maintenanceMessage'] ?? '').toString(),
        updateAvailable: json['updateAvailable'] == true,
        forceUpdate: json['forceUpdate'] == true,
        updateMessage: (json['updateMessage'] ?? '').toString(),
        latestVersion: (json['latestVersion'] ?? '').toString(),
        storeUrl: (json['storeUrl'] ?? '').toString(),
      );

  /// Asks the backend what this build should do. Returns null on any failure
  /// (offline, server down, unsupported platform) so the app never gets
  /// locked out because the check itself failed.
  static Future<AppUpdateStatus?> fetch() async {
    try {
      final String platform;
      if (Platform.isAndroid) {
        platform = 'android';
      } else if (Platform.isIOS) {
        platform = 'ios';
      } else {
        return null;
      }
      final info = await PackageInfo.fromPlatform();
      final build = int.tryParse(info.buildNumber) ?? 0;
      final res = await BmpApi.appConfig(platform, build).timeout(const Duration(seconds: 10));
      final body = (res.data as Map)['body'];
      if (body is! Map) return null;
      return AppUpdateStatus.fromJson(body);
    } catch (_) {
      return null;
    }
  }
}
