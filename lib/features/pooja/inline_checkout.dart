import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api/api_client.dart';
import '../../core/api/bmp_api.dart';
import '../../core/config.dart';
import '../../core/constants.dart';
import '../../core/storage/cookies.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/json.dart';
import '../../core/utils/launch.dart';
import '../../core/utils/nav.dart';
import '../../core/utils/razorpay.dart';
import '../../core/widgets/site_image.dart';
import '../../core/widgets/toast.dart';
import '../address/address_widgets.dart';
import '../booking/booking_success.dart';

const _maroon = Color(0xFF7B1520);
const _maroonHover = Color(0xFF9B1F2F);

/// components/bookingComponent/InlineCheckout.jsx — the 3-step booking
/// sheet (Schedule → Details → Payment) opened by a package's "Book Now".
Future<void> openInlineCheckout(
  BuildContext context, {
  required Json bookingPackage,
  required Json poojaData,
  required String selectedLocation,
  required String selectedLanguage,
  String? selectedLocationId,
  String? selectedLanguageId,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: .6),
    builder: (ctx) => _InlineCheckout(
      bookingPackage: bookingPackage,
      poojaData: poojaData,
      selectedLocation: selectedLocation,
      selectedLanguage: selectedLanguage,
      selectedLocationId: selectedLocationId,
      selectedLanguageId: selectedLanguageId,
      parentContext: context,
    ),
  );
}

class _InlineCheckout extends StatefulWidget {
  const _InlineCheckout({
    required this.bookingPackage,
    required this.poojaData,
    required this.selectedLocation,
    required this.selectedLanguage,
    required this.parentContext,
    this.selectedLocationId,
    this.selectedLanguageId,
  });

  final Json bookingPackage;
  final Json poojaData;
  final String selectedLocation;
  final String selectedLanguage;
  final String? selectedLocationId;
  final String? selectedLanguageId;
  final BuildContext parentContext;

  @override
  State<_InlineCheckout> createState() => _InlineCheckoutState();
}

class _InlineCheckoutState extends State<_InlineCheckout> {
  int _step = 1;
  bool _loading = false;

  // Step 1
  bool _bmpDate = false;
  DateTime? _selectedDay;
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  String _timeslot = timeSlotOptions[2];
  bool _showNotes = false;
  final _notes = TextEditingController();
  bool _showAllInclusions = false;
  bool _timeslotTouched = false;
  final _timeslotKey = GlobalKey();
  bool _restricted = false;
  List<String> _availableSlots = [];

  // Cart
  Json? _cart;
  bool _isEpooja = false;

  // Step 2
  Json _user = {};
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  bool _otpSent = false;
  bool _phoneVerified = false;
  List<Json> _addresses = [];
  Json? _pickedAddress;

  // Step 3
  final _coupon = TextEditingController();
  Json? _appliedCoupon;
  bool _couponLoading = false;
  String _payType = 'full';
  final _extraNotes = TextEditingController();

  String? get _token => Cookies.get('accessToken');
  ApiClient get _api => ApiClient.instance;
  Json get _pkg => obj(widget.bookingPackage['packageData']);

