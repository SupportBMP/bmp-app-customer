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
