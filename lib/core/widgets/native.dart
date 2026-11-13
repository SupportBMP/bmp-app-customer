import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// Platform-native building blocks: Material on Android, Cupertino on iOS.
/// Every select / dropdown / date field in the app goes through these.
bool useCupertino(BuildContext context) {
  final p = Theme.of(context).platform;
  return p == TargetPlatform.iOS || p == TargetPlatform.macOS;
}

/// A single-choice picker: a Material modal bottom sheet with radio rows on
/// Android, a Cupertino action sheet on iOS.
Future<T?> showNativePicker<T>(
  BuildContext context, {
  required String title,
  required List<T> options,
  required String Function(T) labelOf,
  T? selected,
  String? message,
}) {
  if (useCupertino(context)) {
    return showCupertinoModalPopup<T>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(title),
        message: message == null ? null : Text(message),
        actions: [
          for (final o in options)
            CupertinoActionSheetAction(
              isDefaultAction: o == selected,
              onPressed: () => Navigator.of(ctx).pop(o),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Flexible(child: Text(labelOf(o), overflow: TextOverflow.ellipsis)),
                if (o == selected) ...[const SizedBox(width: 8), const Icon(CupertinoIcons.checkmark_alt, size: 20)],
              ]),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
      ),
    );
  }

  return showModalBottomSheet<T>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * .75),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Text(title, style: AppText.body(size: 20, weight: FontWeight.w600)),
          ),
          if (message != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Text(message, style: AppText.body(size: 14, color: AppColors.mutedForeground)),
            ),
          const Divider(height: 1),
          Flexible(
            child: ListView(shrinkWrap: true, padding: const EdgeInsets.symmetric(vertical: 8), children: [
              for (final o in options)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                  selected: o == selected,
                  selectedTileColor: cs.primary.withValues(alpha: .06),
                  leading: Icon(
                    o == selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: o == selected ? cs.primary : AppColors.mutedForeground,
                  ),
                  title: Text(
                    labelOf(o),
                    style: AppText.body(
                      size: 16,
                      weight: o == selected ? FontWeight.w600 : FontWeight.w400,
                      color: o == selected ? cs.primary : AppColors.foreground,
                    ),
                  ),
                  onTap: () => Navigator.of(ctx).pop(o),
                ),
            ]),
          ),
        ]),
      );
    },
  );
}

/// Material date picker dialog on Android, a Cupertino wheel on iOS.
Future<DateTime?> showNativeDatePicker(
  BuildContext context, {
  DateTime? initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  bool Function(DateTime)? selectableDayPredicate,
  String title = 'Select date',
}) async {
  var initial = initialDate ?? DateTime.now();
  if (initial.isBefore(firstDate)) initial = firstDate;
  if (initial.isAfter(lastDate)) initial = lastDate;
  if (selectableDayPredicate != null && !selectableDayPredicate(initial)) {
    for (var d = initial; !d.isAfter(lastDate); d = d.add(const Duration(days: 1))) {
      if (selectableDayPredicate(d)) {
        initial = d;
        break;
      }
    }
  }

  if (!useCupertino(context)) {
    return showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: lastDate,
      selectableDayPredicate: selectableDayPredicate,
      helpText: title,
    );
  }

  var picked = initial;
  final ok = await showCupertinoModalPopup<bool>(
    context: context,
    builder: (ctx) => Container(
      height: 320,
      color: CupertinoColors.systemBackground.resolveFrom(ctx),
      child: SafeArea(
        top: false,
        child: Column(children: [
          Row(children: [
            CupertinoButton(child: const Text('Cancel'), onPressed: () => Navigator.of(ctx).pop(false)),
            Expanded(child: Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600))),
            CupertinoButton(child: const Text('Done'), onPressed: () => Navigator.of(ctx).pop(true)),
          ]),
          Expanded(
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.date,
              initialDateTime: initial,
              minimumDate: firstDate,
              maximumDate: lastDate,
              onDateTimeChanged: (d) => picked = d,
            ),
          ),
        ]),
      ),
    ),
  );
  if (ok != true) return null;
  final day = DateTime(picked.year, picked.month, picked.day);
  if (selectableDayPredicate != null && !selectableDayPredicate(day)) return null;
  return day;
}
