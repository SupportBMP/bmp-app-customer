import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/bmp_api.dart';
import '../../core/config.dart';
import '../../core/constants.dart';
import '../../core/storage/cookies.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/format.dart';
import '../../core/utils/json.dart';
import '../../core/utils/launch.dart';
import '../../core/utils/nav.dart';
import '../../core/utils/razorpay.dart';
import '../../core/widgets/fieldset.dart';
import '../../core/widgets/otp.dart';
import '../../core/widgets/site/site_page.dart';
import '../../core/widgets/site_image.dart';
import '../../core/widgets/toast.dart';
import '../address/address_widgets.dart';
import 'booking_success.dart';

/// pages/booking/[slug].jsx — cart checkout for a pooja cart item.
class CartCheckoutPage extends ConsumerStatefulWidget {
  const CartCheckoutPage({super.key, required this.cartId, this.bmpChooseDate = false});
  final String cartId;
  final bool bmpChooseDate;

  @override
  ConsumerState<CartCheckoutPage> createState() => _CartCheckoutPageState();
}

class _CartCheckoutPageState extends ConsumerState<CartCheckoutPage> {
  String _paymentType = 'full';
  List<Json> _addresses = [];
  Json _cart = {};
  Json? _appliedCoupon;
  Json _user = {};
  Json? _defaultAddress;
  bool _loading = false;
  bool _isEpooja = false;
  bool _isPhoneVerified = false;
  String _notes = '';
  String _phoneInput = '';

