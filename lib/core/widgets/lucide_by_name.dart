import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// `Icons[item.icon]` lookups from the website's JSON data (lucide-react
/// PascalCase names) for the icons the data actually uses.
IconData lucideByName(String? name, [IconData fallback = LucideIcons.star]) {
  switch (name) {
    case 'BookOpen':
      return LucideIcons.bookOpen;
    case 'Clock':
      return LucideIcons.clock;
    case 'FileText':
      return LucideIcons.fileText;
    case 'Headphones':
      return LucideIcons.headphones;
    case 'HelpCircle':
      return LucideIcons.circleHelp;
    case 'Home':
      return LucideIcons.house;
    case 'Phone':
      return LucideIcons.phone;
    case 'PhoneCall':
      return LucideIcons.phoneCall;
    case 'ShieldCheck':
      return LucideIcons.shieldCheck;
    case 'Star':
      return LucideIcons.star;
    case 'UserCheck':
      return LucideIcons.userCheck;
    case 'Zap':
      return LucideIcons.zap;
    case 'MessageCircle':
    case 'Chat':
      return LucideIcons.messageCircle;
    case 'Users':
      return LucideIcons.users;
    case 'Award':
      return LucideIcons.award;
    case 'Heart':
      return LucideIcons.heart;
    case 'Sparkles':
      return LucideIcons.sparkles;
    case 'Calendar':
      return LucideIcons.calendar;
    case 'MapPin':
      return LucideIcons.mapPin;
    case 'Globe':
      return LucideIcons.globe;
    case 'Video':
      return LucideIcons.video;
    case 'Package':
      return LucideIcons.package;
    case 'CheckCircle':
      return LucideIcons.circleCheck;
    default:
      return fallback;
  }
}

/// lucide-react 0.344 brand icons (removed from later Lucide releases), used
/// by the footer's social links. Stroke-style like the rest of Lucide.
class SocialIcon extends StatelessWidget {
  const SocialIcon(this.platform, {super.key, this.size = 20, this.color = Colors.white});
  final String platform;
  final double size;
  final Color color;

  static const _paths = {
    'Facebook': '<path d="M18 2h-3a5 5 0 0 0-5 5v3H7v4h3v8h4v-8h3l1-4h-4V7a1 1 0 0 1 1-1h3z"/>',
    'Instagram':
        '<rect width="20" height="20" x="2" y="2" rx="5" ry="5"/><path d="M16 11.37A4 4 0 1 1 12.63 8 4 4 0 0 1 16 11.37z"/><line x1="17.5" x2="17.51" y1="6.5" y2="6.5"/>',
    'Twitter':
        '<path d="M22 4s-.7 2.1-2 3.4c1.6 10-9.4 17.3-18 11.6 2.2.1 4.4-.6 6-2C3 15.5.5 9.6 3 5c2.2 2.6 5.6 4.1 9 4-.9-4.2 4-6.6 7-3.8 1.1 0 3-1.2 3-1.2z"/>',
    'Youtube':
        '<path d="M2.5 17a24.12 24.12 0 0 1 0-10 2 2 0 0 1 1.4-1.4 49.56 49.56 0 0 1 16.2 0A2 2 0 0 1 21.5 7a24.12 24.12 0 0 1 0 10 2 2 0 0 1-1.4 1.4 49.55 49.55 0 0 1-16.2 0A2 2 0 0 1 2.5 17"/><path d="m10 15 5-3-5-3z"/>',
    'Linkedin':
        '<path d="M16 8a6 6 0 0 1 6 6v7h-4v-7a2 2 0 0 0-2-2 2 2 0 0 0-2 2v7h-4v-7a6 6 0 0 1 6-6z"/><rect width="4" height="12" x="2" y="9"/><circle cx="4" cy="4" r="2"/>',
  };

  @override
  Widget build(BuildContext context) {
    final p = _paths[platform];
    if (p == null) return Icon(LucideIcons.globe, size: size, color: color);
    return SvgPicture.string(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#000" stroke-width="2" '
      'stroke-linecap="round" stroke-linejoin="round">$p</svg>',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}
