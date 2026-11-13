import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api/bmp_api.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/json.dart';
import '../../core/utils/launch.dart';
import '../../core/utils/nav.dart';
import '../../core/widgets/brand_icons.dart';
import '../../core/widgets/form_fields.dart';
import '../../core/widgets/lucide_by_name.dart';
import '../../core/widgets/toast.dart';
import '../../core/widgets/ui.dart';
import '../festival/festival_state.dart';

const _container = EdgeInsets.symmetric(horizontal: 32);

// ---------------------------------------------------------------------------
// EnquiryFormSection.jsx
// ---------------------------------------------------------------------------

const _pujaTypes = [
  'Griha Pravesh (Housewarming)',
  'Satyanarayan Puja',
  'Ganesh Puja',
  'Navagraha Puja',
  'Mahamrityunjay Jaap',
  'Office / Business Puja',
  'Lakshmi Puja',
  'Vastu Shanti',
  'Shashtipoorthi',
  'Other (mention in notes)',
];

class EnquiryFormSection extends StatefulWidget {
  const EnquiryFormSection({super.key, required this.data});
  final Json data;

  @override
  State<EnquiryFormSection> createState() => _EnquiryFormSectionState();
}

class _EnquiryFormSectionState extends State<EnquiryFormSection> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _city = TextEditingController();
  final _notes = TextEditingController();
  final _notesFocus = FocusNode();
  String? _language;
  String? _pujaType;
  String _datePreference = 'auspicious';
  DateTime? _date;
  bool _disclaimer = false;
  bool _loading = false;
  bool _submitted = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _phone, _city, _notes]) {
      c.dispose();
    }
    _notesFocus.dispose();
    super.dispose();
  }

  String _slug(String p) => p.toLowerCase().replaceAll(RegExp(r'\s+'), '-');

  Future<void> _submit() async {
    if (!_disclaimer) return;
    if (_name.text.isEmpty || _phone.text.isEmpty || _city.text.isEmpty) {
      Toast.error('Please fill out this field.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await BmpApi.postGlobalLeadCapture({
        'name': _name.text,
        'phone': _phone.text,
        'language': _language ?? '',
        'city': _city.text,
        'pujaType': _pujaType ?? '',
        'notes': _notes.text,
        'datePreference': _datePreference,
        'selectedDate': _date == null ? null : DateFormat('yyyy-MM-dd').format(_date!),
        'source': 'homepage_v2_enquiry',
      });
      setState(() => _submitted = true);
      WidgetsBinding.instance.addPostFrameCallback((_) => SectionAnchors.maybeOf(context)?.scrollTo('enquiry'));
    } catch (_) {
      setState(() => _error = 'Something went wrong. Please try again or call us directly.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final success = obj(d['success']);
    final card = BoxDecoration(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
      boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 25, offset: Offset(0, 20), spreadRadius: -5)],
    );

    if (_submitted) {
      return Anchor(
        'enquiry',
        child: Padding(
          padding: _container.copyWith(top: 40, bottom: 40),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: card,
            child: Column(children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(color: AppColors.green100, shape: BoxShape.circle),
                child: const Icon(LucideIcons.circleCheck, size: 40, color: AppColors.green600),
              ),
              const SizedBox(height: 24),
              Text(strOrNull(success['title']) ?? 'Request Received!',
                  textAlign: TextAlign.center, style: AppText.heading(size: 30)),
              const SizedBox(height: 24),
              Text(
                strOrNull(success['message']) ??
                    'Thank you for reaching out. Our Puja Seva Team will call you back within 10 minutes to help you with your requirements.',
                textAlign: TextAlign.center,
                style: AppText.body(size: 18, color: AppColors.mutedForeground),
              ),
              const SizedBox(height: 40),
              AppButton(
                variant: BtnVariant.outline,
                label: strOrNull(success['buttonText']) ?? 'Submit Another Enquiry',
                onPressed: () => setState(() => _submitted = false),
              ),
            ]),
          ),
        ),
      );
    }

    final isOther = _pujaType == _slug('Other (mention in notes)');
    const field = 44.0;
    return Anchor(
      'enquiry',
      child: Padding(
        padding: _container.copyWith(top: 40, bottom: 40),
        child: Column(
          children: [
            Text(strOrNull(d['title']) ?? 'Still Have Questions?',
                textAlign: TextAlign.center,
                style: GoogleSerif.style(size: 30, color: AppColors.primary)),
            Text(
              strOrNull(d['subtitle']) ?? 'Fill out the form below and our experts will get back to you shortly.',
              textAlign: TextAlign.center,
              style: AppText.sans(size: 18, color: AppColors.mutedForeground),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: card,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LabeledField(label: 'Your Name', child: AppTextField(controller: _name, hint: 'Enter your name', minHeight: field)),
                  const SizedBox(height: 16),
                  LabeledField(
                    label: 'Phone Number',
                    child: AppTextField(controller: _phone, hint: '+91 XXXXX XXXXX', keyboardType: TextInputType.phone, minHeight: field),
                  ),
                  const SizedBox(height: 20),
                  LabeledField(
                    label: 'Language Preference',
                    child: AppSelectField<String>(
                      value: _language,
                      placeholder: 'Select language',
                      minHeight: field,
                      options: const ['hindi', 'kannada', 'telugu', 'tamil', 'marathi', 'malayalam', 'gujarati', 'bengali'],
                      labelOf: (v) => '${v[0].toUpperCase()}${v.substring(1)}',
                      onChanged: (v) => setState(() => _language = v),
                    ),
                  ),
                  const SizedBox(height: 16),
                  LabeledField(
                    label: 'Your City',
                    child: AppTextField(controller: _city, hint: 'e.g. Bangalore, Mumbai', minHeight: field),
                  ),
                  const SizedBox(height: 20),
                  LabeledField(
                    label: 'Puja Type',
                    child: AppSelectField<String>(
                      value: _pujaType,
                      placeholder: 'Select puja type',
                      minHeight: field,
                      options: _pujaTypes.map(_slug).toList(),
                      labelOf: (v) => _pujaTypes.firstWhere((p) => _slug(p) == v),
                      onChanged: (v) {
                        setState(() => _pujaType = v);
                        if (v == _slug('Other (mention in notes)')) _notesFocus.requestFocus();
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Date Preference', style: AppText.sans(size: 14, weight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  RadioRow<String>(
                    value: 'specific',
                    groupValue: _datePreference,
                    onChanged: (v) => setState(() => _datePreference = v),
                    label: '📅 Yes, I want to select a specific date',
                  ),
                  const SizedBox(height: 12),
                  RadioRow<String>(
                    value: 'auspicious',
                    groupValue: _datePreference,
                    onChanged: (v) => setState(() => _datePreference = v),
                    label: '🌟 No, I need help finding the most auspicious date',
                  ),
                  if (_datePreference == 'specific') ...[
                    const SizedBox(height: 12),
                    AppDateButton(
                      value: _date,
                      firstDate: DateTime.now().add(const Duration(days: 1)),
                      onChanged: (v) => setState(() => _date = v),
                    ),
                  ],
                  const SizedBox(height: 20),
                  LabeledField(
                    label: 'Additional Information ',
                    trailingLabel: TextSpan(
                      text: '(optional)',
                      style: AppText.sans(size: 14, color: AppColors.mutedForeground),
                    ),
                    child: AppTextField(
                      controller: _notes,
                      focusNode: _notesFocus,
                      minHeight: 80,
                      maxLines: 5,
                      minLines: 3,
                      highlight: isOther,
                      hint: isOther
                          ? 'Please describe the puja you need help with, along with any specific requirements'
                          : 'Any specific requirements, number of people, special rituals, etc.',
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEFCE8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFEF08A)),
                    ),
                    child: GestureDetector(
                      onTap: () => setState(() => _disclaimer = !_disclaimer),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: AppCheckbox(value: _disclaimer, onChanged: (v) => setState(() => _disclaimer = v)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'I understand this is an enquiry and not a booking confirmation. A coordinator will call to confirm details.',
                              style: AppText.sans(size: 14, height: 1.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 20),
                    Text(_error!, style: AppText.body(size: 14, weight: FontWeight.w500, color: AppColors.destructive)),
                  ],
                  const SizedBox(height: 20),
                  AppButton(
                    expand: true,
                    height: 52,
                    radius: 999,
                    loading: _loading,
                    icon: _loading ? null : LucideIcons.phone,
                    label: _loading ? 'Submitting...' : (strOrNull(d['buttonText']) ?? 'Request a Callback'),
                    textStyle: AppText.body(size: 16, weight: FontWeight.w600),
                    onPressed: !_disclaimer || _loading ? null : _submit,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    strOrNull(d['footerNote']) ?? 'You will get a call back within 10 minutes · Complete Stress Free Experience, Guaranteed',
                    textAlign: TextAlign.center,
                    style: AppText.body(size: 14, color: AppColors.mutedForeground),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// `font-serif` (Tailwind's ui-serif stack → Georgia-like; Android: Noto Serif).
class GoogleSerif {
  static TextStyle style({double size = 16, Color color = AppColors.foreground, FontWeight weight = FontWeight.w700}) =>
      TextStyle(fontFamily: 'serif', fontSize: size, color: color, fontWeight: weight, height: 1.25);
}

// ---------------------------------------------------------------------------
// StickyMobileCTA.jsx
// ---------------------------------------------------------------------------

class StickyMobileCta extends StatefulWidget {
  const StickyMobileCta({super.key, required this.data, required this.scrollController});
  final Json data;
  final ScrollController scrollController;

  @override
  State<StickyMobileCta> createState() => _StickyMobileCtaState();
}

class _StickyMobileCtaState extends State<StickyMobileCta> {
  bool _visible = false;
  bool _tooltip = false;
  final _timers = <Timer>[];

  @override
  void initState() {
    super.initState();
    _timers.addAll([
      Timer(const Duration(milliseconds: 600), () => setState(() => _visible = true)),
      Timer(const Duration(seconds: 3), () => setState(() => _tooltip = true)),
      Timer(const Duration(seconds: 7), () => setState(() => _tooltip = false)),
    ]);
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }

  void _action(Json tab) {
    HapticFeedback.selectionClick();
    final label = str(tab['label']);
    final anchors = SectionAnchors.maybeOf(context);
    if (label == 'Home') {
      widget.scrollController.animateTo(0, duration: const Duration(milliseconds: 600), curve: Curves.easeInOut);
    } else if (boolOf(tab['isEnquiry'])) {
      anchors?.scrollTo('enquiry');
    } else if (boolOf(tab['highlight'])) {
      anchors?.scrollTo('self-booking');
    } else if (label == 'Call') {
      callPhone(strOrNull(tab['href']) ?? 'tel:+919869929292');
    } else if (label == 'WhatsApp') {
      openWhatsApp("Hi! I'd like to chat with a Puja Advisor about a ceremony.\n\n${pageReference('/')}");
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = objList(widget.data['tabs']);
    // A compact, platform-style bottom bar: white surface, hairline border,
    // outline icons with small labels; "Insta Book" carries a filled
    // indicator pill instead of a floating button.
    return AnimatedSlide(
      offset: _visible ? Offset.zero : const Offset(0, 1),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.border, width: .5)),
          boxShadow: [BoxShadow(color: Color(0x0F000000), blurRadius: 12, offset: Offset(0, -2))],
        ),
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
        child: SizedBox(
          height: 62,
          child: Row(children: [
            for (final tab in tabs) Expanded(child: _item(tab)),
          ]),
        ),
      ),
    );
  }

  Widget _item(Json tab) {
    final highlight = boolOf(tab['highlight']);
    final enquiry = boolOf(tab['isEnquiry']);
    final fg = highlight ? AppColors.primary : AppColors.foreground.o(.72);
    final Widget icon = strOrNull(tab['customIcon']) != null
        ? WhatsAppIcon(size: 22, color: fg)
        : Icon(lucideByName(str(tab['icon']), LucideIcons.house), size: 22, color: highlight ? Colors.white : fg);

    return InkResponse(
      onTap: () => _action(tab),
      radius: 36,
      highlightShape: BoxShape.circle,
      child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
        Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 56,
            height: 30,
            alignment: Alignment.center,
            decoration: highlight
                ? BoxDecoration(
                    gradient: const LinearGradient(colors: [AppColors.primary, Color(0xFF6D131B)]),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [BoxShadow(color: AppColors.primary.o(.3), blurRadius: 8, offset: const Offset(0, 2))],
                  )
                : null,
            child: Stack(clipBehavior: Clip.none, children: [
              icon,
              if (enquiry)
                Positioned(
                  right: -2,
                  top: -1,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: AppColors.saffron,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 3),
          Text(
            str(tab['label']),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.body(size: 11, weight: highlight ? FontWeight.w700 : FontWeight.w500, color: fg, height: 1.2),
          ),
        ]),
        if (enquiry)
          Positioned(
            top: -30,
            child: AnimatedOpacity(
              opacity: _tooltip ? 1 : 0,
              duration: const Duration(milliseconds: 250),
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.foreground,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [BoxShadow(color: Color(0x26000000), blurRadius: 8)],
                  ),
                  child: Text(
                    strOrNull(tab['tooltip']) ?? 'Need help?',
                    style: AppText.body(size: 11, weight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// LiveBookingFeed.jsx
// ---------------------------------------------------------------------------

class LiveBookingFeed extends StatefulWidget {
  const LiveBookingFeed({super.key, required this.latestOrders});
  final List<Json> latestOrders;

  @override
  State<LiveBookingFeed> createState() => _LiveBookingFeedState();
}

class _LiveBookingFeedState extends State<LiveBookingFeed> with SingleTickerProviderStateMixin {
  int _index = -1;
  bool _visible = false;
  bool _dismissed = false;
  Timer? _initial;
  Timer? _interval;
  Timer? _hide;
  late final AnimationController _ping;

  List<Map<String, String>> get _feed => widget.latestOrders.map((order) {
        final created = DateTime.tryParse(str(order['createdAt'])) ?? DateTime.now();
        final mins = DateTime.now().difference(created).inMinutes.abs();
        final timeAgo = mins < 60 ? '${mins > 0 ? mins : 1} min ago' : '${mins ~/ 60} hour${mins ~/ 60 > 1 ? 's' : ''} ago';
        return {
          'name': strOrNull(order['userName']) ?? strOrNull(order['customerName']) ?? 'A devotee',
          'language': strOrNull(order['languageName']) ?? 'Hindi',
          'ritual': strOrNull(order['poojaName']) ?? 'Pooja',
          'city': strOrNull(order['locationName']) ?? 'Mumbai',
          'timeAgo': timeAgo,
        };
      }).toList();

  @override
  void initState() {
    super.initState();
    _ping = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();
    if (widget.latestOrders.isEmpty) return;
    _initial = Timer(const Duration(seconds: 8), () {
      _showNext();
      _interval = Timer.periodic(const Duration(seconds: 22), (_) => _showNext());
    });
  }

  void _showNext() {
    if (_dismissed || !mounted) return;
    setState(() {
      _index = (_index + 1) % widget.latestOrders.length;
      _visible = true;
    });
    _hide?.cancel();
    _hide = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  void dispose() {
    _initial?.cancel();
    _interval?.cancel();
    _hide?.cancel();
    _ping.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_index < 0 || _dismissed || widget.latestOrders.isEmpty) return const SizedBox.shrink();
    final b = _feed[_index];
    final w = math.min(320.0, MediaQuery.sizeOf(context).width - 32);
    return IgnorePointer(
      ignoring: !_visible,
      child: AnimatedOpacity(
        opacity: _visible ? 1 : 0,
        duration: const Duration(milliseconds: 500),
        child: AnimatedSlide(
          offset: _visible ? Offset.zero : const Offset(0, .2),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
          child: SizedBox(
            width: w,
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: const Border(
                    left: BorderSide(color: AppColors.primary, width: 4),
                    top: BorderSide(color: AppColors.border),
                    right: BorderSide(color: AppColors.border),
                    bottom: BorderSide(color: AppColors.border),
                  ),
                  boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 15, offset: Offset(0, 10), spreadRadius: -3)],
                ),
                padding: const EdgeInsets.fromLTRB(12, 12, 32, 12),
                child: Stack(clipBehavior: Clip.none, children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Row(children: [
                      SizedBox(
                        width: 8,
                        height: 8,
                        child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
                          AnimatedBuilder(
                            animation: _ping,
                            builder: (_, _) => Transform.scale(
                              scale: 1 + _ping.value,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF4ADE80).o(.75 * (1 - _ping.value)),
                                ),
                              ),
                            ),
                          ),
                          Container(decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.green500)),
                        ]),
                      ),
                      const SizedBox(width: 6),
                      Text('LIVE', style: AppText.body(size: 10, weight: FontWeight.w600, color: AppColors.green600, letterSpacing: .5)),
                    ]),
                    const SizedBox(height: 4),
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(text: b['name'], style: const TextStyle(fontWeight: FontWeight.w600)),
                        const TextSpan(text: ' booked a '),
                        TextSpan(text: b['language'], style: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.primary)),
                        const TextSpan(text: ' priest for '),
                        TextSpan(text: b['ritual'], style: const TextStyle(fontWeight: FontWeight.w500)),
                        TextSpan(text: ' in ${b['city']}'),
                      ]),
                      style: AppText.body(size: 14, height: 1.35),
                    ),
                    const SizedBox(height: 2),
                    Text(b['timeAgo']!, style: AppText.body(size: 11, color: AppColors.mutedForeground)),
                  ]),
                  Positioned(
                    right: -24,
                    top: -4,
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _visible = false;
                        _dismissed = true;
                      }),
                      child: const Icon(LucideIcons.x, size: 14, color: AppColors.mutedForeground),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ExitIntentPopup.jsx — on a phone: 70% scroll depth, fast scroll up past
// 500px, or 20 s of inactivity, after a 5 s grace period; once per session.
// ---------------------------------------------------------------------------

class ExitIntentController {
  ExitIntentController({required this.context, required this.scroll, required this.data});
  final BuildContext context;
  final ScrollController scroll;
  final Json data;

  bool _ready = false;
  bool _triggered = false;
  double _lastY = 0;
  Timer? _grace;
  Timer? _inactivity;

  void start() {
    if (fxSessionFlags.contains(exitIntentSessionKey)) return;
    _grace = Timer(const Duration(seconds: 5), () => _ready = true);
    scroll.addListener(_onScroll);
    _resetInactivity();
  }

  void onActivity() => _resetInactivity();

  void _resetInactivity() {
    _inactivity?.cancel();
    if (_triggered) return;
    _inactivity = Timer(const Duration(seconds: 20), () {
      if (_ready) _trigger();
    });
  }

  void _onScroll() {
    if (!scroll.hasClients) return;
    final pos = scroll.position;
    final y = pos.pixels;
    // Jumps made by menu links / anchors aren't the visitor scrolling.
    if (pos.userScrollDirection == ScrollDirection.idle) {
      _lastY = y;
      return;
    }
    _resetInactivity();
    final depth = (y + pos.viewportDimension) / (pos.maxScrollExtent + pos.viewportDimension);
    if (depth >= .7) _trigger();
    if (_lastY - y > 150 && y > 500) _trigger();
    _lastY = y;
  }

  void _trigger() {
    if (_triggered || !_ready || fxSessionFlags.contains(exitIntentSessionKey) || !context.mounted) return;
    // Only while the homepage is on screen, not under a pushed page.
    if (ModalRoute.of(context)?.isCurrent == false) return;
    fxSessionFlags.add(exitIntentSessionKey);
    _triggered = true;
    _inactivity?.cancel();
    showAppDialog(context, maxWidth: 448, builder: (_) => _ExitIntentForm(data: data));
  }

  void dispose() {
    _grace?.cancel();
    _inactivity?.cancel();
    scroll.removeListener(_onScroll);
  }
}

class _ExitIntentForm extends StatefulWidget {
  const _ExitIntentForm({required this.data});
  final Json data;

  @override
  State<_ExitIntentForm> createState() => _ExitIntentFormState();
}

class _ExitIntentFormState extends State<_ExitIntentForm> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  bool _loading = false;
  bool _submitted = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_name.text.isEmpty || _phone.text.isEmpty) {
      Toast.error('Please fill out this field.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await BmpApi.postGlobalLeadCapture({
        'name': _name.text,
        'phone': _phone.text,
        'source': 'exit_intent_popup',
        'pujaType': 'General Enquiry',
        'notes': 'Customer was about to exit the page.',
      });
      setState(() => _submitted = true);
    } catch (_) {
      setState(() => _error = 'Something went wrong. Please try again or call us directly.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 24),
          child: Text(
            _submitted ? (strOrNull(d['successTitle']) ?? "We'll Call You Soon! 🙏") : (strOrNull(d['title']) ?? 'Need more Guidance ?'),
            textAlign: TextAlign.center,
            style: GoogleSerif.style(size: 24, color: AppColors.bluntRed),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _submitted
              ? (strOrNull(d['successSubtitle']) ?? 'Our Puja Seva team will reach out within 30 minutes to assist you.')
              : (strOrNull(d['subtitle']) ??
                  'Get a free 1-on-1 consultation with our spiritual experts to find the perfect puja for your needs.'),
          textAlign: TextAlign.center,
          style: AppText.body(size: 16, color: AppColors.mutedForeground),
        ),
        if (!_submitted) ...[
          const SizedBox(height: 16),
          LabeledField(
            label: 'Your Name',
            labelStyle: AppText.body(size: 14, weight: FontWeight.w500),
            child: AppTextField(controller: _name, hint: 'Enter your name', borderColor: AppColors.primary.o(.1)),
          ),
          const SizedBox(height: 16),
          LabeledField(
            label: 'Phone Number',
            labelStyle: AppText.body(size: 14, weight: FontWeight.w500),
            child: AppTextField(
              controller: _phone,
              hint: '+91 98699 XXXXX',
              keyboardType: TextInputType.phone,
              borderColor: AppColors.primary.o(.1),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: AppText.body(size: 12, weight: FontWeight.w500, color: AppColors.destructive)),
          ],
          const SizedBox(height: 16),
          AppButton(
            size: BtnSize.lg,
            expand: true,
            background: AppColors.bluntRed,
            loading: _loading,
            icon: _loading ? null : LucideIcons.phone,
            label: _loading ? 'Submitting...' : (strOrNull(d['buttonText']) ?? 'Request Free Callback'),
            onPressed: _loading ? null : _submit,
          ),
          const SizedBox(height: 16),
          Text(
            (strOrNull(d['footerText']) ?? 'No spam • Free consultation • Expert advice').toUpperCase(),
            textAlign: TextAlign.center,
            style: AppText.body(size: 10, color: AppColors.mutedForeground, letterSpacing: .5),
          ),
        ] else ...[
          const SizedBox(height: 24),
          Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(color: AppColors.green50, shape: BoxShape.circle),
              child: const Icon(LucideIcons.phone, size: 32, color: AppColors.green600),
            ),
          ),
          const SizedBox(height: 16),
          Text('Thank you for reaching out!',
              textAlign: TextAlign.center, style: AppText.body(weight: FontWeight.w500, color: AppColors.mutedForeground)),
          const SizedBox(height: 16),
          AppButton(
            variant: BtnVariant.outline,
            expand: true,
            label: 'Continue Browsing',
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}
