import 'package:intl/intl.dart';

import 'json.dart';

/// utils/utils.jsx formatting helpers.

/// `formatAmountPutComma` — western 3-digit grouping on the raw value.
String formatAmountPutComma(dynamic amount) {
  if (amount == null) return '';
  final s = '$amount';
  final parts = s.split('.');
  final whole = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  return parts.length > 1 ? '$whole.${parts[1]}' : whole;
}

/// `formatDateToDDMMYYYY`.
String formatDateToDDMMYYYY(dynamic dateString) {
  final d = DateTime.tryParse(str(dateString))?.toLocal();
  if (d == null) return '';
  return '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';
}

/// `isoDateToDDMMYYYY` — pure string reorder.
String isoDateToDDMMYYYY(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final p = iso.split('-');
  if (p.length < 3) return '';
  return '${p[2]}-${p[1]}-${p[0]}';
}

/// `ddmmyyyyToIsoDate`.
String ddmmyyyyToIsoDate(String? s) {
  if (s == null || s.isEmpty) return '';
  final p = s.split('-');
  if (p.length < 3) return '';
  return '${p[2]}-${p[1]}-${p[0]}';
}

/// `convertToIST` — `toLocaleString('en-IN', {dd/mm/yyyy, HH:mm})`.
String convertToIST(dynamic utc) {
  final d = DateTime.tryParse(str(utc));
  if (d == null) return '';
  final ist = d.toUtc().add(const Duration(hours: 5, minutes: 30));
  return '${DateFormat('dd/MM/yyyy').format(ist)}, ${DateFormat('HH:mm').format(ist)}';
}

/// `formatDate` — "5th January 2026 - 10.30" in UTC.
String formatOrdinalDate(dynamic dateString) {
  final d = DateTime.tryParse(str(dateString))?.toUtc();
  if (d == null) return str(dateString);
  final day = d.day;
  final suffix = (day % 10 == 1 && day != 11)
      ? 'st'
      : (day % 10 == 2 && day != 12)
          ? 'nd'
          : (day % 10 == 3 && day != 13)
              ? 'rd'
              : 'th';
  return '$day$suffix ${DateFormat('MMMM').format(d)} ${d.year} - ${d.hour.toString().padLeft(2, '0')}.${d.minute.toString().padLeft(2, '0')}';
}

String capitalizeWord(String? w) {
  if (w == null || w.trim().isEmpty) return '';
  return '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}';
}

/// `.replace(/\b\w/g, c => c.toUpperCase())` after replacing dashes.
String toDisplayName(String? segment) => (segment ?? '')
    .replaceAll('-', ' ')
    .replaceAllMapped(RegExp(r'\b\w'), (m) => m.group(0)!.toUpperCase())
    .replaceAll(RegExp(r'^E Pooja$'), 'E-Pooja');

/// CSS `text-transform: capitalize`.
String cssCapitalize(String s) =>
    s.replaceAllMapped(RegExp(r"(^|[\s\-/(])(\w)"), (m) => '${m.group(1)}${m.group(2)!.toUpperCase()}');
