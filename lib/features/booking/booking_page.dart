import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api/bmp_api.dart';
import '../../core/constants.dart';
import '../../core/state/app_state.dart';
import '../../core/storage/cookies.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/json.dart';
import '../../core/widgets/fieldset.dart';
import '../../core/widgets/site/site_page.dart';
import '../../core/widgets/toast.dart';
import '../../core/widgets/form_fields.dart';

/// pages/booking/index.jsx — legacy calendar + time slot step. Reached from
/// order rescheduling (`?reschedule=true&orderId=…`) and cart edits
/// (`?cartId=…`), with the pooja/package in the query string.
class BookingPage extends ConsumerStatefulWidget {
  const BookingPage({super.key, required this.query});
  final Map<String, String> query;

  @override
  ConsumerState<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends ConsumerState<BookingPage> {
  bool _showBookingForm = false;
  bool _bmpChooseDate = false;
  String _rasi = '';
  String _timeSlotText = '';

  bool get _isReschedule => widget.query['reschedule'] == 'true';

  Future<Response> _withGuestRetry(Future<Response> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 && await guestLogin(ref)) return call();
      return e.response ?? Response(requestOptions: e.requestOptions, statusCode: 500, data: {'message': 'Something went wrong'});
    }
  }

  Future<void> _proceed(Map<String, dynamic> q) async {
    final query = Map<String, dynamic>.of(q);
    final date = query['date'];
    if (date is DateTime) query['date'] = DateFormat('dd-MM-yyyy').format(date);
    if (_rasi.isNotEmpty && _rasi != 'skip') query['extraDetails'] = _rasi;
    if (_timeSlotText.isNotEmpty) query['timeSlotText'] = _timeSlotText;

    if (query['reschedule'] == 'true') {
      try {
        final r = await BmpApi.updateOrder(str(query['orderId']), {
          'rescheduledBookingDate': query['date'],
          'rescheduledBookingTimeSlot': query['timeslot'],
          'rescheduledTimeSlotText': _timeSlotText,
        });
        if (r.statusCode == 200 && intOf(obj(r.data)['statusCode']) == 200) {
          Toast.show('Order rescheduled successfully');
          if (mounted) context.push('/user/orders/${str(query['orderId'])}');
        } else {
          Toast.show('Something went wrong');
        }
      } catch (_) {}
      return;
    }

    final payload = {...query, 'location': Cookies.get('location'), 'language': Cookies.get('language')};
    final cartId = widget.query['cartId'];
    final res = await _withGuestRetry(() => cartId != null
        ? BmpApi.updateCart(cartId, payload, Cookies.get('accessToken'))
        : BmpApi.addToCart(payload, Cookies.get('accessToken')));
    if (!mounted) return;
    final d = obj(res.data);
    if (res.statusCode == 201 || res.statusCode == 200) {
      if (intOf(d['statusCode']) == 200) {
        if (cartId != null) {
          context.push('/booking/$cartId');
        } else {
          context.push('/booking/${str(pick(d, ['body', '_id']))}?bmpChooseDate=$_bmpChooseDate&custominput=$_rasi');
        }
      } else {
        Toast.show(str(d['message']));
      }
    } else {
      Toast.show('Something went wrong');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SitePage(children: [
      if (!_showBookingForm) ...[
        LegacyCalendar(
          proceedLabel: _isReschedule ? 'Reschedule' : 'PROCEED',
          onTimeSlotText: (v) => _timeSlotText = v,
          onProceed: (date, slot) => _proceed({...widget.query, 'date': date, 'timeslot': slot}),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(children: [
            const SizedBox(height: 16),
            Text('- Or -', style: AppText.poppins(size: 12, color: AppColors.defaultText, height: 20 / 12)),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => setState(() {
                _showBookingForm = true;
                _bmpChooseDate = true;
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.lightGrey)),
                child: Text('Let BookMyPooja team recommend auspicious date and time',
                    style: AppText.poppins(size: 12, color: AppColors.defaultText)),
              ),
            ),
          ]),
        ),
      ] else
        SizedBox(
          height: MediaQuery.sizeOf(context).height * .7,
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.lightGrey)),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const SizedBox(height: 44),
                TextField(
                  onChanged: (v) => setState(() => _rasi = v.trim().isEmpty ? '' : v),
                  style: AppText.poppins(size: 14),
                  decoration: InputDecoration(
                    hintText: 'Enter Rasi/Nakshatra of the Person/(Optional)',
                    hintStyle: AppText.poppins(size: 14, color: AppColors.gray400),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.gray300)),
                  ),
                ),
                const SizedBox(height: 36),
                Container(
                  padding: const EdgeInsets.only(top: 16),
                  decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.gray200))),
                  child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    _box('Skip', outlined: true, onTap: () {
                      setState(() => _rasi = '');
                      _proceed(widget.query);
                    }),
                    const SizedBox(width: 16),
                    _box('Send', onTap: () => _proceed(widget.query)),
                  ]),
                ),
              ]),
            ),
          ),
        ),
    ]);
  }

  Widget _box(String label, {required VoidCallback onTap, bool outlined = false}) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 128,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: outlined ? Colors.white : AppColors.bluntRed,
            borderRadius: BorderRadius.circular(8),
            border: outlined ? Border.all(color: AppColors.lightGrey) : null,
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              style: AppText.poppins(size: 14, weight: FontWeight.w500, color: outlined ? AppColors.defaultText : Colors.white)),
        ),
      );
}

