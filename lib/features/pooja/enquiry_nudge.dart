import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api/bmp_api.dart';
import '../../core/storage/cookies.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/json.dart';
import '../../core/utils/launch.dart';
import '../../core/utils/leads.dart';
import '../../core/widgets/brand_icons.dart';
import '../festival/festival_state.dart';
import '../festival/ornaments.dart';
import 'pdp_widgets.dart';

/// Port of bmp_fe components/PoojaComponent/PoojaEnquiryNudge.jsx.
///
/// After [dwellSeconds] of foreground time on a pooja page, offers a short
/// callback form. Never opens once Book Now / Get a Quote was tapped, while
/// checkout or another sheet/dialog is open, if it already showed this
/// session, or for 7 days after a submit. (The website's desktop exit-intent
/// trigger has no app equivalent.)
class PoojaEnquiryNudge extends StatefulWidget {
  const PoojaEnquiryNudge({
    super.key,
    required this.poojaName,
    required this.poojaSlug,
    required this.language,
    required this.location,
    required this.packages,
    required this.suppressed,
    required this.pageUrl,
  });

  final String poojaName;
  final String poojaSlug;
  final String language;
  final String location;

  /// Package labels the pooja offers (Basic / Standard / Premium).
  final List<String> packages;

  /// True once booking or a quote has started.
  final bool Function() suppressed;
  final String pageUrl;

  static const dwellSeconds = 45;
  static const sessionKey = 'bmp_pdp_enquiry_shown';
  static const leadKey = 'bmp_pdp_enquiry_lead_at';
  static const cooldown = Duration(days: 7);

  static bool recentlySubmitted() {
    final at = Cookies.prefs.getInt(leadKey);
    return at != null && DateTime.now().millisecondsSinceEpoch - at < cooldown.inMilliseconds;
  }

  @override
  State<PoojaEnquiryNudge> createState() => _PoojaEnquiryNudgeState();
}

class _PoojaEnquiryNudgeState extends State<PoojaEnquiryNudge> {
  Timer? _ticker;
  int _active = 0;
  bool _foreground = true;
  late final AppLifecycleListener _life;

  @override
  void initState() {
    super.initState();
    _life = AppLifecycleListener(onStateChange: (s) => _foreground = s == AppLifecycleState.resumed);
    _arm();
  }

  @override
  void didUpdateWidget(covariant PoojaEnquiryNudge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.poojaSlug != widget.poojaSlug) {
      _ticker?.cancel();
      _active = 0;
      _arm();
    }
  }

  void _arm() {
    if (widget.poojaSlug.isEmpty) return;
    if (fxSessionFlags.contains(PoojaEnquiryNudge.sessionKey) || PoojaEnquiryNudge.recentlySubmitted()) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_foreground) return;
      _active++;
      // Keep retrying each second once due, so a busy moment just defers it.
      if (_active >= PoojaEnquiryNudge.dwellSeconds) _fire();
    });
  }

  bool get _otherModalOpen => !(ModalRoute.of(context)?.isCurrent ?? true);

  void _fire() {
    if (!mounted || widget.suppressed() || _otherModalOpen) return;
    if (fxSessionFlags.contains(PoojaEnquiryNudge.sessionKey)) {
      _ticker?.cancel();
      return;
    }
    _ticker?.cancel();
    fxSessionFlags.add(PoojaEnquiryNudge.sessionKey);
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .55),
      builder: (ctx) => _NudgeDialog(widget: widget),
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _life.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

const _greetings = {
  'hindi': 'नमस्ते',
  'marathi': 'नमस्कार',
  'gujarati': 'નમસ્તે',
  'bengali': 'নমস্কার',
  'kannada': 'ನಮಸ್ಕಾರ',
  'telugu': 'నమస్కారం',
  'tamil': 'வணக்கம்',
};

const _whenOptions = ['This week', 'This month', 'Later', 'Not decided'];

class _NudgeDialog extends StatelessWidget {
  const _NudgeDialog({required this.widget});
  final PoojaEnquiryNudge widget;