  @override
  void initState() {
    super.initState();
    for (final c in [_phone, _otp, _coupon]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_notes, _phone, _otp, _coupon, _extraNotes]) {
      c.dispose();
    }
    super.dispose();
  }

  String _ddmmyyyy(DateTime d) => DateFormat('dd-MM-yyyy').format(d);

  Future<Json?> _fetchCart(String cartId) async {
    final res = await _api.getAuth(AppConfig.api('/pooja-cart/$cartId'), _token);
    final d = obj(res.data);
    final body = objList(d['body']);
    if (intOf(d['statusCode']) == 200 && body.isNotEmpty) {
      setState(() {
        _cart = body.first;
        _isEpooja = str(body.first['location']) == ePoojaLocationId;
      });
      return body.first;
    }
    return null;
  }

  Future<Json?> _fetchUser() async {
    try {
      final res = await BmpApi.userDetails();
      final d = obj(res.data);
      if (intOf(d['statusCode']) == 200) {
        final u = obj(d['body']);
        setState(() {
          _user = u;
          _phoneVerified = str(u['phone']).isNotEmpty && boolOf(u['isPhoneVerified']);
        });
        return u;
      }
    } catch (_) {}
    return null;
  }

  Future<List<Json>> _fetchAddrs() async {
    try {
      final res = await BmpApi.userAddresses();
      final d = obj(res.data);
      _addresses = intOf(d['statusCode']) == 200 ? objList(d['body']) : [];
    } catch (_) {
      _addresses = [];
    }
    if (_addresses.isNotEmpty && _pickedAddress == null) {
      _pickedAddress = _addresses.first;
      _syncProfile(_addresses.first);
    }
    if (_addresses.isEmpty) _pickedAddress = null;
    if (mounted) setState(() {});
    return _addresses;
  }

  Future<void> _loadSlots() async {
    if (_bmpDate || _selectedDay == null || strOrNull(widget.poojaData['_id']) == null) {
      setState(() {
        _restricted = false;
        _availableSlots = [];
      });
      return;
    }
    final q = Uri(queryParameters: {
      'poojaId': str(widget.poojaData['_id']),
      'locationId': Cookies.get('location') ?? widget.selectedLocationId ?? '',
      'languageId': Cookies.get('language') ?? widget.selectedLanguageId ?? '',
      'date': _ddmmyyyy(_selectedDay!),
    }).query;
    try {
      final res = await BmpApi.availableSlots('?$q');
      final body = obj(obj(res.data)['body']);
      if (!mounted) return;
      setState(() {
        _restricted = boolOf(body['restricted']);
        _availableSlots = list(body['availableSlots']).map((e) => '$e').toList();
        if (_restricted && _timeslot.isNotEmpty && !_availableSlots.contains(_timeslot)) {
          _timeslot = '';
          _timeslotTouched = false;
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _restricted = false;
          _availableSlots = [];
        });
      }
    }
  }

  // ── Step 1 ────────────────────────────────────────────────────────────────
  Future<void> _step1Next() async {
    if (!_bmpDate && _selectedDay == null) {
      Toast.error('Please pick a date or let us choose one');
      return;
    }
    setState(() => _loading = true);
    try {
      final payload = {
        'poojaId': widget.bookingPackage['poojaId'],
        'packageId': widget.bookingPackage['packageId'],
        'packageType': widget.bookingPackage['packageType'],
        'location': Cookies.get('location') ?? widget.selectedLocationId,
        'language': Cookies.get('language') ?? widget.selectedLanguageId,
        'bmpChooseDate': _bmpDate,
        if (!_bmpDate && _selectedDay != null) 'date': _ddmmyyyy(_selectedDay!),
        if (!_bmpDate && _timeslot.isNotEmpty) 'timeslot': _timeslot,
        if (_notes.text.trim().isNotEmpty) 'timeSlotText': _notes.text.trim(),
      };
      Response res;
      try {
        res = await BmpApi.addToCart(payload, _token);
      } on DioException catch (e) {
        if (e.response?.statusCode == 401) {
          final ok = await _guestLogin();
          if (!ok) rethrow;
          res = await BmpApi.addToCart(payload, _token);
        } else {
          rethrow;
        }
      }
      final d = obj(res.data);
      if (intOf(d['statusCode']) == 200) {
        await _fetchCart(str(pick(d, ['body', '_id'])));
        await _fetchUser();
        await _fetchAddrs();
        setState(() => _step = 2);
      } else {
        Toast.error(strOrNull(d['message']) ?? 'Could not create booking');
      }
    } catch (e) {
      Toast.error(apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _guestLogin() async {
    try {
      final res = await BmpApi.guestLogin();
      final d = obj(res.data);
      if (res.statusCode == 201 && intOf(d['statusCode']) == 200) {
        Cookies.set('accessToken', str(pick(d, ['body', 'accessToken'])));
        return true;
      }
    } catch (_) {}
    Toast.error('Something went wrong -2');
    return false;
  }

  // ── Step 2 ────────────────────────────────────────────────────────────────
  Future<void> _sendOtp() async {
    if (_phone.text.length != 10) {
      Toast.error('Enter a valid 10-digit number');
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await BmpApi.sendPhoneOtp('+91-${_phone.text}');
      if (res.statusCode == 201) {
        setState(() => _otpSent = true);
        Toast.success('OTP sent!');
      } else {
        Toast.error('Failed to send OTP');
      }
    } catch (_) {
      Toast.error('Failed to send OTP');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _verifyOtp() async {
    setState(() => _loading = true);
    try {
      final res = await BmpApi.verifyPhoneOtp('+91-${_phone.text}', _otp.text, _token,
          cartId: strOrNull(_cart?['_id']), guestUserId: strOrNull(_user['_id']));
      final d = obj(res.data);
      if (intOf(d['statusCode']) == 200) {
        Cookies.set('accessToken', str(pick(d, ['body', 'accessToken'])));
        setState(() => _phoneVerified = true);
        await _fetchUser();
        await _fetchAddrs();
        Toast.success('Phone verified!');
      } else {
        Toast.error(strOrNull(d['message']) ?? 'Invalid OTP');
      }
    } catch (e) {
      Toast.error(apiErrorMessage(e, 'Invalid OTP'));
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _syncProfile(Json? address) async {
    if (address == null) return;
    final needsName = str(_user['userName']).isEmpty && str(address['name']).isNotEmpty;
    final needsEmail = str(_user['email']).isEmpty && str(address['email']).isNotEmpty;
    if (!needsName && !needsEmail) return;
    try {
      final res = await BmpApi.updateUser({
        if (needsName) 'userName': address['name'],
        if (needsEmail) 'email': address['email'],
      });
      if (intOf(obj(res.data)['statusCode']) == 200) await _fetchUser();
    } catch (_) {}
  }

  Future<void> _addAddress(Json data) async {
    await _syncProfile(data);
    final editId = strOrNull(data['editAddressId']);
    if (editId != null) {
      await BmpApi.updateAddress(editId, data);
    } else {
      await BmpApi.addAddress(data);
    }
    await _fetchAddrs();
    Toast.success('Address saved');
  }

  Future<void> _selectAddress(Json addr) async {
    if (_cart?['_id'] != null) {
      await BmpApi.updateCart(str(_cart!['_id']), {'addressId': addr['_id']}, _token);
    }
    await _syncProfile(addr);
    setState(() => _pickedAddress = addr);
  }

  Future<void> _openAddrFlow() async {
    final data = await openAddressFlow(context, userData: _user);
    if (data == null) return;
    await _addAddress(data);
    if (mounted) _openAddrList();
  }

  Future<void> _openAddrList() async {
    final picked = await openAddressListing(
      context,
      addresses: _addresses,
      fetchAddresses: _fetchAddrs,
      handleAddAddress: _addAddress,
      handleDeleteAddress: (id) async {
        await BmpApi.removeAddress(id);
        await _fetchAddrs();
      },
      userData: _user,
      defaultAddress: _pickedAddress,
    );
    if (picked != null) await _selectAddress(picked);
  }

  bool get _needsVerify => intOf(_user['userType']) == 3 && !_phoneVerified;

  void _step2Next() {
    if (_needsVerify) {
      Toast.error('Please verify your phone first');
      return;
    }
    if (!_isEpooja && _pickedAddress == null) {
      Toast.error('Please add a puja address');
      return;
    }
    setState(() => _step = 3);
  }

  // ── Coupon ──────────────────────────────────────────────────────────────────
  Future<void> _applyCoupon() async {
    if (_coupon.text.trim().isEmpty) {
      Toast.error('Enter a coupon code');
      return;
    }
    setState(() => _couponLoading = true);
    try {
      final v = await BmpApi.validateCoupon({'couponCode': _coupon.text.trim()}, _token);
      final vd = obj(v.data);
      if (intOf(vd['statusCode']) == 200) {
        final d = obj(vd['body']);
        final a = await BmpApi.applyCouponToCart(
          str(_cart?['_id']),
          {'couponId': d['_id'], 'couponType': d['couponType'], 'paymentMethodId': 'COUPON'},
          _token,
        );
        if (intOf(obj(a.data)['statusCode']) == 200) {
          setState(() => _appliedCoupon = d);
          await _fetchCart(str(_cart?['_id']));
          Toast.success('${str(d['amount'])}${intOf(d['couponType']) == 1 ? '%' : '₹'} discount applied!');
        } else {
          Toast.error('Could not apply coupon');
        }
      } else {
        Toast.error('Invalid coupon code');
      }
    } catch (_) {
      Toast.error('Invalid coupon code');
    } finally {
      if (mounted) setState(() => _couponLoading = false);
    }
  }

  Future<void> _removeCoupon() async {
    try {
      await BmpApi.removeCouponFromCart(
        str(_cart?['_id']),
        {'couponId': _appliedCoupon?['_id'], 'paymentMethodId': 'COUPON'},
        _token,
      );
    } catch (_) {}
    setState(() {
      _appliedCoupon = null;
      _coupon.clear();
    });
    await _fetchCart(str(_cart?['_id']));
    Toast.success('Coupon removed');
  }

  ({double base, double discount, double gst, double total}) get _amounts {
    final a = _cart?['amounts'];
    if (a is! Map) return (base: 0, discount: 0, gst: 0, total: 0);
    final o = obj(a[_payType == 'full' ? 'fullPayment' : 'partialPayment']);
    double r2(num v) => double.parse(v.toStringAsFixed(2));
    final base = r2(numOf(o['amount']));
    final discount = dbl(o['discount']);
    final gst = r2(numOf(o['gstAmount']));
    return (base: base, discount: discount, gst: gst, total: r2(base + gst));
  }

  String _money(num v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  // ── Place order ───────────────────────────────────────────────────────────────
  Future<void> _placeOrder() async {
    final cart = _cart;
    if (cart == null) return;
    setState(() => _loading = true);
    final amounts = _amounts;
    try {
      final o = await BmpApi.createPaymentOrder(
        receipt: '',
        cartId: str(cart['_id']),
        type: _payType,
        amount: amounts.total,
        extraDetailsByUser: _extraNotes.text,
        address: _pickedAddress?['_id'],
      );
      final od = obj(o.data);
      if (intOf(od['statusCode']) == 200) {
        final rzpOrderId = str(pick(od, ['body', 'initiatedRazorPayOrderId']));
        final orderId = str(pick(od, ['body', '_doc', '_id']));
        final paid = await displayRazorpay(amount: (amounts.total * 100).round(), razorpayOrderId: rzpOrderId, userData: _user);
        final v = await BmpApi.verifyPayment(
          razorPayPaymentId: paid.paymentId,
          razorPayOrderId: rzpOrderId,
          razorPaySignature: paid.signature,
          cartId: str(cart['_id']),
          orderId: orderId,
        );
        if (intOf(obj(v.data)['statusCode']) == 200) {
          Toast.success('Booking confirmed! 🙏');
          if (!mounted) return;
          Navigator.of(context).pop();
          if (!widget.parentContext.mounted) return;
          showBookingSuccess(widget.parentContext, orderId: orderId);
          return;
        }
        Toast.error('Payment verification failed. Please contact support.');
      } else {
        Toast.error(strOrNull(od['message']) ?? 'Order creation failed');
      }
    } on RazorpayFailure catch (e) {
      if (e.toast != null) Toast.error(e.toast!);
    } catch (_) {
      Toast.error('Payment failed. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── UI ──────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: mq.size.height * .95),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _header(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: switch (_step) {
                  1 => _step1(),
                  2 => _step2(),
                  _ => _step3(),
                },
              ),
            ),
            _footer(mq.padding.bottom),
          ]),
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: const BoxDecoration(gradient: LinearGradient(colors: [_maroon, Color(0xFFC0392B)])),
      child: Column(children: [
        Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .3), borderRadius: BorderRadius.circular(999))),
        const SizedBox(height: 16),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('SECURE BOOKING',
                  style: AppText.poppins(size: 10, weight: FontWeight.w700, color: Colors.white.withValues(alpha: .7), letterSpacing: 1)),
              const SizedBox(height: 4),
              Text(str(widget.poojaData['name']),
                  style: AppText.poppins(size: 16, weight: FontWeight.w700, color: Colors.white, height: 1.25)),
              const SizedBox(height: 2),
              Text('${_cap(str(widget.bookingPackage['packageType']))} Package',
                  style: AppText.poppins(size: 12, color: Colors.white.withValues(alpha: .75))),
            ]),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: .2), shape: BoxShape.circle),
              child: const Icon(LucideIcons.x, size: 15, color: Colors.white),
            ),
          ),
        ]),
        const SizedBox(height: 20),
        Row(children: [
          for (var i = 0; i < 3; i++) ...[
            Column(children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _step >= i + 1 ? Colors.white : Colors.white.withValues(alpha: .2),
                  border: _step == i + 1 ? Border.all(color: Colors.white.withValues(alpha: .4), width: 2) : null,
                ),
                child: _step > i + 1
                    ? const Icon(LucideIcons.check, size: 12, color: _maroon)
                    : Text('${i + 1}',
                        style: AppText.poppins(size: 12, weight: FontWeight.w700, color: _step >= i + 1 ? _maroon : Colors.white.withValues(alpha: .5))),
              ),
              const SizedBox(height: 4),
              Text(const ['Schedule', 'Details', 'Payment'][i],
                  style: AppText.poppins(size: 9, weight: FontWeight.w600, color: _step >= i + 1 ? Colors.white : Colors.white.withValues(alpha: .4))),
            ]),
            if (i < 2)
              Expanded(
                child: Container(
                  height: 1,
                  margin: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                  color: _step > i + 1 ? Colors.white : Colors.white.withValues(alpha: .25),
                ),
              ),
          ],
        ]),
      ]),
    );
  }

  String _cap(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  Widget _step1() {
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final highlightIcon = resolveSlotHighlightIcon(str(widget.poojaData['name']), widget.selectedLocation, widget.selectedLanguage);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      GestureDetector(
        onTap: () => setState(() {
          _bmpDate = !_bmpDate;
          if (_bmpDate) _selectedDay = null;
        }),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.amber50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: Row(children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: _bmpDate ? _maroon : Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: _bmpDate ? _maroon : AppColors.gray300, width: 2),
              ),
              child: _bmpDate ? const Icon(LucideIcons.check, size: 11, color: Colors.white) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Let us pick an auspicious date',
                    style: AppText.poppins(size: 14, weight: FontWeight.w600, color: const Color(0xFF78350F))),
                const SizedBox(height: 2),
                Text('Our team will call you to confirm the muhurat', style: AppText.poppins(size: 12, color: AppColors.amber600)),
              ]),
            ),
          ]),
        ),
      ),
      if (!_bmpDate) ...[
        const SizedBox(height: 16),
        _calendar(today),
      ],
      if (_selectedDay != null || _bmpDate) ...[
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.green50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFBBF7D0)),
          ),
          child: Row(children: [
            const Icon(LucideIcons.check, size: 13, color: AppColors.green700),
            const SizedBox(width: 8),
            Text(
              _bmpDate ? 'Our team will confirm the date' : DateFormat('EEEE, d MMMM yyyy').format(_selectedDay!),
              style: AppText.poppins(size: 12, weight: FontWeight.w600, color: AppColors.green700),
            ),
          ]),
        ),
      ],
      if (!_bmpDate) ...[
        const SizedBox(height: 16),
        Column(key: _timeslotKey, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Icon(LucideIcons.clock, size: 12, color: AppColors.gray600),
            const SizedBox(width: 6),
            Text('Preferred Time Slot', style: AppText.poppins(size: 12, weight: FontWeight.w700, color: AppColors.gray600)),
          ]),
          if (_restricted && _availableSlots.isEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFECDD3)),
              ),
              child: Text('This date is fully booked for the selected pooja. Please choose another date.',
                  style: AppText.poppins(size: 12, weight: FontWeight.w600, color: const Color(0xFFBE123C))),
            ),
          ],
          for (final g in const [
            ('Morning', LucideIcons.sunrise, Color(0xFFFB923C)),
            ('Afternoon', LucideIcons.sun, AppColors.amber500),
            ('Evening', LucideIcons.moon, Color(0xFF818CF8)),
          ]) ...[
            const SizedBox(height: 16),
            Row(children: [
              const SizedBox(width: 4),
              Icon(g.$2, size: 13, color: g.$3),
              const SizedBox(width: 6),
              Text(g.$1.toUpperCase(), style: AppText.poppins(size: 10, weight: FontWeight.w700, color: AppColors.gray400, letterSpacing: .5)),
            ]),
            const SizedBox(height: 8),
            LayoutBuilder(builder: (ctx, c) {
              final cols = MediaQuery.sizeOf(ctx).width >= 425 ? 3 : 2;
              final w = (c.maxWidth - 8 * (cols - 1)) / cols;
              return Wrap(spacing: 8, runSpacing: 8, children: [
                for (final opt in timeSlotOptions.where((s) => s.startsWith(g.$1)))
                  SizedBox(width: w, child: _slotButton(opt, g.$1, highlightIcon)),
              ]);
            }),
          ],
        ]),
      ],
      const SizedBox(height: 16),
      if (!_showNotes)
        Align(
          alignment: Alignment.centerLeft,
          child: GestureDetector(
            onTap: () => setState(() => _showNotes = true),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(LucideIcons.plus, size: 12, color: _maroon),
              const SizedBox(width: 4),
              Text('Add special instructions (muhurat / nakshatra)',
                  style: AppText.poppins(size: 12, weight: FontWeight.w600, color: _maroon)),
            ]),
          ),
        )
      else
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text('Special Instructions', style: AppText.poppins(size: 12, weight: FontWeight.w700, color: AppColors.gray600))),
            GestureDetector(
              onTap: () => setState(() {
                _showNotes = false;
                _notes.clear();
              }),
              child: Text('Remove', style: AppText.poppins(size: 10, color: AppColors.gray400)),
            ),
          ]),
          const SizedBox(height: 6),
          _textArea(_notes, 'e.g. Rashi, Nakshatra, or a specific muhurat preference...', autofocus: true),
        ]),
    ]);
  }

  Widget _slotButton(String opt, String group, String? highlightIcon) {
    final selected = _timeslot == opt;
    final disabled = _restricted && !_availableSlots.contains(opt);
    final highlighted = highlightIcon != null && _restricted && !disabled;
    final label = opt.replaceFirst('$group ', '').replaceAll('(', '').replaceAll(')', '');
    final (bg, border, fg) = disabled
        ? (AppColors.gray50, AppColors.gray100, AppColors.gray300)
        : selected
            ? (_maroon, _maroon, Colors.white)
            : highlighted
                ? (AppColors.amber50, AppColors.amber400, AppColors.amber800)
                : (Colors.white, AppColors.gray100, AppColors.gray600);
    return GestureDetector(
      onTap: disabled
          ? null
          : () => setState(() {
                _timeslot = opt;
                _timeslotTouched = true;
              }),
      child: AnimatedScale(
        scale: selected ? 1.02 : 1,
        duration: const Duration(milliseconds: 150),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border),
            boxShadow: highlighted ? const [BoxShadow(color: Color(0x73F59E0B), blurRadius: 10)] : null,
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (highlighted) ...[
              SiteImage(highlightIcon, width: 14, height: 14, placeholderColor: Colors.transparent),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: AppText.poppins(size: 11, weight: FontWeight.w600, color: fg)
                    .copyWith(decoration: disabled ? TextDecoration.lineThrough : null, decorationColor: fg),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _calendar(DateTime today) {
    final first = _month;
    final isThisMonth = first.year == today.year && first.month == today.month;
    final start = first.subtract(Duration(days: first.weekday % 7));
    final lastDay = DateTime(first.year, first.month + 1, 0);
    final end = lastDay.add(Duration(days: 6 - lastDay.weekday % 7));
    final days = <DateTime>[];
    for (var d = start; !d.isAfter(end); d = DateTime(d.year, d.month, d.day + 1)) {
      days.add(d);
    }
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.gray100)),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(color: AppColors.gray50, border: Border(bottom: BorderSide(color: AppColors.gray100))),
          child: Row(children: [
            Expanded(child: Text(DateFormat('MMMM yyyy').format(first), style: AppText.poppins(size: 14, weight: FontWeight.w700, color: AppColors.gray800))),
            _navBtn(LucideIcons.chevronLeft, isThisMonth ? null : () => setState(() => _month = DateTime(first.year, first.month - 1))),
            const SizedBox(width: 4),
            _navBtn(LucideIcons.chevronRight, () => setState(() => _month = DateTime(first.year, first.month + 1))),
          ]),
        ),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
          child: Column(children: [
            Row(children: [
              for (final d in const ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(d,
                        textAlign: TextAlign.center,
                        style: AppText.poppins(size: 10, weight: FontWeight.w700, color: d == 'Su' ? const Color(0xFFFB7185) : AppColors.gray400)),
                  ),
                ),
            ]),
            for (var w = 0; w < days.length; w += 7)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(children: [
                  for (final day in days.sublist(w, w + 7)) Expanded(child: _dayCell(day, first, today)),
                ]),
              ),
          ]),
        ),
      ]),
    );
  }

  Widget _navBtn(IconData icon, VoidCallback? onTap) => Opacity(
        opacity: onTap == null ? .3 : 1,
        child: GestureDetector(
          onTap: onTap,
          child: SizedBox(width: 28, height: 28, child: Icon(icon, size: 15, color: AppColors.gray500)),
        ),
      );

  Widget _dayCell(DateTime day, DateTime first, DateTime today) {
    if (day.month != first.month) return const SizedBox(height: 36);
    final past = day.isBefore(today);
    final selected = _selectedDay != null && day == _selectedDay;
    final isToday = day == today;
    final soon = day.isAfter(today) && day.isBefore(today.add(const Duration(days: 3)));
    Color fg = AppColors.gray700;
    Color? bg;
    Border? border;
    if (past) fg = AppColors.gray300;
    if (soon && !selected && !isToday) fg = AppColors.amber600;
    if (isToday && !selected) {
      bg = const Color(0xFFFFF1F2);
      fg = _maroon;
      border = Border.all(color: _maroon.withValues(alpha: .3));
    }
    if (selected) {
      bg = _maroon;
      fg = Colors.white;
    }
    return GestureDetector(
      onTap: past
          ? null
          : () {
              setState(() {
                _selectedDay = selected ? null : day;
                _timeslotTouched = false;
              });
              _loadSlots();
            },
      child: AnimatedScale(
        scale: selected ? 1.05 : 1,
        duration: const Duration(milliseconds: 150),
        child: Container(
          height: 36,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: border,
            boxShadow: selected ? const [BoxShadow(color: Color(0x1A000000), blurRadius: 6, offset: Offset(0, 4))] : null,
          ),
          child: Text('${day.day}',
              style: AppText.poppins(size: 12, weight: selected ? FontWeight.w700 : FontWeight.w500, color: fg)),
        ),
      ),
    );
  }

  Widget _textArea(TextEditingController c, String hint, {bool autofocus = false}) => TextField(
        controller: c,
        autofocus: autofocus,
        minLines: 2,
        maxLines: 2,
        style: AppText.poppins(size: 14, color: AppColors.gray700),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppText.poppins(size: 14, color: AppColors.gray400),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.gray200)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _maroon)),
        ),
      );

  Widget _step2() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (_needsVerify)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF1F2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _maroon.withValues(alpha: .15)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: _maroon.withValues(alpha: .1), shape: BoxShape.circle),
                child: const Icon(LucideIcons.shield, size: 16, color: _maroon),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Verify your phone', style: AppText.poppins(size: 14, weight: FontWeight.w700, color: AppColors.gray800)),
                  const SizedBox(height: 2),
                  Text('One-time verification for secure booking', style: AppText.poppins(size: 12, color: AppColors.gray500)),
                ]),
              ),
            ]),
            const SizedBox(height: 16),
            if (!_otpSent)
              Row(children: [
                Expanded(
                  child: Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.gray200),
                    ),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: const BoxDecoration(border: Border(right: BorderSide(color: AppColors.gray100))),
                        child: Text('+91', style: AppText.poppins(size: 14, weight: FontWeight.w700, color: AppColors.gray500)),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _phone,
                          keyboardType: TextInputType.phone,
                          maxLength: 10,
                          onChanged: (v) {
                            final dgt = v.replaceAll(RegExp(r'\D'), '');
                            if (dgt != v) _phone.text = dgt;
                          },
                          style: AppText.poppins(size: 14),
                          decoration: _plainInput('10-digit mobile'),
                        ),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(width: 8),
                _maroonButton(_loading ? '...' : 'Send OTP', _loading || _phone.text.length != 10 ? null : _sendOtp, height: 46),
              ])
            else
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
                  const Icon(LucideIcons.check, size: 11, color: AppColors.green600),
                  const SizedBox(width: 6),
                  Text('OTP sent to +91-${_phone.text}', style: AppText.poppins(size: 12, color: AppColors.gray500)),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => setState(() => _otpSent = false),
                    child: Text('Change',
                        style: AppText.poppins(size: 12, weight: FontWeight.w600, color: _maroon).copyWith(decoration: TextDecoration.underline)),
                  ),
                ]),
                const SizedBox(height: 12),
                TextField(
                  controller: _otp,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: AppText.poppins(size: 24, weight: FontWeight.w900, color: _maroon, letterSpacing: 14),
                  decoration: InputDecoration(
                    hintText: 'Enter OTP',
                    counterText: '',
                    hintStyle: AppText.poppins(size: 24, weight: FontWeight.w900, color: AppColors.gray300, letterSpacing: 4),
                    filled: true,
                    fillColor: Colors.white,
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _maroon.withValues(alpha: .3), width: 2)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _maroon, width: 2)),
                  ),
                ),
                const SizedBox(height: 12),
                _maroonButton(_loading ? 'Verifying...' : 'Verify & Continue', _loading || _otp.text.length < 4 ? null : _verifyOtp, height: 50),
              ]),
          ]),
        )
      else
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.green50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFBBF7D0)),
          ),
          child: Row(children: [
            Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(color: AppColors.green500, shape: BoxShape.circle),
              child: const Icon(LucideIcons.check, size: 11, color: Colors.white),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Phone verified — ${str(_user['phone'])}',
                  style: AppText.poppins(size: 12, weight: FontWeight.w600, color: AppColors.green700)),
            ),
          ]),
        ),
      if (!_needsVerify) ...[
        const SizedBox(height: 20),
        Row(children: [
          const Icon(LucideIcons.mapPin, size: 14, color: _maroon),
          const SizedBox(width: 6),
          Expanded(
            child: Text(_isEpooja ? 'Billing Address' : 'Puja Address',
                style: AppText.poppins(size: 14, weight: FontWeight.w700, color: AppColors.gray800)),
          ),
          GestureDetector(
            onTap: () => _addresses.isNotEmpty ? _openAddrList() : _openAddrFlow(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), border: Border.all(color: _maroon.withValues(alpha: .3))),
              child: Text(_pickedAddress != null ? 'Change' : '+ Add',
                  style: AppText.poppins(size: 12, weight: FontWeight.w700, color: _maroon)),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        if (_pickedAddress != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _maroon.withValues(alpha: .2), width: 2),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(str(_pickedAddress!['name']), style: AppText.poppins(size: 14, weight: FontWeight.w700, color: AppColors.gray800)),
              const SizedBox(height: 6),
              Text(
                '${str(_pickedAddress!['areaLocation'])}${strOrNull(_pickedAddress!['landmark']) != null ? ', ${str(_pickedAddress!['landmark'])}' : ''}\n'
                '${str(_pickedAddress!['city'])}, ${str(_pickedAddress!['state'])} — ${str(_pickedAddress!['pincode'])}\n'
                '📞 ${str(_pickedAddress!['phoneNumber'])}',
                style: AppText.poppins(size: 12, color: AppColors.gray500, height: 20 / 12),
              ),
            ]),
          )
        else
          GestureDetector(
            onTap: _openAddrFlow,
            child: CustomPaint(
              painter: _DashPainter(_maroon.withValues(alpha: .3)),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(LucideIcons.plus, size: 15, color: _maroon),
                  const SizedBox(width: 8),
                  Text('Add ${_isEpooja ? 'Billing' : 'Puja'} Address',
                      style: AppText.poppins(size: 14, weight: FontWeight.w700, color: _maroon)),
                ]),
              ),
            ),
          ),
      ],
    ]);
  }

  InputDecoration _plainInput(String hint) => InputDecoration(
        hintText: hint,
        counterText: '',
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        hintStyle: AppText.poppins(size: 14, color: AppColors.gray400),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      );

  Widget _step3() {
    final a = _amounts;
    final cartAmounts = obj(_cart?['amounts']);
    final partial = obj(cartAmounts['partialPayment']);
    final partialNow = (numOf(partial['amount']) + numOf(partial['gstAmount'])).toStringAsFixed(2);
    final inclusions = objList(_pkg['inclusions']).where((i) => i['present'] != false).toList();
    final pandits = intOf(_pkg['numberOfPandits']);
    final daysN = intOf(_pkg['numberOfDays']);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFFF1F2), AppColors.orange50]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFFE4E6)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('BOOKING SUMMARY', style: AppText.poppins(size: 10, weight: FontWeight.w900, color: AppColors.gray400, letterSpacing: 1)),
          const SizedBox(height: 8),
          Text(str(widget.poojaData['name']), style: AppText.poppins(size: 14, weight: FontWeight.w700, color: AppColors.gray800)),
          const SizedBox(height: 4),
          Wrap(spacing: 12, runSpacing: 4, children: [
            if (!_bmpDate && _selectedDay != null)
              _iconText(LucideIcons.calendar, DateFormat('d MMM yyyy').format(_selectedDay!)),
            if (!_bmpDate) _iconText(LucideIcons.clock, _timeslot),
            if (_bmpDate) Text('Date to be confirmed', style: AppText.poppins(size: 12, weight: FontWeight.w600, color: AppColors.amber600)),
          ]),
          if (pandits > 0 || daysN > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.only(top: 8),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0x80FFE4E6)))),
              child: Wrap(spacing: 16, runSpacing: 4, children: [
                if (pandits > 0) _dotStat('$pandits', pandits > 1 ? 'Pandits' : 'Pandit'),
                if (daysN > 0) _dotStat('$daysN', daysN > 1 ? 'Days' : 'Day'),
              ]),
            ),
          ],
          if (inclusions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
              for (final inc in inclusions.take(_showAllInclusions ? inclusions.length : 4))
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .8),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0x99FFE4E6)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(LucideIcons.check, size: 8, color: AppColors.green500),
                    const SizedBox(width: 4),
                    Text(str(inc['name']), style: AppText.poppins(size: 9, color: AppColors.gray600)),
                  ]),
                ),
              if (inclusions.length > 4)
                GestureDetector(
                  onTap: () => setState(() => _showAllInclusions = !_showAllInclusions),
                  child: Text(_showAllInclusions ? 'show less' : '+${inclusions.length - 4} more',
                      style: AppText.poppins(size: 9, weight: FontWeight.w500, color: const Color(0xFFF43F5E))),
                ),
            ]),
          ],
          if (_pickedAddress != null) ...[
            const SizedBox(height: 10),
            _iconText(LucideIcons.mapPin, '${str(_pickedAddress!['areaLocation'])}, ${str(_pickedAddress!['city'])}'),
          ],
        ]),
      ),
      if (!_isEpooja && cartAmounts['isPartialPaymentAllowed'] != false) ...[
        const SizedBox(height: 16),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _payOption('full', 'Full Payment', 'Pay everything now')),
          const SizedBox(width: 8),
          Expanded(
            child: _payOption('partial', 'Partial Pay',
                'Pay only ₹${_trimZeros(partialNow)} now. Remaining Payment after the puja completion'),
          ),
        ]),
      ],
      const SizedBox(height: 16),
      Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.gray100)),
        child: Column(children: [
          Container(
            color: AppColors.gray50,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(children: [
              _amountRow('Cart Amount', '₹${_money(a.base)}'),
              if (a.discount > 0) ...[
                const SizedBox(height: 8),
                _amountRow('Discount', '- ₹${_money(a.discount)}', green: true),
              ],
              const SizedBox(height: 8),
              _amountRow('GST', '₹${_money(a.gst)}'),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: AppColors.gray100))),
            child: Row(children: [
              Expanded(child: Text('Total Payable', style: AppText.poppins(size: 14, weight: FontWeight.w700, color: AppColors.gray800))),
              Text('₹${_money(a.total)}', style: AppText.poppins(size: 20, weight: FontWeight.w900, color: _maroon)),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 16),
      if (_appliedCoupon == null)
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Icon(LucideIcons.tag, size: 11, color: AppColors.gray600),
            const SizedBox(width: 6),
            Expanded(child: Text('Coupon Code', style: AppText.poppins(size: 12, weight: FontWeight.w700, color: AppColors.gray600))),
            Text('(Not applicable on partial pay)', style: AppText.poppins(size: 9, color: const Color(0xCCF43F5E))),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _coupon,
                enabled: _payType != 'partial',
                textCapitalization: TextCapitalization.characters,
                onChanged: (v) {
                  final up = v.toUpperCase();
                  if (up != v) _coupon.value = _coupon.value.copyWith(text: up);
                },
                style: AppText.sans(size: 14, weight: FontWeight.w700, letterSpacing: 1.5),
                decoration: InputDecoration(
                  hintText: _payType == 'partial' ? 'COUPONS DISABLED' : 'ENTER CODE',
                  hintStyle: AppText.poppins(size: 14, color: AppColors.gray400),
                  filled: true,
                  fillColor: _payType == 'partial' ? AppColors.gray50 : Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.gray200)),
                  disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.gray100)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _maroon)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _maroonButton(_couponLoading ? '...' : 'Apply',
                _couponLoading || _coupon.text.trim().isEmpty || _payType == 'partial' ? null : _applyCoupon,
                height: 46),
          ]),
        ])
      else
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.green50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFBBF7D0)),
          ),
          child: Row(children: [
            Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(color: AppColors.green500, shape: BoxShape.circle),
              child: const Icon(LucideIcons.check, size: 12, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(str(_appliedCoupon!['couponCode']), style: AppText.poppins(size: 12, weight: FontWeight.w700, color: const Color(0xFF166534))),
                Text('${str(_appliedCoupon!['amount'])}${intOf(_appliedCoupon!['couponType']) == 1 ? '%' : '₹'} discount applied',
                    style: AppText.poppins(size: 12, color: AppColors.green600)),
              ]),
            ),
            GestureDetector(
              onTap: _removeCoupon,
              child: Text('Remove', style: AppText.poppins(size: 12, weight: FontWeight.w700, color: AppColors.red500)),
            ),
          ]),
        ),
      const SizedBox(height: 16),
      Text.rich(
        TextSpan(children: [
          const TextSpan(text: 'Additional Notes '),
          TextSpan(text: '(optional)', style: AppText.poppins(size: 12, color: AppColors.gray400)),
        ]),
        style: AppText.poppins(size: 12, weight: FontWeight.w700, color: AppColors.gray600),
      ),
      const SizedBox(height: 6),
      _textArea(_extraNotes, 'Any special instructions for the pandit...'),
      const SizedBox(height: 16),
      Text.rich(
        TextSpan(children: [
          const TextSpan(text: 'By placing this order you agree to our '),
          WidgetSpan(child: _link('T&C', '/terms-and-conditions')),
          const TextSpan(text: ' and '),
          WidgetSpan(child: _link('Privacy Policy', '/privacy-policy')),
        ]),
        textAlign: TextAlign.center,
        style: AppText.poppins(size: 10, color: AppColors.gray400, height: 1.6),
      ),
    ]);
  }

  String _trimZeros(String s) => s.contains('.') ? s.replaceAll(RegExp(r'\.?0+$'), '') : s;

  Widget _link(String t, String href) => GestureDetector(
        onTap: () => goHref(widget.parentContext, href),
        child: Text(t, style: AppText.poppins(size: 10, color: _maroon).copyWith(decoration: TextDecoration.underline)),
      );

  Widget _iconText(IconData i, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(i, size: 10, color: AppColors.gray500),
        const SizedBox(width: 4),
        Flexible(child: Text(t, style: AppText.poppins(size: 12, color: AppColors.gray500))),
      ]);

  Widget _dotStat(String n, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 4, height: 4, decoration: const BoxDecoration(color: Color(0xFFFB7185), shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text.rich(
          TextSpan(children: [
            TextSpan(text: n, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.gray700)),
            TextSpan(text: ' $label'),
          ]),
          style: AppText.poppins(size: 10, color: AppColors.gray500),
        ),
      ]);

  Widget _payOption(String val, String title, String sub) {
    final sel = _payType == val;
    return GestureDetector(
      onTap: () {
        setState(() => _payType = val);
        if (val == 'partial' && _appliedCoupon != null) _removeCoupon();
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: sel ? const Color(0xFFFFF1F2) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: sel ? _maroon : AppColors.gray100, width: 2),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: sel ? _maroon : null,
              border: Border.all(color: sel ? _maroon : AppColors.gray300, width: 2),
            ),
            alignment: Alignment.center,
            child: sel ? Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)) : null,
          ),
          const SizedBox(height: 8),
          Text(title, style: AppText.poppins(size: 12, weight: FontWeight.w700, color: sel ? _maroon : AppColors.gray700)),
          const SizedBox(height: 2),
          Text(sub, style: AppText.poppins(size: 10, color: AppColors.gray400, height: 1.25)),
        ]),
      ),
    );
  }

  Widget _amountRow(String l, String v, {bool green = false}) => Row(children: [
        Expanded(
          child: Text(l,
              style: AppText.poppins(size: 12, color: green ? AppColors.green600 : AppColors.gray500, weight: green ? FontWeight.w600 : FontWeight.w400)),
        ),
        Text(v, style: AppText.poppins(size: 12, weight: FontWeight.w600, color: green ? AppColors.green600 : AppColors.gray700)),
      ]);

  Widget _maroonButton(String label, VoidCallback? onTap, {double height = 52, double radius = 12, bool expand = false}) => Opacity(
        opacity: onTap == null ? .4 : 1,
        child: Material(
          color: _maroon,
          borderRadius: BorderRadius.circular(radius),
          child: InkWell(
            borderRadius: BorderRadius.circular(radius),
            splashColor: _maroonHover,
            onTap: onTap,
            child: Container(
              height: height,
              width: expand ? double.infinity : null,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              child: Text(label, style: AppText.poppins(size: 14, weight: FontWeight.w700, color: Colors.white)),
            ),
          ),
        ),
      );

  Widget _footer(double bottomInset) {
    final slotPending = _selectedDay != null && !_timeslotTouched && !_bmpDate;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: AppColors.gray100))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (_step == 1)
          _maroonButton(
            _loading
                ? 'Setting up your booking…'
                : slotPending
                    ? 'Select Time Slot ↓'
                    : 'Continue to Details →',
            _loading || (_selectedDay == null && !_bmpDate)
                ? null
                : () {
                    if (slotPending) {
                      final ctx = _timeslotKey.currentContext;
                      if (ctx != null) Scrollable.ensureVisible(ctx, alignment: .5, duration: const Duration(milliseconds: 400));
                      setState(() => _timeslotTouched = true);
                    } else {
                      _step1Next();
                    }
                  },
            height: 52,
            radius: 16,
            expand: true,
          ),
        if (_step == 2)
          Row(children: [
            GestureDetector(
              onTap: () => setState(() => _step = 1),
              child: Container(
                width: 44,
                height: 48,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.gray200)),
                child: const Icon(LucideIcons.chevronLeft, size: 18, color: AppColors.gray500),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _maroonButton('Review Payment →', _needsVerify || (!_isEpooja && _pickedAddress == null) ? null : _step2Next,
                  height: 50, radius: 16, expand: true),
            ),
          ]),
        if (_step == 3) ...[
          _maroonButton(_loading ? 'Processing…' : '🙏 Place Order — ₹${_money(_amounts.total)}', _loading ? null : _placeOrder,
              height: 52, radius: 16, expand: true),
          GestureDetector(
            onTap: () => setState(() => _step = 2),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text('← Back', style: AppText.poppins(size: 12, color: AppColors.gray400)),
            ),
          ),
        ],
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () => callPhone('+919869929292'),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(LucideIcons.phone, size: 11, color: AppColors.gray400),
            const SizedBox(width: 6),
            Text('Need help? Call us', style: AppText.poppins(size: 12, color: AppColors.gray400)),
          ]),
        ),
      ]),
    );
  }
}

class _DashPainter extends CustomPainter {
  _DashPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(16)));
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final m in path.computeMetrics()) {
      for (double d = 0; d < m.length; d += 9) {
        canvas.drawPath(m.extractPath(d, d + 5), p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashPainter old) => old.color != color;
}
