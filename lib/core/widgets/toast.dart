import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// react-hot-toast replacement (`toast`, `toast.success`, `toast.error`),
/// shown at the bottom like the website's `<Toaster position="bottom-right" />`.
class Toast {
  Toast._();

  static final messengerKey = GlobalKey<ScaffoldMessengerState>();

  static void show(String message) => _show(message, null, null);
  static void success(String message) => _show(message, LucideIcons.circleCheck, AppColors.green500);
  static void error(String message) => _show(message, LucideIcons.circleX, AppColors.red500);

  /// A push notification received while the app is open (Android doesn't
  /// draw those itself). [onOpen] adds a "View" action.
  static void notification(String title, String body, {VoidCallback? onOpen}) {
    final m = messengerKey.currentState;
    if (m == null) return;
    m.hideCurrentSnackBar();
    m.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        elevation: 6,
        backgroundColor: Colors.white,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 6),
        action: onOpen == null ? null : SnackBarAction(label: 'View', onPressed: onOpen),
        content: Row(
          children: [
            const Icon(Icons.notifications_none, size: 20, color: Color(0xFF363636)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title.isNotEmpty)
                    Text(title, style: AppText.sans(size: 14, weight: FontWeight.w600, color: const Color(0xFF363636))),
                  if (body.isNotEmpty)
                    Text(body, style: AppText.sans(size: 13, color: const Color(0xFF5A5A5A))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void _show(String message, IconData? icon, Color? iconColor) {
    final m = messengerKey.currentState;
    if (m == null) return;
    m.hideCurrentSnackBar();
    m.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        elevation: 6,
        backgroundColor: Colors.white,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 3),
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: iconColor),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(message, style: AppText.sans(size: 14, color: const Color(0xFF363636))),
            ),
          ],
        ),
      ),
    );
  }
}