  @override
  Widget build(BuildContext context) {
    final greeting = _greetings[widget.language.toLowerCase()] ?? 'Namaste';
    final lang = titleCaseWords(widget.language);
    final city = titleCaseWords(widget.location);
    return Dialog(
      backgroundColor: pdpCream,
      insetPadding: const EdgeInsets.all(12),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 448),
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF8A1C23), Color(0xFF9E2A1F), Color(0xFFC2410C)],
                ),
              ),
              child: Stack(children: [
                const Positioned(top: 0, left: 0, right: 0, child: ToranGarland(height: 20)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const DiyaIcon(size: 32),
                      const SizedBox(width: 8),
                      Text('$greeting 🙏', style: AppText.body(size: 18, weight: FontWeight.w600, color: const Color(0xFFFDE68A))),
                    ]),
                    const SizedBox(height: 8),
                    Text('Planning your ${widget.poojaName.isEmpty ? 'puja' : widget.poojaName}?',
                        style: AppText.heading(size: 24, weight: FontWeight.w700, color: Colors.white, height: 1.2)),
                    const SizedBox(height: 6),
                    Text(
                      'Share your number. Our Puja Seva team will call you with auspicious dates, samagri details and the right '
                      'package for your family. Free, no obligation.',
                      style: AppText.body(size: 14, color: Colors.white.withValues(alpha: .85), height: 1.55),
                    ),
                    const SizedBox(height: 12),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      if (lang.isNotEmpty) _headerChip('$lang-speaking pandit'),
                      if (city.isNotEmpty) _headerChip(city),
                    ]),
                  ]),
                ),
                Positioned(
                  top: 22,
                  right: 10,
                  child: Semantics(
                    button: true,
                    label: 'Close',
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .8), shape: BoxShape.circle),
                        child: const Icon(LucideIcons.x, size: 16, color: pdpMutedInk),
                      ),
                    ),
                  ),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: _EnquiryForm(widget: widget, language: lang, city: city),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _headerChip(String s) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .15), borderRadius: BorderRadius.circular(999)),
        child: Text(s, style: AppText.body(size: 12, weight: FontWeight.w600, color: Colors.white)),
      );
}

class _EnquiryForm extends StatefulWidget {
  const _EnquiryForm({required this.widget, required this.language, required this.city});
  final PoojaEnquiryNudge widget;
  final String language;
  final String city;

  @override
  State<_EnquiryForm> createState() => _EnquiryFormState();
}

