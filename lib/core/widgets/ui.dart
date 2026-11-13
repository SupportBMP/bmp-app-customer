import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'native.dart';

/// shadcn `Button` variants (components/v2/ui/button.jsx).
enum BtnVariant { primary, destructive, outline, secondary, ghost, link }

enum BtnSize { md, sm, lg, icon }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.onPressed,
    this.label,
    this.child,
    this.icon,
    this.trailingIcon,
    this.variant = BtnVariant.primary,
    this.size = BtnSize.md,
    this.expand = false,
    this.height,
    this.radius,
    this.background,
    this.foreground,
    this.borderColor,
    this.borderWidth = 1,
    this.textStyle,
    this.padding,
    this.loading = false,
    this.shadow,
  });

  final VoidCallback? onPressed;
  final String? label;
  final Widget? child;
  final IconData? icon;
  final IconData? trailingIcon;
  final BtnVariant variant;
  final BtnSize size;
  final bool expand;
  final double? height;
  final double? radius;
  final Color? background;
  final Color? foreground;
  final Color? borderColor;
  final double borderWidth;
  final TextStyle? textStyle;
  final EdgeInsets? padding;
  final bool loading;
  final List<BoxShadow>? shadow;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || loading;
    final (bg, fg, border) = switch (variant) {
      BtnVariant.primary => (AppColors.primary, AppColors.primaryForeground, null),
      BtnVariant.destructive => (AppColors.destructive, Colors.white, null),
      BtnVariant.outline => (AppColors.background, AppColors.foreground, AppColors.border),
      BtnVariant.secondary => (AppColors.secondary, AppColors.foreground, null),
      BtnVariant.ghost => (Colors.transparent, AppColors.foreground, null),
      BtnVariant.link => (Colors.transparent, AppColors.primary, null),
    };
    final h = height ??
        switch (size) {
          BtnSize.md => 40.0,
          BtnSize.sm => 36.0,
          BtnSize.lg => 44.0,
          BtnSize.icon => 40.0,
        };
    final r = radius ?? (size == BtnSize.lg ? 999.0 : 8.0);
    final pad = padding ??
        switch (size) {
          BtnSize.md => const EdgeInsets.symmetric(horizontal: 16),
          BtnSize.sm => const EdgeInsets.symmetric(horizontal: 12),
          BtnSize.lg => const EdgeInsets.symmetric(horizontal: 32),
          BtnSize.icon => EdgeInsets.zero,
        };
    final fgc = foreground ?? fg;
    final style = (textStyle ?? AppText.body(size: 14, weight: FontWeight.w500)).copyWith(color: fgc);

    Widget content = child ??
        Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: fgc)),
              )
            else if (icon != null)
              Padding(
                padding: EdgeInsets.only(right: label == null ? 0 : 8),
                child: Icon(icon, size: 16, color: fgc),
              ),
            if (label != null) Flexible(child: Text(label!, style: style, textAlign: TextAlign.center)),
            if (trailingIcon != null)
              Padding(padding: const EdgeInsets.only(left: 8), child: Icon(trailingIcon, size: 16, color: fgc)),
          ],
        );
    if (child != null) {
      content = DefaultTextStyle.merge(style: style, child: IconTheme.merge(data: IconThemeData(color: fgc, size: 16), child: content));
    }

    return Opacity(
      opacity: disabled && !loading ? 0.5 : 1,
      child: Container(
        height: h,
        width: size == BtnSize.icon ? h : (expand ? double.infinity : null),
        decoration: BoxDecoration(
          color: background ?? bg,
          borderRadius: BorderRadius.circular(r),
          border: (borderColor ?? border) == null ? null : Border.all(color: borderColor ?? border!, width: borderWidth),
          boxShadow: shadow,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(r),
            onTap: disabled ? null : onPressed,
            child: Padding(padding: pad, child: Center(widthFactor: 1, child: content)),
          ),
        ),
      ),
    );
  }
}

/// Plain tappable wrapper with no ripple shape constraints.
class Tap extends StatelessWidget {
  const Tap({super.key, required this.child, this.onTap, this.radius = 0});
  final Widget child;
  final VoidCallback? onTap;
  final double radius;

  @override
  Widget build(BuildContext context) => Material(
        type: MaterialType.transparency,
        child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(radius), child: child),
      );
}

/// Section heading: `Title <span class="text-primary">Highlight</span>` — the
/// pattern every v2 landing section uses.
class HighlightHeading extends StatelessWidget {
  const HighlightHeading({
    super.key,
    required this.title,
    this.highlight,
    this.size = 24,
    this.align = TextAlign.center,
    this.color = AppColors.foreground,
    this.highlightColor = AppColors.primary,
  });

  final String title;
  final String? highlight;
  final double size;
  final TextAlign align;
  final Color color;
  final Color highlightColor;

  @override
  Widget build(BuildContext context) {
    final h = highlight;
    final base = AppText.heading(size: size, color: color);
    if (h == null || h.isEmpty || !title.contains(h)) {
      return Text.rich(
        TextSpan(children: [
          TextSpan(text: title),
          if (h != null && h.isNotEmpty && !title.contains(h)) ...[
            const TextSpan(text: ' '),
            TextSpan(text: h, style: TextStyle(color: highlightColor)),
          ],
        ]),
        style: base,
        textAlign: align,
      );
    }
    final i = title.indexOf(h);
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: title.substring(0, i)),
        TextSpan(text: h, style: TextStyle(color: highlightColor)),
        TextSpan(text: title.substring(i + h.length)),
      ]),
      style: base,
      textAlign: align,
    );
  }
}

