import 'package:url_launcher/url_launcher.dart';

import '../config.dart';

/// `window.open(url, '_blank')` for external links (WhatsApp, maps, social).
Future<void> openExternal(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

Future<void> callPhone([String phone = AppConfig.phoneNumber]) =>
    openExternal(phone.startsWith('tel:') ? phone : 'tel:$phone');

/// `https://wa.me/<n>?text=<message>`.
String whatsappLink(String message, [String number = AppConfig.whatsappNumber]) =>
    'https://wa.me/$number?text=${Uri.encodeComponent(message)}';

Future<void> openWhatsApp(String message, [String number = AppConfig.whatsappNumber]) =>
    openExternal(whatsappLink(message, number));

/// The website appends `Reference: <origin><path>` to WhatsApp messages; the
/// app references the same page on the website.
String pageReference(String path) => 'Reference: ${AppConfig.siteUrl}$path';