  String? get _token => Cookies.get('accessToken');

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _fetchAddresses();
    await _fetchUser();
    await _fetchCart();
  }

  Future<void> _fetchCart() async {
    if (_token == null) return;
    try {
      final res = await ApiClient.instance.getAuth(AppConfig.api('/pooja-cart/${widget.cartId}'), _token);
      final d = obj(res.data);
      final body = objList(d['body']);
      if (res.statusCode == 200 && intOf(d['statusCode']) == 200 && body.isNotEmpty) {
        final cart = body.first;
        final coupons = objList(cart['paymentMethods']).where((p) => str(p['paymentMethodId']) == 'COUPON').toList();
        Json? applied;
        if (coupons.isNotEmpty) {
          try {
            final c = await BmpApi.couponById(str(coupons.first['couponId']), _token);
            final cd = obj(c.data);
            if (c.statusCode == 200 && intOf(cd['statusCode']) == 200 && cd['body'] != null) applied = obj(cd['body']);
          } catch (_) {}
        }
        if (!mounted) return;
        setState(() {
          _cart = cart;
          _appliedCoupon = applied;
          _defaultAddress = _addresses.where((a) => str(a['_id']) == str(cart['addressId'])).firstOrNull ?? _addresses.firstOrNull;
          if (str(cart['location']) == ePoojaLocationId) _isEpooja = true;
          if (cart['amounts'] is Map && cart['amounts']['isPartialPaymentAllowed'] == false && _paymentType == 'partial') {
            _paymentType = 'full';
            Toast.show('⚠️ Partial payment is not allowed when a coupon is applied. Switched to Full Payment.');
          }
        });
      } else {
        if (mounted) context.go('/');
        Toast.error('Error Fetching Cart Item Response');
      }
    } catch (_) {
      Toast.error('Error fetching cart item:');
    }
  }

  Future<void> _fetchAddresses() async {
    try {
      final r = await BmpApi.userAddresses();
      final d = obj(r.data);
      _addresses = r.statusCode == 200 && intOf(d['statusCode']) == 200 ? objList(d['body']) : [];
    } catch (_) {
      _addresses = [];
    }
    if (mounted) {
      setState(() {
        if (_defaultAddress == null || _defaultAddress!.isEmpty) {
          _defaultAddress = _addresses.where((a) => str(a['_id']) == str(_cart['addressId'])).firstOrNull ?? _addresses.firstOrNull;
        }
      });
    }
  }

  Future<void> _fetchUser() async {
    try {
      final r = await BmpApi.userDetails();
      final d = obj(r.data);
      if (r.statusCode == 200 && intOf(d['statusCode']) == 200) {
        final u = obj(d['body']);
        setState(() {
          _user = u;
          _isPhoneVerified = str(u['phone']).isNotEmpty && boolOf(u['isPhoneVerified']);
        });
        if (!_isPhoneVerified && mounted) _openCompleteProfile();
      }
    } catch (_) {}
  }

  Future<void> _updateUser(Json data) async {
    try {
      final r = await BmpApi.updateUser(data);
      if (r.statusCode == 201 && intOf(obj(r.data)['statusCode']) == 200) {
        await _fetchUser();
      } else {
        Toast.error('Error updating user data 001');
      }
    } catch (_) {
      Toast.error('Error updating user data');
    }
  }

  Future<void> _handleAddAddress(Json data) async {
    try {
      final editId = strOrNull(data['editAddressId']);
      if (editId != null) {
        final r = await BmpApi.updateAddress(editId, data);
        if (r.statusCode != 200 || intOf(obj(r.data)['statusCode']) != 200) throw Exception('Update failed');
        Toast.success('Address updated successfully');
      } else {
        final updates = <String, dynamic>{
          if (str(_user['userName']).isEmpty && str(data['name']).isNotEmpty) 'userName': data['name'],
          if (str(_user['email']).isEmpty && str(data['email']).isNotEmpty) 'email': data['email'],
        };
        if (updates.isNotEmpty) await _updateUser(updates);
        await BmpApi.addAddress(data);
        Toast.success('Address added successfully');
      }
      await _fetchAddresses();
    } catch (_) {
      Toast.error('Something went wrong. Please try again.');
    }
  }

  Future<void> _openAddressModal() async {
    final data = await openAddressFlow(context, userData: _user);
    if (data == null) return;
    await _handleAddAddress(data);
    if (mounted) _openSelection();
  }

  Future<void> _openSelection() async {
    final picked = await openAddressListing(
      context,
      addresses: _addresses,
      fetchAddresses: () async {
        await _fetchAddresses();
        return _addresses;
      },
      handleAddAddress: _handleAddAddress,
      handleDeleteAddress: (id) async {
        try {
          final r = await BmpApi.removeAddress(id);
          if (r.statusCode != 200 || intOf(obj(r.data)['statusCode']) != 200) Toast.error('Something Went Wrong!');
        } catch (_) {}
        await _fetchAddresses();
      },
      userData: _user,
      defaultAddress: _defaultAddress,
    );
    if (picked == null) return;
    setState(() => _loading = true);
    await BmpApi.updateCart(str(_cart['_id']), {'addressId': str(picked['_id'])}, _token);
    await _fetchCart();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _sendOtp(String key, String value) async {
    try {
      final r = key == 'email' ? await BmpApi.sendEmailOtp(value) : await BmpApi.sendPhoneOtp(value);
      if (r.statusCode == 200) Toast.success('OTP sent successfully');
    } catch (_) {
      Toast.error('Error sending OTP');
    }
  }

  Future<void> _verifyOtp(String key, String value, String otp) async {
    try {
      final r = key == 'email'
          ? await BmpApi.verifyEmailOtp(value, otp, _token)
          : await BmpApi.verifyPhoneOtp('+91-$value', otp, _token, cartId: widget.cartId, guestUserId: strOrNull(_user['_id']));
      final d = obj(r.data);
      if (r.statusCode == 201 && intOf(d['statusCode']) == 200) {
        final body = obj(d['body']);
        if (key == 'phone') Cookies.set('accessToken', str(body['accessToken']));
        if (key == 'phone') setState(() => _isPhoneVerified = true);
        final u = obj(body['user']);
        if (intOf(u['userType']) == 0 && str(u['userName']).isNotEmpty) Toast.success('Welcome Back ${str(u['userName'])}');
        await _fetchUser();
        await _fetchAddresses();
        Toast.success('OTP verified successfully');
        if (mounted && key == 'phone') Navigator.of(context, rootNavigator: true).maybePop();
      } else {
        Toast.error(strOrNull(d['message']) ?? 'Error verifying OTP-2');
      }
    } catch (_) {
      Toast.error('Error verifying OTP 001');
    }
  }

  void _openCompleteProfile() {
    showDialog(
      context: context,
      barrierColor: const Color(0x80111827),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: AppColors.bluntRed)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.gray200))),
              child: Row(children: [
                Expanded(child: Text('Verify yourself first', style: AppText.poppins(size: 16, weight: FontWeight.w600))),
                GestureDetector(
                  onTap: () => Navigator.of(ctx).pop(),
                  child: const Text('✕', style: TextStyle(color: AppColors.bluntRed)),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              child: InputWithOtp(
                inputKey: 'phone',
                value: _phoneInput,
                onChanged: (v) => _phoneInput = v,
                sendOtp: _sendOtp,
                verifyOtp: _verifyOtp,
                isVerified: _isPhoneVerified,
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Future<bool> _applyCoupon(Json coupon) async {
    final r = await BmpApi.applyCouponToCart(
        widget.cartId, {'couponId': coupon['_id'], 'couponType': coupon['couponType'], 'paymentMethodId': 'COUPON'}, _token);
    if (r.statusCode == 201 && intOf(obj(r.data)['statusCode']) == 200) {
      await _fetchCart();
      Toast.success('Coupon Code Applied Successfully');
      return true;
    }
    return false;
  }

  Future<void> _removeCoupon() async {
    try {
      final r = await BmpApi.removeCouponFromCart(
          widget.cartId, {'couponId': _appliedCoupon?['_id'], 'paymentMethodId': 'COUPON'}, _token);
      if (r.statusCode == 201 && intOf(obj(r.data)['statusCode']) == 200) {
        await _fetchCart();
        Toast.success('Coupon Removed Successfully');
      }
    } catch (_) {}
    await _fetchCart();
  }

  Future<void> _placeOrder(String type, double amount) async {
    try {
      final r = await BmpApi.createPaymentOrder(
        receipt: '',
        cartId: str(_cart['_id']),
        type: type == 'fullPayment' ? 'full' : 'partial',
        amount: amount,
        extraDetailsByUser: _notes,
        address: _defaultAddress?['_id'],
      );
      final d = obj(r.data);
      if (r.statusCode == 201 && intOf(d['statusCode']) == 200) {
        final rzp = str(pick(d, ['body', 'initiatedRazorPayOrderId']));
        final orderId = str(pick(d, ['body', '_doc', '_id']));
        final paid = await displayRazorpay(amount: amount.toInt() * 100, razorpayOrderId: rzp);
        final v = await BmpApi.verifyPayment(
          razorPayPaymentId: paid.paymentId,
          razorPayOrderId: rzp,
          razorPaySignature: paid.signature,
          cartId: str(_cart['_id']),
          orderId: orderId,
        );
        if (v.statusCode == 201 && intOf(obj(v.data)['statusCode']) == 200) {
          Toast.show('Payment Verified Successfully');
          if (mounted) showBookingSuccess(context, orderId: orderId);
        } else {
          Toast.show('Error Placing Order');
        }
      } else {
        Toast.error('Error Placing Order');
      }
    } on RazorpayFailure catch (e) {
      // A dismissed checkout shows nothing, like the website.
      if (e.toast != null) Toast.error(e.toast!);
    } catch (_) {
      Toast.error('Error Placing Order');
    }
  }

  @override
  Widget build(BuildContext context) {
    final poojas = objList(_cart['pooja']);
    final hasPooja = poojas.isNotEmpty;
    final amounts = obj(_cart['amounts']);
    final partialAllowed = amounts['isPartialPaymentAllowed'] != false;
    final canPlace = _addresses.isNotEmpty;

    final type = _paymentType == 'partial' && partialAllowed ? 'partialPayment' : 'fullPayment';
    final amountObj = obj(amounts[type]);
    final base = double.parse(numOf(amountObj['amount']).toStringAsFixed(2));
    final gst = double.parse(numOf(amountObj['gstAmount']).toStringAsFixed(2));
    final total = base + gst;

    return SitePage(
      loading: _loading,
      bottomBar: hasPooja ? _placeOrderBar(total, canPlace, type) : null,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (widget.bmpChooseDate) ...[
              _notice('BookMypooja Team will contact you soon to confirm the auspicious dates.'),
              const SizedBox(height: 16),
            ],
            if (!truthy(_cart['templePoojaServiceId']))
              if (intOf(_user['userType']) == 3)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: _redButton('COMPLETE YOUR PROFILE', _openCompleteProfile),
                )
              else if (_addresses.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    _notice('BookMypooja Team will contact you soon to confirm the auspicious date.'),
                    const SizedBox(height: 22),
                    _redButton(_isEpooja ? 'Add Billing Address' : 'Add Puja Address', _openAddressModal),
                  ]),
                )
              else if (_defaultAddress != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.profileBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.gray200),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(!_isEpooja ? 'Address where Puja will be performed' : 'Billing Address',
                        style: AppText.poppins(size: 16, weight: FontWeight.w600, color: AppColors.defaultText)),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                        child: Text(str(_defaultAddress!['name']),
                            style: AppText.poppins(size: 14, weight: FontWeight.w500, color: AppColors.defaultText)),
                      ),
                      OutlinedButton(
                        onPressed: _openSelection,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.bluntRed),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        ),
                        child: Text('Change', style: AppText.poppins(size: 14, weight: FontWeight.w500, color: AppColors.bluntRed)),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Text(
                      '${str(_defaultAddress!['areaLocation'])}, ${str(_defaultAddress!['landmark'])}\n'
                      '${str(_defaultAddress!['city'])}, ${str(_defaultAddress!['state'])} - ${str(_defaultAddress!['pincode'])}\n'
                      'Mobile: ${str(_defaultAddress!['phoneNumber'])}',
                      style: AppText.poppins(size: 14, color: AppColors.defaultText),
                    ),
                  ]),
                ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('Cart Details', style: AppText.poppins(size: 14, weight: FontWeight.w600, color: AppColors.defaultText)),
            ),
            if (hasPooja) CartItemPooja(pooja: poojas.first, cart: _cart),
            if (hasPooja) ...[
              const SizedBox(height: 40),
              CouponBox(
                appliedCoupon: _appliedCoupon,
                discount: numOf(pick(amounts, ['fullPayment', 'discount'])),
                onApply: _applyCoupon,
                onRemove: _removeCoupon,
              ),
              Padding(
                padding: const EdgeInsets.only(top: 32, bottom: 8),
                child: Text('Payment Methods', style: AppText.poppins(size: 14, weight: FontWeight.w600, color: AppColors.defaultText)),
              ),
              Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.gray200)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (!_isEpooja && partialAllowed) _radio('Partial Payment', 'partial', top: false),
                  if (_paymentType == 'partial' && partialAllowed) _breakdown('partialPayment'),
                  _radio('Full Payment', 'full', top: !_isEpooja && partialAllowed),
                  if (_paymentType == 'full') _breakdown('fullPayment'),
                ]),
              ),
            ],
          ]),
        ),
      ],
    );
  }

  Widget _notice(String t) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0x33CBD5E1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.lightGrey),
        ),
        child: Text(t, style: AppText.poppins(size: 16, weight: FontWeight.w500, color: AppColors.bluntRed)),
      );

  Widget _redButton(String label, VoidCallback onTap) => Material(
        color: AppColors.bluntRed,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(label,
                textAlign: TextAlign.center,
                style: AppText.poppins(size: 12, weight: FontWeight.w500, color: Colors.white, letterSpacing: 1.2)),
          ),
        ),
      );

  Widget _radio(String label, String value, {required bool top}) => InkWell(
        onTap: () => setState(() => _paymentType = value),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(border: top ? const Border(top: BorderSide(color: AppColors.gray200)) : null),
          child: Row(children: [
            Expanded(child: Text(label, style: AppText.poppins(size: 16, color: AppColors.defaultText))),
            // Material radio look without the deprecated groupValue API.
            Container(
              width: 20,
              height: 20,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _paymentType == value ? AppColors.primary : AppColors.gray500, width: 2),
              ),
              child: _paymentType == value
                  ? Container(width: 10, height: 10, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.primary))
                  : null,
            ),
          ]),
        ),
      );

  /// PlaceOrderComponent.jsx (body; the sticky bar is [_placeOrderBar]).
  Widget _breakdown(String type) {
    final a = obj(obj(_cart['amounts'])[type]);
    final base = double.parse(numOf(a['amount']).toStringAsFixed(2));
    return Container(
      color: const Color(0x33CBD5E1),
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 2, offset: Offset(0, 1))],
          ),
          child: Column(children: [
            _row('Cart Amount', '₹ ${_num(base)}'),
            _row('Discount', '- ₹ ${_num(numOf(a['discount']))}', green: true),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4), child: Divider(height: 1)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.lightGrey),
              boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 2, offset: Offset(0, 1))],
            ),
            child: TextField(
              onChanged: (v) => _notes = v,
              minLines: 3,
              maxLines: 3,
              style: AppText.poppins(size: 14),
              decoration: fieldsetDecoration('Additional Notes', hint: 'Please add any more relevant details.')
                  .copyWith(enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, border: InputBorder.none),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text.rich(
            TextSpan(children: [
              const TextSpan(text: 'By clicking on the '),
              const TextSpan(text: 'Place Order', style: TextStyle(fontWeight: FontWeight.w700)),
              const TextSpan(text: ' button, you confirm that you have read and agree to our '),
              WidgetSpan(child: _link('Terms & Conditions', '/terms-and-conditions')),
              const TextSpan(text: ' and '),
              WidgetSpan(child: _link('Privacy Policy', '/privacy-policy')),
              const TextSpan(text: '.'),
            ]),
            style: AppText.poppins(size: 12, color: AppColors.gray600),
          ),
        ),
      ]),
    );
  }

  String _num(num v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  Widget _link(String t, String href) => GestureDetector(
        onTap: () => goHref(context, href),
        child: Text(t, style: AppText.poppins(size: 12, color: AppColors.bluntRed).copyWith(decoration: TextDecoration.underline)),
      );

  Widget _row(String l, String v, {bool green = false}) => SizedBox(
        height: 32,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(children: [
            Expanded(child: Text(l, style: AppText.poppins(size: 12, color: AppColors.gray600))),
            Text(v, style: AppText.poppins(size: 14, weight: FontWeight.w500, color: green ? AppColors.green600 : AppColors.foreground)),
          ]),
        ),
      );

  Widget _placeOrderBar(double total, bool canPlace, String type) => Container(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.paddingOf(context).bottom),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.lightGrey)),
          boxShadow: [BoxShadow(color: Color(0x1A000000), blurRadius: 15, offset: Offset(0, -2))],
        ),
        child: Row(children: [
          Expanded(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Payable Amount', style: AppText.poppins(size: 14, weight: FontWeight.w500, color: AppColors.gray700)),
              Text('₹ ${total.toStringAsFixed(2)}', style: AppText.poppins(size: 18, weight: FontWeight.w600, color: AppColors.gray900)),
            ]),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () => callPhone(),
            icon: const Icon(Icons.phone_outlined, size: 15, color: Color(0xFF8A1C23)),
            label: Text('Call', style: AppText.poppins(size: 14, weight: FontWeight.w500, color: const Color(0xFF8A1C23))),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.gray200),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: const Size(70, 36),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: canPlace ? AppColors.bluntRed : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: canPlace ? BorderSide.none : const BorderSide(color: AppColors.bluntRed),
            ),
            elevation: canPlace ? 3 : 0,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => canPlace ? _placeOrder(type, total) : _openAddressModal(),
              child: Container(
                constraints: const BoxConstraints(minWidth: 110),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                alignment: Alignment.center,
                child: Text(
                  canPlace ? 'Place Order' : (_isEpooja ? 'Add Billing Address' : 'Add Puja Address'),
                  style: AppText.poppins(size: 14, weight: FontWeight.w500, color: canPlace ? Colors.white : AppColors.bluntRed),
                ),
              ),
            ),
          ),
        ]),
      );
}

