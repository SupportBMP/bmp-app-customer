import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'ui.dart';
import 'native.dart';

/// shadcn `Label` + control, stacked with `space-y-2`.
class LabeledField extends StatelessWidget {
  const LabeledField({super.key, required this.label, required this.child, this.labelStyle, this.trailingLabel});
  final String label;
  final Widget child;
  final TextStyle? labelStyle;
  final InlineSpan? trailingLabel;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text.rich(
            TextSpan(children: [TextSpan(text: label), ?trailingLabel]),
            style: labelStyle ?? AppText.sans(size: 14, weight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          child,
        ],
      );
}

/// shadcn `Input` (`h-10 rounded-md border border-input px-3 text-sm`).
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.hint,
    this.keyboardType,
    this.minHeight = 40,
    this.maxLines = 1,
    this.minLines,
    this.onChanged,
    this.focusNode,
    this.borderColor,
    this.radius = 10,
    this.inputFormatters,
    this.enabled = true,
    this.highlight = false,
    this.textCapitalization = TextCapitalization.none,
    this.fill,
    this.prefix,
    this.suffix,
    this.style,
    this.obscure = false,
    this.maxLength,
    this.autofillHints,
  });

  final TextEditingController? controller;
  final String? hint;
  final TextInputType? keyboardType;
  final double minHeight;
  final int? maxLines;
  final int? minLines;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;
  final Color? borderColor;
  final double radius;
  final List<TextInputFormatter>? inputFormatters;
  final bool enabled;
  final bool highlight;
  final TextCapitalization textCapitalization;
  final Color? fill;
  final Widget? prefix;
  final Widget? suffix;
  final TextStyle? style;
  final bool obscure;
  final int? maxLength;
  final Iterable<String>? autofillHints;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: BorderSide(color: highlight ? AppColors.primary : (borderColor ?? AppColors.border)),
    );
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        maxLines: maxLines,
        minLines: minLines,
        onChanged: onChanged,
        enabled: enabled,
        obscureText: obscure,
        maxLength: maxLength,
        inputFormatters: inputFormatters,
        textCapitalization: textCapitalization,
        autofillHints: autofillHints,
        style: style ?? AppText.body(size: 14),
        decoration: InputDecoration(
          hintText: hint,
          counterText: '',
          filled: true,
          fillColor: fill ?? (enabled ? AppColors.background : AppColors.muted),
          prefixIcon: prefix,
          suffixIcon: suffix,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: (minHeight - 20) / 2),
          hintStyle: AppText.body(size: 14, color: AppColors.mutedForeground),
          border: border,
          enabledBorder: highlight
              ? border.copyWith(borderSide: BorderSide(color: AppColors.primary.o(.5), width: 2))
              : border,
          disabledBorder: border,
          focusedBorder: border.copyWith(borderSide: const BorderSide(color: AppColors.primary, width: 2)),
        ),
      ),
    );
  }
}

/// shadcn `Select` trigger opening a bottom-sheet list.
class AppSelectField<T> extends StatelessWidget {
  const AppSelectField({
    super.key,
    required this.value,
    required this.options,
    required this.labelOf,
    required this.onChanged,
    this.placeholder = 'Select',
    this.title,
    this.minHeight = 40,
    this.radius = 10,
    this.leading,
    this.borderColor,
    this.textStyle,
    this.fill,
  });

  final T? value;
  final List<T> options;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;
  final String placeholder;
  final String? title;
  final double minHeight;
  final double radius;
  final Widget? leading;
  final Color? borderColor;
  final TextStyle? textStyle;
  final Color? fill;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final v = await showPickerSheet<T>(
          context,
          title: title ?? placeholder,
          options: options,
          labelOf: labelOf,
          selected: value,
        );
        if (v != null) onChanged(v);
      },
      child: Container(
        constraints: BoxConstraints(minHeight: minHeight),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: fill ?? AppColors.background,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: borderColor ?? AppColors.border),
        ),
        child: Row(children: [
          if (leading != null) ...[leading!, const SizedBox(width: 8)],
          Expanded(
            child: Text(
              value == null ? placeholder : labelOf(value as T),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: (textStyle ?? AppText.body(size: 14))
                  .copyWith(color: value == null ? AppColors.mutedForeground : null),
            ),
          ),
          const Icon(LucideIcons.chevronDown, size: 16, color: Color(0x80212121)),
        ]),
      ),
    );
  }
}

/// Outline "Pick a date" button + calendar (react-day-picker in a popover).
class AppDateButton extends StatelessWidget {
  const AppDateButton({
    super.key,
    required this.value,
    required this.onChanged,
    this.placeholder = 'Pick a date',
    this.firstDate,
    this.lastDate,
    this.format = 'MMMM d, y',
    this.minHeight = 44,
    this.selectable,
  });

  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final String placeholder;
  final DateTime? firstDate;
  final DateTime? lastDate;

  /// intl pattern; `PPP` in date-fns ≈ "MMMM do, y".
  final String format;
  final double minHeight;
  final bool Function(DateTime)? selectable;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return GestureDetector(
      onTap: () async {
        final first = firstDate ?? DateTime(now.year, now.month, now.day);
        final d = await showNativeDatePicker(context,
          initialDate: value != null && !value!.isBefore(first) ? value! : first,
          firstDate: first,
          lastDate: lastDate ?? DateTime(now.year + 2),
          selectableDayPredicate: selectable,
        );
        if (d != null) onChanged(d);
      },
      child: Container(
        constraints: BoxConstraints(minHeight: minHeight),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          Icon(LucideIcons.calendar, size: 16, color: value == null ? AppColors.mutedForeground : AppColors.foreground),
          const SizedBox(width: 8),
          Text(
            value == null ? placeholder : ordinalDate(value!, format),
            style: AppText.body(size: 14, color: value == null ? AppColors.mutedForeground : AppColors.foreground),
          ),
        ]),
      ),
    );
  }
}

/// date-fns `PPP` ("January 5th, 2026").
String ordinalDate(DateTime d, [String pattern = 'MMMM d, y']) {
  if (pattern != 'MMMM d, y') return DateFormat(pattern).format(d);
  final day = d.day;
  final suffix = (day % 10 == 1 && day != 11)
      ? 'st'
      : (day % 10 == 2 && day != 12)
          ? 'nd'
          : (day % 10 == 3 && day != 13)
              ? 'rd'
              : 'th';
  return '${DateFormat('MMMM').format(d)} $day$suffix, ${d.year}';
}

/// shadcn RadioGroupItem + label row.
class RadioRow<T> extends StatelessWidget {
  const RadioRow({super.key, required this.value, required this.groupValue, required this.onChanged, required this.label});
  final T value;
  final T groupValue;
  final ValueChanged<T> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(value),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 16,
            height: 16,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.primary)),
            alignment: Alignment.center,
            child: selected
                ? Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.primary))
                : null,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: AppText.sans(size: 14, weight: FontWeight.w500))),
        ],
      ),
    );
  }
}

/// shadcn Checkbox (`h-4 w-4 rounded-sm border-primary`).
class AppCheckbox extends StatelessWidget {
  const AppCheckbox({super.key, required this.value, required this.onChanged, this.color = AppColors.primary});
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color color;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => onChanged(!value),
        child: Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: value ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: color),
          ),
          child: value ? const Icon(LucideIcons.check, size: 12, color: Colors.white) : null,
        ),
      );
}

final digitsOnly = FilteringTextInputFormatter.digitsOnly;
