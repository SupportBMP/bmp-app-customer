import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../utils/json.dart';
import '../site_image.dart';
import '../ui.dart';
import 'app_drawer.dart';

String currentPath(BuildContext context) {
  try {
    return GoRouterState.of(context).uri.toString();
  } catch (_) {
    return '/';
  }
}

void goLogin(BuildContext context) =>
    context.push('/auth?redirect=${Uri.encodeComponent(currentPath(context))}');

/// components/v2/commons/UserMenu.jsx
class UserMenu extends ConsumerWidget {
  const UserMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).value;
    if (user == null) {
      return AppButton(
        onPressed: () => goLogin(context),
        label: 'Login / Sign Up',
        size: BtnSize.sm,
        radius: 999,
        background: AppColors.bluntRed,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        textStyle: AppText.body(size: 14, weight: FontWeight.w600),
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showAccountSheet(context, ref),
      child: SizedBox(
        height: 40,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primary.o(.12),
            child: Stack(alignment: Alignment.center, children: [
              const Icon(LucideIcons.user, size: 18, color: AppColors.primary),
              if (strOrNull(user['profileImage']) != null)
                ClipOval(child: SiteImage(str(user['profileImage']), width: 32, height: 32, fit: BoxFit.cover, placeholderColor: Colors.transparent)),
            ]),
          ),
          const SizedBox(width: 8),
          const Icon(LucideIcons.chevronDown, size: 12, color: AppColors.mutedForeground),
          const SizedBox(width: 8),
        ]),
      ),
    );
  }
}