class _EnquiryFormState extends State<_EnquiryForm> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  String _when = '';
  String _pkg = '';
  bool _busy = false;
  bool _failed = false;
  String? _doneName;

  PoojaEnquiryNudge get w => widget.widget;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  String get _phoneError => _phone.text.isNotEmpty && !isValidIndianMobile(_phone.text) ? 'Enter a valid 10-digit mobile number.' : '';

  bool get _ready => _name.text.trim().length >= 2 && _phone.text.length == 10 && _phoneError.isEmpty;

  String _waMessage() {
    final pooja = w.poojaName.isEmpty ? 'a puja' : w.poojaName;
    return "Namaste BookMyPooja 🙏 I'd like help with $pooja"
        '${widget.city.isNotEmpty ? ' in ${widget.city}' : ''}${widget.language.isNotEmpty ? ' (${widget.language} pandit)' : ''}.'
        '${_when.isNotEmpty ? '\nWhen: $_when' : ''}${_pkg.isNotEmpty ? '\nPackage: $_pkg' : ''}';
  }

  Future<void> _submit() async {
    if (!_ready || _busy) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    final enquiry = [
      'Pooja page popup',
      'Trigger: dwell',
      'Pooja: ${w.poojaName.isEmpty ? w.poojaSlug : w.poojaName}',
      'When: ${_when.isEmpty ? 'NA' : _when}',
      'Package: ${_pkg.isEmpty ? 'NA' : _pkg}',
    ].join(' - ');
    var ok = false;
    try {
      final body = createCrmLeadEnquiryBody({
        'name': _name.text.trim(),
        'phone': _phone.text,
        'city': widget.city,
        'language': widget.language.isEmpty ? 'Any' : widget.language,
        'enquiry': enquiry,
      });
      final res = await BmpApi.postGlobalLeadCapture({
        ...body,
        'pooja-enquired': w.poojaName.isEmpty ? w.poojaSlug : w.poojaName,
        'source': 'App · Pooja page popup',
        'webPageLink': w.pageUrl,
      });
      ok = intOf(obj(res.data)['statusCode']) == 200;
    } catch (e) {
      debugPrint('Pooja enquiry lead failed: $e');
    }
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _busy = false;
        _failed = true;
      });
      return;
    }
    Cookies.prefs.setInt(PoojaEnquiryNudge.leadKey, DateTime.now().millisecondsSinceEpoch);
    setState(() {
      _busy = false;
      _doneName = _name.text.trim().split(' ').first;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_doneName != null) {
      return Column(children: [
        const Icon(LucideIcons.circleCheck, size: 40, color: Color(0xFF1FA855)),
        const SizedBox(height: 12),
        Text('Thank you, $_doneName!', style: AppText.body(size: 16, weight: FontWeight.w600, color: pdpInk)),
        const SizedBox(height: 6),
        Text('Our Puja Seva team will call you shortly (8 AM – 9 PM).',
            textAlign: TextAlign.center, style: AppText.body(size: 14, color: pdpMutedInk)),
        const SizedBox(height: 14),
        _filledButton(
          color: const Color(0xFF1FA855),
          onTap: () => openWhatsApp(_waMessage()),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const WhatsAppIcon(size: 20),
            const SizedBox(width: 8),
            Text('Continue on WhatsApp', style: AppText.body(size: 14, weight: FontWeight.w700, color: Colors.white)),
          ]),
        ),
      ]);
    }

    final err = _phoneError;
    final packageOptions = [...w.packages, 'Not sure'];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _box(
        child: TextField(
          controller: _name,
          autofillHints: const [AutofillHints.name],
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => setState(() {}),
          style: AppText.body(size: 14, color: pdpInk),
          decoration: _input('Your name'),
        ),
      ),
      const SizedBox(height: 12),
      _box(
        child: Row(children: [
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            color: const Color(0xFFFDF1E0),
            child: Text('+91', style: AppText.body(size: 14, color: pdpMutedInk)),
          ),
          Expanded(
            child: TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              autofillHints: const [AutofillHints.telephoneNumberNational],
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
              onChanged: (_) => setState(() {}),
              style: AppText.body(size: 14, color: pdpInk),
              decoration: _input('10-digit mobile number'),
            ),
          ),
        ]),
      ),
      if (err.isNotEmpty)
        Padding(padding: const EdgeInsets.only(top: 6), child: Text(err, style: AppText.body(size: 12, color: AppColors.red500))),
      const SizedBox(height: 14),
      _chips('When is your puja? (optional)', _whenOptions, _when, (v) => setState(() => _when = _when == v ? '' : v)),
      if (w.packages.isNotEmpty) ...[
        const SizedBox(height: 14),
        _chips("Package you're considering (optional)", packageOptions, _pkg, (v) => setState(() => _pkg = _pkg == v ? '' : v)),
      ],
      if (_failed) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8)),
          child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text("We couldn't send your request. ", style: AppText.body(size: 12, color: const Color(0xFFB91C1C))),
            GestureDetector(
              onTap: () => openWhatsApp(_waMessage()),
              child: Text('Message us on WhatsApp',
                  style: AppText.body(size: 12, weight: FontWeight.w700, color: const Color(0xFFB91C1C), decoration: TextDecoration.underline)),
            ),
            Text(' or call ', style: AppText.body(size: 12, color: const Color(0xFFB91C1C))),
            GestureDetector(
              onTap: () => callPhone(),
              child: Text(leadPhoneLabel,
                  style: AppText.body(size: 12, weight: FontWeight.w700, color: const Color(0xFFB91C1C), decoration: TextDecoration.underline)),
            ),
            Text('.', style: AppText.body(size: 12, color: const Color(0xFFB91C1C))),
          ]),
        ),
      ],
      const SizedBox(height: 14),
      Opacity(
        opacity: _ready && !_busy ? 1 : .6,
        child: _filledButton(
          color: AppColors.bluntRed,
          onTap: _ready && !_busy ? _submit : null,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(LucideIcons.phoneCall, size: 16, color: Colors.white),
            const SizedBox(width: 8),
            Text(_busy ? 'Sending…' : 'Get a free call back', style: AppText.body(size: 14, weight: FontWeight.w700, color: Colors.white)),
          ]),
        ),
      ),
      const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _meta(LucideIcons.clock, '8 AM – 9 PM'),
        const SizedBox(width: 16),
        _meta(LucideIcons.shieldCheck, 'No spam'),
        const SizedBox(width: 16),
        GestureDetector(
          onTap: () => callPhone(),
          child: _meta(LucideIcons.phone, 'Call now', color: AppColors.bluntRed, weight: FontWeight.w600),
        ),
      ]),
    ]);
  }

  InputDecoration _input(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: AppText.body(size: 14, color: const Color(0xFFA08070)),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        filled: false,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      );

  Widget _box({required Widget child}) => Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE6D3B3)),
        ),
        child: child,
      );

  Widget _chips(String label, List<String> options, String selected, ValueChanged<String> onTap) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: AppText.body(size: 12, weight: FontWeight.w600, color: pdpMutedInk)),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final o in options)
            Semantics(
              button: true,
              selected: selected == o,
              child: GestureDetector(
                onTap: () => onTap(o),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: selected == o ? AppColors.bluntRed : Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: selected == o ? AppColors.bluntRed : const Color(0xFFE6D3B3)),
                  ),
                  child: Text(o, style: AppText.body(size: 12, weight: FontWeight.w600, color: selected == o ? Colors.white : pdpInk)),
                ),
              ),
            ),
        ]),
      ]);

  Widget _filledButton({required Color color, required VoidCallback? onTap, required Widget child}) => Material(
        color: color,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: SizedBox(height: 48, child: Center(child: child)),
        ),
      );

  Widget _meta(IconData icon, String label, {Color color = pdpMutedInk, FontWeight weight = FontWeight.w400}) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label, style: AppText.body(size: 11, color: color, weight: weight)),
      ]);
}