/// bookingComponent/CartItemPoojaComponent.jsx
class CartItemPooja extends StatelessWidget {
  const CartItemPooja({super.key, required this.pooja, required this.cart});
  final Json pooja;
  final Json cart;

  @override
  Widget build(BuildContext context) {
    final media = objList(pooja['media']);
    final type = str(cart['packageType']);
    final pkg = obj(pick(cart, ['packageDetails', type]));
    final pandits = truthy(pkg['numberOfPandits']) ? '${str(pkg['numberOfPandits'])} Pandit' : '';
    final days = truthy(pkg['numberOfDays']) ? ' + ${str(pkg['numberOfDays'])} Day' : '';
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0x33CBD5E1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.lightGrey),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (media.isNotEmpty) ...[
          Container(
            width: 64,
            height: 64,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(color: AppColors.gray300, borderRadius: BorderRadius.circular(8)),
            child: SiteImage(str(media.first['mediaUrl'])),
          ),
          const SizedBox(width: 16),
        ],
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text.rich(
              TextSpan(children: [
                TextSpan(text: str(pooja['name'])),
                if (str(cart['location']) == ePoojaLocationId)
                  TextSpan(
                    text: '  (e-Pooja)',
                    style: AppText.poppins(size: 12, color: AppColors.bluntRed),
                  ),
              ]),
              style: AppText.poppins(size: 14, weight: FontWeight.w600, color: AppColors.defaultText, height: 20 / 14),
            ),
            Text.rich(
              TextSpan(children: [
                const TextSpan(text: 'Package : '),
                TextSpan(text: type.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w500)),
              ]),
              style: AppText.poppins(size: 12, color: AppColors.defaultText, height: 20 / 12),
            ),
            Text('$pandits$days', style: AppText.poppins(size: 12, color: AppColors.defaultText)),
            const SizedBox(height: 16),
            Row(children: [
              _labelValue('Performing Date', str(cart['date'])),
              const SizedBox(width: 24),
              Flexible(child: _labelValue('Performing Time', str(cart['timeslot']))),
            ]),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: Text('₹ ${truthy(pooja['price']) ? formatAmountPutComma(pooja['price']) : ''}',
                    style: AppText.poppins(size: 16, weight: FontWeight.w600, color: AppColors.defaultText)),
              ),
              GestureDetector(
                onTap: () => context.push(
                  '/${Cookies.get('language_name')?.toLowerCase()}/${Cookies.get('location_name')?.toLowerCase()}/pooja/${str(pooja['slug'])}',
                ),
                child: Text('Modify', style: AppText.poppins(size: 14, weight: FontWeight.w500, color: AppColors.bluntRed)),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _labelValue(String l, String v) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l, style: AppText.poppins(size: 12, color: AppColors.headerQuote)),
        const SizedBox(height: 4),
        Text(v, style: AppText.poppins(size: 12, weight: FontWeight.w500, color: AppColors.defaultText)),
      ]);
}