/// bookingComponent/Calender.jsx + hours.jsx
class LegacyCalendar extends StatefulWidget {
  const LegacyCalendar({super.key, required this.onProceed, required this.proceedLabel, required this.onTimeSlotText});
  final void Function(DateTime? date, String slot) onProceed;
  final String proceedLabel;
  final ValueChanged<String> onTimeSlotText;

  @override
  State<LegacyCalendar> createState() => _LegacyCalendarState();
}

class _LegacyCalendarState extends State<LegacyCalendar> {
  late final DateTime _today = DateUtils.dateOnly(DateTime.now());
  late DateTime _month = DateTime(_today.year, _today.month);
  late DateTime? _selectedDay = _today;
  DateTime? _selectedDate;
  bool _touched = false;
  String? _time;

  @override
  Widget build(BuildContext context) {
    final first = _month;
    final isThisMonth = first.year == _today.year && first.month == _today.month;
    final start = first.subtract(Duration(days: first.weekday % 7));
    final lastDay = DateTime(first.year, first.month + 1, 0);
    final end = lastDay.add(Duration(days: 6 - lastDay.weekday % 7));
    final days = <DateTime>[for (var d = start; !d.isAfter(end); d = DateTime(d.year, d.month, d.day + 1)) d];

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(color: const Color(0xFFF5F7F9), borderRadius: BorderRadius.circular(8)),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.only(left: 10, right: 4),
                  child: Row(children: [
                    Expanded(
                      child: Text(DateFormat(' MMMM yyyy').format(first),
                          style: AppText.poppins(size: 14, weight: FontWeight.w500, color: AppColors.defaultText)),
                    ),
                    GestureDetector(
                      onTap: isThisMonth ? null : () => setState(() => _month = DateTime(first.year, first.month - 1)),
                      child: Icon(LucideIcons.chevronLeft, size: 28, color: AppColors.headerQuote.withValues(alpha: isThisMonth ? .5 : 1)),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: () => setState(() => _month = DateTime(first.year, first.month + 1)),
                      child: const Icon(LucideIcons.chevronRight, size: 28, color: AppColors.headerQuote),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),
                Row(children: [
                  for (final n in const ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'])
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(n,
                            textAlign: TextAlign.center,
                            style: AppText.poppins(
                                size: 16, weight: FontWeight.w500, color: n == 'Sun' ? AppColors.darkOrange : AppColors.defaultText)),
                      ),
                    ),
                ]),
                for (var w = 0; w < days.length; w += 7)
                  Row(children: [for (final d in days.sublist(w, w + 7)) Expanded(child: _day(d, first))]),
              ]),
            ),
            if (_touched)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  AppSelectField<String>(
                    value: _time,
                    placeholder: timeSlotOptions.first,
                    minHeight: 56,
                    radius: 8,
                    options: timeSlotOptions,
                    labelOf: (v) => v,
                    textStyle: AppText.poppins(size: 14, weight: FontWeight.w500, color: AppColors.defaultText),
                    onChanged: (v) => setState(() => _time = v),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    onChanged: widget.onTimeSlotText,
                    style: AppText.poppins(size: 14),
                    decoration: fieldsetDecoration(' Additional info on muhurat if any',
                        hint: 'Example : 08-10am', prefix: fieldsetIcon('/icons/slots.svg')),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: () => widget.onProceed(_selectedDate, _time ?? 'Morning (6 AM to 8 AM)'),
                      child: Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                        decoration: BoxDecoration(color: AppColors.bluntRed, borderRadius: BorderRadius.circular(8)),
                        child: Text(widget.proceedLabel, style: AppText.poppins(size: 14, color: Colors.white)),
                      ),
                    ),
                  ),
                ]),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _day(DateTime day, DateTime first) {
    final past = day.isBefore(_today);
    final selected = _selectedDay != null && day == _selectedDay;
    final isToday = day == _today;
    final soon = day.isAfter(_today) && day.isBefore(_today.add(const Duration(days: 3)));
    final inMonth = day.month == first.month;
    Color fg = past ? AppColors.lightGrey : AppColors.defaultText;
    Color? bg;
    Border? border;
    if (soon) {
      fg = AppColors.bluntRed;
      border = Border.all(color: AppColors.bluntRed);
      bg = AppColors.blue50;
    }
    if (isToday) {
      fg = AppColors.bluntRed;
      bg = AppColors.blue50;
    }
    if (selected && day.isAfter(_today.add(const Duration(days: 2)))) {
      bg = AppColors.bluntRed;
      fg = Colors.white;
    }
    if (selected && isToday) {
      bg = const Color(0x4DCBD5E1);
      fg = const Color(0xFFF87171);
    }
    if (selected && soon) {
      bg = Colors.white;
      fg = AppColors.bluntRed;
    }
    return Opacity(
      opacity: !inMonth && !selected && !isToday ? 0 : 1,
      child: GestureDetector(
        onTap: past || !inMonth
            ? null
            : () => setState(() {
                  if (selected) {
                    _touched = false;
                    _selectedDay = null;
                    _selectedDate = null;
                  } else {
                    _touched = true;
                    _selectedDay = day;
                    _selectedDate = day;
                    _time = null;
                  }
                }),
        child: Container(
          height: 48,
          alignment: Alignment.center,
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4), border: border),
            child: Text('${day.day}',
                style: AppText.poppins(size: 16, weight: selected || isToday ? FontWeight.w600 : FontWeight.w400, color: fg)),
          ),
        ),
      ),
    );
  }
}