/// shadcn Dialog: centered card, `max-w-lg`, rounded-lg, close X top-right.
Future<T?> showAppDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool showClose = true,
  bool barrierDismissible = true,
  EdgeInsets padding = const EdgeInsets.all(24),
  Color background = Colors.white,
  double maxWidth = 512,
  double radius = 12,
  Color closeColor = AppColors.foreground,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: 'Close',
    barrierColor: Colors.black.o(0.8),
    transitionDuration: const Duration(milliseconds: 200),
    transitionBuilder: (ctx, a, _, child) => FadeTransition(
      opacity: a,
      child: ScaleTransition(scale: Tween(begin: 0.95, end: 1.0).animate(a), child: child),
    ),
    pageBuilder: (ctx, _, _) => SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Material(
              color: background,
              borderRadius: BorderRadius.circular(radius),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  Padding(padding: padding, child: Builder(builder: builder)),
                  if (showClose)
                    Positioned(
                      right: 12,
                      top: 12,
                      child: IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: Icon(LucideIcons.x, size: 16, color: closeColor.o(0.7)),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// shadcn Sheet: a full-height panel from the left or right (`w-3/4 sm:max-w-sm`
/// unless the page overrides the width).
Future<T?> showSideSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool fromLeft = false,
  double width = 288,
  bool showClose = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: Colors.black.o(0.8),
    transitionDuration: const Duration(milliseconds: 300),
    transitionBuilder: (ctx, a, _, child) => SlideTransition(
      position: Tween(begin: Offset(fromLeft ? -1 : 1, 0), end: Offset.zero)
          .animate(CurvedAnimation(parent: a, curve: Curves.easeOut)),
      child: child,
    ),
    pageBuilder: (ctx, _, _) {
      final w = width.clamp(0.0, MediaQuery.sizeOf(ctx).width * 0.85);
      return Align(
        alignment: fromLeft ? Alignment.centerLeft : Alignment.centerRight,
        child: Material(
          color: AppColors.background,
          elevation: 16,
          child: SizedBox(
            width: w,
            height: double.infinity,
            child: SafeArea(
              child: Stack(
                children: [
                  Positioned.fill(child: Builder(builder: builder)),
                  if (showClose)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: Icon(LucideIcons.x, size: 16, color: AppColors.foreground.o(0.7)),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// Bottom sheet used where the website shows a popover/select list.
Future<T?> showPickerSheet<T>(
  BuildContext context, {
  required String title,
  required List<T> options,
  required String Function(T) labelOf,
  T? selected,
}) =>
    showNativePicker<T>(context, title: title, options: options, labelOf: labelOf, selected: selected);

/// shadcn Accordion item: trigger row with rotating chevron, border-b.
class AccordionTile extends StatefulWidget {
  const AccordionTile({
    super.key,
    required this.title,
    required this.child,
    this.initiallyOpen = false,
    this.padding = const EdgeInsets.symmetric(vertical: 16),
    this.showBorder = true,
    this.open,
    this.onToggle,
    this.chevronColor,
  });

  final Widget title;
  final Widget child;
  final bool initiallyOpen;
  final EdgeInsets padding;
  final bool showBorder;

  /// Controlled mode (single-open accordions).
  final bool? open;
  final VoidCallback? onToggle;
  final Color? chevronColor;

  @override
  State<AccordionTile> createState() => _AccordionTileState();
}

class _AccordionTileState extends State<AccordionTile> {
  late bool _open = widget.initiallyOpen;

  bool get _isOpen => widget.open ?? _open;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: widget.showBorder
          ? const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border)))
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () {
              if (widget.onToggle != null) {
                widget.onToggle!();
              } else {
                setState(() => _open = !_open);
              }
            },
            child: Padding(
              padding: widget.padding,
              child: Row(
                children: [
                  Expanded(child: widget.title),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _isOpen ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(LucideIcons.chevronDown, size: 16, color: widget.chevronColor),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: _isOpen ? widget.child : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

/// The app's loader: the diya emblem breathing in place of a spinner.
class AppSpinner extends StatefulWidget {
  const AppSpinner({super.key, this.size = 48});
  final double size;

  @override
  State<AppSpinner> createState() => _AppSpinnerState();
}

class _AppSpinnerState extends State<AppSpinner> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat(reverse: true);
  late final Animation<double> _t = CurvedAnimation(parent: _c, curve: Curves.easeInOut);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Center(
        child: Semantics(
          label: 'Loading',
          child: AnimatedBuilder(
            animation: _t,
            builder: (_, child) => Opacity(
              opacity: .55 + .45 * _t.value,
              child: Transform.scale(scale: .9 + .1 * _t.value, child: child),
            ),
            child: SvgPicture.asset('assets/images/splash/emblem.svg', width: widget.size, height: widget.size * 242 / 204),
          ),
        ),
      );
}

/// Gap helpers to keep layout code close to Tailwind's spacing scale.
class Gap extends StatelessWidget {
  const Gap(this.size, {super.key});
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox(width: size, height: size);
}

/// Bulleted check row (`CheckCircle` + text) used in hero sections.
class CheckLine extends StatelessWidget {
  const CheckLine(this.text, {super.key, this.color = AppColors.mutedForeground, this.iconColor = AppColors.primary, this.size = 16});
  final String text;
  final Color color;
  final Color iconColor;
  final double size;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(LucideIcons.circleCheck, size: 20, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: AppText.sans(size: size, weight: FontWeight.w500, color: color))),
        ],
      );
}