/// bookingComponent/CouponComponent.jsx + CouponSelectionModal.jsx
class CouponBox extends StatelessWidget {
  const CouponBox({super.key, required this.appliedCoupon, required this.discount, required this.onApply, required this.onRemove});
  final Json? appliedCoupon;
  final num discount;
  final Future<bool> Function(Json coupon) onApply;
  final Future<void> Function() onRemove;

  @override
  Widget build(BuildContext context) {
    final c = appliedCoupon;
    if (c == null) {
      return GestureDetector(
        onTap: () => _openModal(context),
        child: Container(
          height: 80,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0x33CBD5E1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.lightGrey, width: 2),
          ),
          child: Row(children: [
            const Opacity(opacity: .8, child: SiteImage('/icons/Group6937.svg', width: 60, height: 60, fit: BoxFit.contain, placeholderColor: Colors.transparent)),
            const SizedBox(width: 20),
            Expanded(child: Text('Apply Coupons', style: AppText.poppins(size: 14, weight: FontWeight.w500))),
            const Icon(Icons.arrow_forward, size: 16),
          ]),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.lightGrey, width: 2)),
      child: Stack(children: [
        const Positioned(left: 4, top: 0, child: Opacity(opacity: .9, child: SiteImage('/icons/Group6937.svg', width: 60, height: 60, fit: BoxFit.contain, placeholderColor: Colors.transparent))),
        Padding(
          padding: const EdgeInsets.only(left: 80),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(strOrNull(c['couponName']) ?? 'Coupon Applied!',
                style: AppText.poppins(size: 14, weight: FontWeight.w500, color: AppColors.bluntRed)),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(children: [
                TextSpan(
                  text: intOf(c['couponType']) == 1 ? '${str(c['amount'])}%' : '$discount INR',
                  style: const TextStyle(color: AppColors.bluntRed),
                ),
                const TextSpan(text: ' Coupon Saving'),
              ]),
              style: AppText.poppins(size: 14, weight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: AppColors.bluntRed, borderRadius: BorderRadius.circular(8)),
                child: Text('REMOVE', style: AppText.poppins(size: 12, weight: FontWeight.w500, color: Colors.white)),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  void _openModal(BuildContext context) {
    final code = TextEditingController();
    bool? valid;
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .5),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Dialog(
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Expanded(child: Text('Apply Coupon', style: AppText.poppins(size: 16))),
                GestureDetector(onTap: () => Navigator.of(ctx).pop(), child: const Text('×', style: TextStyle(fontSize: 20, color: AppColors.gray500))),
              ]),
              const SizedBox(height: 16),
              TextField(
                controller: code,
                style: AppText.poppins(size: 16),
                decoration: InputDecoration(
                  hintText: 'Enter Coupon Code',
                  hintStyle: AppText.poppins(size: 16, color: AppColors.gray400),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.gray200)),
                ),
              ),
              const SizedBox(height: 8),
              Material(
                color: AppColors.bluntRed,
                borderRadius: BorderRadius.circular(6),
                child: InkWell(
                  onTap: () async {
                    try {
                      final r = await BmpApi.validateCoupon({'couponCode': code.text}, Cookies.get('accessToken'));
                      final d = obj(r.data);
                      if (r.statusCode == 201 && intOf(d['statusCode']) == 200) {
                        final body = obj(d['body']);
                        final msg = '${str(body['amount'])} ${intOf(body['couponType']) == 1 ? 'Percent' : 'Rupees'}';
                        final ok = await onApply(body);
                        setLocal(() => valid = ok);
                        if (ok && ctx.mounted) {
                          Navigator.of(ctx).pop();
                          Toast.success('You have got $msg discount on your Pooja Booking');
                        }
                      } else {
                        setLocal(() => valid = false);
                      }
                    } catch (_) {
                      setLocal(() => valid = false);
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('APPLY', textAlign: TextAlign.center, style: AppText.poppins(size: 16, color: Colors.white)),
                  ),
                ),
              ),
              if (valid == false)
                Padding(padding: const EdgeInsets.only(top: 4), child: Text('Invalid Coupon', style: AppText.poppins(size: 10, color: AppColors.red500))),
              if (valid == true)
                Padding(padding: const EdgeInsets.only(top: 4), child: Text('Valid Coupon Code', style: AppText.poppins(size: 10, color: AppColors.green500))),
            ]),
          ),
        ),
      ),
    );
  }
}
