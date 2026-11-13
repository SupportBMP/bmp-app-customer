/// Build-time configuration, supplied with
/// `flutter run --dart-define-from-file=env/prod.json`.
///
/// Mirrors the website's next.config.js `env` block.
class AppConfig {
  AppConfig._();

  /// BMP_BE base URL (website: `apiHost`). Always ends with a slash.
  static const String apiHost = String.fromEnvironment(
    'API_HOST',
    defaultValue: 'https://api.bookmypoojaonline.com/',
  );

  /// The website origin (website: `NEXT_PUBLIC_SITE_URL`). Used for the OTP
  /// relay (`/api/auth/send-otp`) and for share links.
  static const String siteUrl = String.fromEnvironment(
    'SITE_URL',
    defaultValue: 'https://bookmypoojaonline.com',
  );

  static const String razorpayKey = String.fromEnvironment('RAZORPAY_KEY');

  static const String googleApiKey = String.fromEnvironment('GOOGLE_API_KEY');

  /// Sanity project for downloadable pooja guides (`fileBuilder`).
  static const String sanityProjectId = String.fromEnvironment('SANITY_PROJECT_ID');

  static const String whatsappNumber = '919869929292';
  static const String phoneNumber = '+919869929292';

  /// `apiHost` joined with [path], without doubling the slash.
  static String api(String path) {
    final base = apiHost.endsWith('/') ? apiHost : '$apiHost/';
    final p = path.startsWith('/') ? path.substring(1) : path;
    return '$base$p';
  }
}
