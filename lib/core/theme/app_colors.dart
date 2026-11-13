import 'package:flutter/material.dart';

/// Colours of the website's `.new-v2-theme` (styles/globals.css) plus the
/// custom Tailwind colours in tailwind.config.js.
class AppColors {
  AppColors._();

  // .new-v2-theme CSS variables
  static const background = Color(0xFFFFFFFF);
  static const foreground = Color(0xFF212121);
  static const card = Color(0xFFFFFFFF);
  static const primary = Color(0xFF91121D); // hsl(355 78% 32%)
  static const primaryForeground = Color(0xFFFFFFFF);
  static const secondary = Color(0xFFF5F3EF); // hsl(40 25% 95%)
  static const muted = Color(0xFFF7F5F3); // hsl(40 20% 96%)
  static const mutedForeground = Color(0xFF595959); // hsl(0 0% 35%)
  static const accent = primary;
  static const destructive = Color(0xFFEF4343);
  static const border = Color(0xFFE5E0DC); // hsl(30 15% 88%)
  static const whatsapp = Color(0xFF1FAD53); // hsl(142 70% 40%)
  static const whatsappBrand = Color(0xFF25D366);

  /// `gold` resolves to `hsl(var(--gold))`, which v2 sets to the primary.
  static const gold = primary;

  // oklch palettes from tailwind.config.js
  static const saffron = Color(0xFFEF852E);
  static const saffronDark = Color(0xFFC56C21);
  static const saffronLight = Color(0xFFFFAF76);
  static const maroon = Color(0xFF6B141F);
  static const maroonDark = Color(0xFF4F0913);
  static const maroonLight = Color(0xFF843B3E);
  static const cream = Color(0xFFF9F4EE);
  static const creamDark = Color(0xFFF1E6DA);

  // Legacy named colours
  static const bluntRed = Color(0xFF8A1C23);
  static const hoverModalButton = Color(0xFF6C151B);
  static const defaultText = Color(0xFF475569); // `text-Default`
  static const headerQuote = Color(0xFF94A3B8);
  static const lightGrey = Color(0xFFCBD5E1);
  static const phDefault = Color(0xFF707070);
  static const profileBg = Color(0xFFF8F9FA);
  static const darkOrange = Color(0xFFD9000E);
  static const pendingColor = Color(0xFFECBF08);
  static const acceptedColor = Color(0xFF168838);
  static const cancelledColor = Color(0xFFCF4E10);
  static const pendingBg = Color(0x1AFFCC00);
  static const acceptedBg = Color(0x1A00A632);
  static const completedBg = Color(0x80CBD5E1);
  static const cancelledBg = Color(0x1ACF4E10);

  /// `ModalTransparentColor` (#00000066) — legacy modal backdrop.
  static const black40 = Color(0x66000000);

  // Footer (`bg-[#1a1a2e]`)
  static const footerBg = Color(0xFF1A1A2E);

  // Hero gradient stops
  static const heroFrom = Color(0xFFF9F6F1); // hsl(40 40% 96%)
  static const heroTo = Color(0xFFF8F2F2); // hsl(355 30% 96%)

  // Tailwind default palette entries used across pages
  static const gray50 = Color(0xFFF9FAFB);
  static const gray100 = Color(0xFFF3F4F6);
  static const gray200 = Color(0xFFE5E7EB);
  static const gray300 = Color(0xFFD1D5DB);
  static const gray400 = Color(0xFF9CA3AF);
  static const gray500 = Color(0xFF6B7280);
  static const gray600 = Color(0xFF4B5563);
  static const gray700 = Color(0xFF374151);
  static const gray800 = Color(0xFF1F2937);
  static const gray900 = Color(0xFF111827);
  static const slate50 = Color(0xFFF8FAFC);
  static const slate100 = Color(0xFFF1F5F9);
  static const slate200 = Color(0xFFE2E8F0);
  static const slate400 = Color(0xFF94A3B8);
  static const slate500 = Color(0xFF64748B);
  static const slate600 = Color(0xFF475569);
  static const slate700 = Color(0xFF334155);
  static const slate800 = Color(0xFF1E293B);
  static const slate900 = Color(0xFF0F172A);
  static const green50 = Color(0xFFF0FDF4);
  static const green100 = Color(0xFFDCFCE7);
  static const green500 = Color(0xFF22C55E);
  static const green600 = Color(0xFF16A34A);
  static const green700 = Color(0xFF15803D);
  static const red50 = Color(0xFFFEF2F2);
  static const red100 = Color(0xFFFEE2E2);
  static const red500 = Color(0xFFEF4444);
  static const red600 = Color(0xFFDC2626);
  static const red700 = Color(0xFFB91C1C);
  static const blue50 = Color(0xFFEFF6FF);
  static const blue100 = Color(0xFFDBEAFE);
  static const blue500 = Color(0xFF3B82F6);
  static const blue600 = Color(0xFF2563EB);
  static const blue700 = Color(0xFF1D4ED8);
  static const amber50 = Color(0xFFFFFBEB);
  static const amber100 = Color(0xFFFEF3C7);
  static const amber400 = Color(0xFFFBBF24);
  static const amber500 = Color(0xFFF59E0B);
  static const amber600 = Color(0xFFD97706);
  static const amber700 = Color(0xFFB45309);
  static const amber800 = Color(0xFF92400E);
  static const yellow400 = Color(0xFFFACC15);
  static const yellow500 = Color(0xFFEAB308);
  static const orange50 = Color(0xFFFFF7ED);
  static const orange500 = Color(0xFFF97316);
  static const orange600 = Color(0xFFEA580C);
  static const emerald50 = Color(0xFFECFDF5);
  static const emerald500 = Color(0xFF10B981);
  static const emerald600 = Color(0xFF059669);
  static const emerald700 = Color(0xFF047857);
}

extension ColorAlpha on Color {
  /// Tailwind's `/NN` opacity modifier, e.g. `primary/10` → `primary.o(.10)`.
  Color o(double opacity) => withValues(alpha: opacity);
}
