import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/bmp_api.dart';
import '../../core/storage/cookies.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/json.dart';
import '../../core/utils/launch.dart';
import '../../core/utils/razorpay.dart';
import '../../core/widgets/site_image.dart';
import '../../core/widgets/toast.dart';
import '../../core/widgets/ui.dart';
import 'orders_page.dart';
import 'profile_page.dart';

const _poojaStages = ['Booked', 'Assigning Pandit', 'Pandit Assigned', 'Pooja Completed'];

/// pages/user/orders/[slug].jsx + Containers/OrderContainer/poojaOrderContainer.jsx
class OrderDetailPage extends StatefulWidget {
  const OrderDetailPage({super.key, required this.orderId, this.type});
  final String orderId;
  final String? type;

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  Json? _order;
  bool _loading = false;
  final _review = TextEditingController();
  int _rating = 5;

  @override
  void initState() {
    super.initState();
    _review.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _review.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (Cookies.get('accessToken') == null) {
      Toast.error('Please login to continue');
      context.push('/auth?redirect=${Uri.encodeComponent('/user/orders/${widget.orderId}')}');
      return;
    }
    setState(() => _loading = true);
    try {
      final r = await BmpApi.orderById(widget.orderId);
      final d = obj(r.data);
      if (r.statusCode == 200 && intOf(d['statusCode']) == 200) {
        final o = objList(d['body']).where((o) => str(o['_id']) == widget.orderId).firstOrNull;
        if (o == null) {
          Toast.error('Invalid order id');
          if (mounted) context.pushReplacement('/user/orders');
          return;
        }
        setState(() => _order = o);
      } else {
        Toast.error(strOrNull(d['message']) ?? 'Error fetching order');
        if (mounted) context.pushReplacement('/user/orders');
      }
    } catch (_) {
      Toast.error('Something went wrong while fetching order details');
      if (mounted) context.pushReplacement('/user/orders');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    final r = await BmpApi.orderById(widget.orderId);
    final d = obj(r.data);
    if (r.statusCode == 200 && intOf(d['statusCode']) == 200) {
      final o = objList(d['body']).where((o) => str(o['_id']) == widget.orderId).firstOrNull;
      if (o != null) setState(() => _order = o);
    } else {
      Toast.show(str(d['message']));
    }
  }

  Future<void> _confirmCancel() async {
    setState(() => _loading = true);
    try {
      final payload = _order?['templeService'] != null ? {'templePoojaServiceStatus': 2} : {'poojaOrderStatus': 1};
      final r = await BmpApi.updateOrder(widget.orderId, payload);
      if (r.statusCode == 200) {
        await _refresh();
        Toast.success('Booking cancelled successfully');
      } else {
        Toast.show('Error cancelling Booking');
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _submitReview() async {
    try {
      final r = await BmpApi.createPoojaReview(str(pick(_order, ['pooja', '_id'])), _review.text, _rating);
      final d = obj(r.data);
      if (r.statusCode == 201) {
        if (intOf(d['statusCode']) == 200) {
          Toast.success('Review Added Successfully');
          if (mounted) context.pop();
        } else {
          Toast.show('Error adding review');
        }
      } else {
        Toast.error('Server Error: Unable to add review.');
      }
    } catch (e) {
      Toast.error('$e');
    }
  }

  Future<void> _payRemaining() async {
    final o = _order!;
    final receipt = strOrNull(o['receipt']);
    if (receipt == null) {
      Toast.error('Invalid order data');
      return;
    }
    setState(() => _loading = true);
    try {
      final r = await BmpApi.createRemainingPaymentOrder(receipt);
      final d = obj(r.data);
      if (r.statusCode != 201 || intOf(d['statusCode']) != 200) throw Exception('Failed to create payment order');
      final rzp = str(pick(d, ['body', 'initiatedRazorPayOrderId']));
      final paid = await displayRazorpay(amount: intOf(pick(d, ['body', 'amount'])), razorpayOrderId: rzp);
      final v = await BmpApi.verifyPayment(
          razorPayPaymentId: paid.paymentId, razorPayOrderId: rzp, razorPaySignature: paid.signature, orderId: widget.orderId);
      if (v.statusCode == 201 && intOf(obj(v.data)['statusCode']) == 200) {
        Toast.success('Payment successful!');
        await _refresh();
      } else {
        throw Exception('Payment verification failed');
      }
    } on RazorpayFailure catch (e) {
      Toast.error(e.toast ?? 'Payment was cancelled');
    } catch (e) {
      Toast.error(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = _order;
    return UserShell(padding: const EdgeInsets.symmetric(horizontal: 12), children: [
      if (o == null)
        Text('Loading...', style: AppText.poppins())
      else if (_loading)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: Column(children: [
            const AppSpinner(),
            const SizedBox(height: 16),
            Text('Processing your request...', style: AppText.poppins(color: AppColors.gray600)),
          ]),
        )
      else
        Padding(padding: const EdgeInsets.only(bottom: 96), child: _card(o)),
    ]);
  }

  Widget _card(Json o) {
    final isEPooja = str(pick(o, ['pooja', 'typeOfPooja'])) == 'e-pooja';
    final orderStatus = intOf(o['poojaOrderStatus'], -1);
    final bookingStatus = intOf(o['poojaBookingStatus'], -1);
    final isCompleted = orderStatus == 3;
    final isCancelled = orderStatus == 1 || orderStatus == 4;
    final fb = obj(o['financialBreakdown']);
    final base = numOf(fb['basePackageAmount']);
    final paid = numOf(fb['amountPaid']);
    final remaining = numOf(fb['remainingAmount']);
    final total = numOf(fb['totalEffectiveAmount']);
    final coupon = numOf(fb['couponDiscount']);
    final additional = numOf(fb['additionalCharges']);
    final other = numOf(fb['otherCharges']);
    final manual = numOf(fb['manualDiscount']);
    final ps = str(fb['paymentStatus'], 'PENDING');
    final isPartial = ps == 'PARTIAL';
    final isFull = ps == 'FULL';
    final adjustments = objList(o['adjustments']);
    final charges = adjustments.where((a) => str(a['type']) == 'ADDITIONAL_CHARGE').toList();
    final discounts = adjustments.where((a) => str(a['type']) == 'DISCOUNT').toList();
    final hasAdditional = additional > 0 || other > 0 || charges.isNotEmpty;
    final (label, fg, bg, bd) = switch (orderStatus) {
      1 || 4 => ('CANCELLED', AppColors.red700, AppColors.red100, const Color(0xFFFECACA)),
      2 => ('ACCEPTED', AppColors.green700, AppColors.green100, const Color(0xFFBBF7D0)),
      3 => ('COMPLETED', AppColors.blue700, AppColors.blue100, const Color(0xFFBFDBFE)),
      _ => ('PENDING', AppColors.amber700, AppColors.amber100, const Color(0xFFFDE68A)),
    };
    final isReview = widget.type == 'review';

    Widget chip(IconData icon, String t) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: AppColors.gray50, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.gray200)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 12, color: AppColors.gray400),
            const SizedBox(width: 4),
            Text(t, style: AppText.poppins(size: 12, color: AppColors.gray700)),
          ]),
        );
    Widget tr(Widget left, String right, {Color bg = Colors.white, Color rc = AppColors.gray800, double rs = 12, bool bold = false}) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: bg, border: const Border(top: BorderSide(color: AppColors.gray100))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: left),
            Text(right, style: AppText.poppins(size: rs, weight: bold ? FontWeight.w700 : FontWeight.w600, color: rc)),
          ]),
        );
    Text tl(String t, Color c, {bool bold = false}) => Text(t, style: AppText.poppins(size: 12, color: c, weight: bold ? FontWeight.w700 : FontWeight.w400));
    Widget reasoned(String title, Color c, dynamic reason, Color rc) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          tl(title, c),
          if (strOrNull(reason) != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('"${str(reason)}"', style: AppText.poppins(size: 11, color: rc).copyWith(fontStyle: FontStyle.italic)),
            ),
        ]);
    Widget pill(String t, Color bg, Color fg) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
          child: Text(t, style: AppText.poppins(size: 11, weight: FontWeight.w600, color: fg)),
        );

    final body = isReview
        ? _reviewForm(o)
        : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 64,
                height: 64,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isEPooja ? const Color(0xFFBFDBFE) : AppColors.gray100, width: 2),
                  boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 3, offset: Offset(0, 1))],
                ),
                child: SiteImage(strOrNull(pick(o, ['pooja', 'media', 0, 'mediaUrl']))),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(text: str(pick(o, ['pooja', 'name']))),
                      if (isEPooja)
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.blue100, borderRadius: BorderRadius.circular(999)),
                            child: Text('E-POOJA', style: AppText.poppins(size: 10, weight: FontWeight.w700, color: AppColors.blue700)),
                          ),
                        ),
                    ]),
                    style: AppText.poppins(size: 16, weight: FontWeight.w700, color: AppColors.gray900, height: 1.35),
                  ),
                  if (strOrNull(o['packageSelected']) != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text('${capitalizeFirst(str(o['packageSelected']))} Package', style: AppText.poppins(size: 12, color: AppColors.gray500)),
                    ),
                  if (strOrNull(pick(o, ['pooja', 'addons'])) != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(str(pick(o, ['pooja', 'addons'])),
                          maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.poppins(size: 12, color: AppColors.gray500)),
                    ),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    chip(Icons.calendar_today_outlined, strOrNull(o['rescheduledBookingDate']) ?? str(o['bookingDate'])),
                    chip(Icons.access_time, strOrNull(o['rescheduledBookingTimeSlot']) ?? str(o['bookingTimeSlot'])),
                  ]),
                ]),
              ),
            ]),
            if (total > 0) ...[
              const SizedBox(height: 20),
              Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.gray200)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Container(
                    color: AppColors.gray50,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Text('PAYMENT BREAKDOWN', style: AppText.poppins(size: 12, weight: FontWeight.w700, color: AppColors.gray700, letterSpacing: .6)),
                  ),
                  if (base > 0) tr(tl('Base Package Price', AppColors.gray600), '₹${toLocale(base)}'),
                  if (other > 0)
                    tr(tl('Other Charges', AppColors.amber800), '+ ₹${toLocale(other)}', bg: const Color(0x66FFFBEB), rc: AppColors.amber700),
                  for (final a in charges)
                    tr(reasoned('Additional Charge', AppColors.amber800, a['reason'], AppColors.amber600), '+ ₹${toLocale(numOf(a['amount']) / 100)}',
                        bg: const Color(0x66FFFBEB), rc: AppColors.amber700),
                  for (final a in discounts)
                    tr(reasoned('Discount Applied', const Color(0xFF166534), a['reason'], AppColors.green600), '− ₹${toLocale(numOf(a['amount']) / 100)}',
                        bg: const Color(0x66F0FDF4), rc: AppColors.green700),
                  if (manual > 0)
                    tr(tl('Manual Discount', const Color(0xFF166534)), '− ₹${toLocale(manual)}', bg: const Color(0x66F0FDF4), rc: AppColors.green700),
                  if (coupon > 0)
                    tr(tl('Coupon Savings', const Color(0xFF166534)), '− ₹${toLocale(coupon)}', bg: const Color(0x66F0FDF4), rc: AppColors.green700),
                  tr(tl('Total Amount', AppColors.gray800, bold: true), '₹${toLocale(total)}', bg: AppColors.gray50, rc: AppColors.gray900, rs: 14, bold: true),
                  tr(tl('Amount Paid', AppColors.gray600), '₹${toLocale(paid)}', rc: AppColors.green600),
                  if (remaining > 0 && !isCancelled)
                    tr(Text('Balance Due', style: AppText.poppins(size: 12, weight: FontWeight.w600, color: AppColors.red700)), '₹${toLocale(remaining)}',
                        bg: const Color(0x80FEF2F2), rc: AppColors.red600, rs: 14, bold: true),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: const BoxDecoration(color: AppColors.gray50, border: Border(top: BorderSide(color: AppColors.gray100))),
                    child: Wrap(spacing: 8, children: [
                      if (isFull) pill('✓ Fully Paid', AppColors.green100, AppColors.green700),
                      if (isPartial && !isCancelled) pill('Partial Payment', const Color(0xFFFEF9C3), const Color(0xFFA16207)),
                      if (!isFull && !isPartial) pill('Unpaid', AppColors.gray100, AppColors.gray500),
                    ]),
                  ),
                  if (hasAdditional)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: const BoxDecoration(color: Color(0x80FFFBEB), border: Border(top: BorderSide(color: AppColors.amber100))),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Padding(padding: EdgeInsets.only(top: 2), child: Icon(Icons.info_outline, size: 14, color: AppColors.amber500)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Additional charges have been applied to your order. These are already included in the total above. Please contact us if you have any questions.',
                            style: AppText.poppins(size: 11, color: AppColors.amber700, height: 1.6),
                          ),
                        ),
                      ]),
                    ),
                ]),
              ),
            ],
            if (isEPooja && isCompleted && strOrNull(o['recordingLink']) != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.blue50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => openExternal(str(o['recordingLink'])),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(color: AppColors.blue100, shape: BoxShape.circle),
                      child: const Icon(Icons.play_arrow, size: 20, color: AppColors.blue600),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('E-Pooja Recording', style: AppText.poppins(size: 14, weight: FontWeight.w600, color: AppColors.gray900)),
                      Text('Watch your recording', style: AppText.poppins(size: 12, color: AppColors.gray500)),
                    ]),
                  ),
                  Material(
                    color: AppColors.blue600,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: () => openExternal(str(o['recordingLink'])),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(children: [
                          Text('Watch', style: AppText.poppins(size: 12, weight: FontWeight.w600, color: Colors.white)),
                          const SizedBox(width: 6),
                          const Icon(Icons.open_in_new, size: 14, color: Colors.white),
                        ]),
                      ),
                    ),
                  ),
                ]),
              ),
            ],
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.gray50, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.gray200)),
              child: _ProgressBar(status: bookingStatus),
            ),
            if (orderStatus != 3) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.gray50, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.gray200)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('NEXT STEP', style: AppText.poppins(size: 10, weight: FontWeight.w700, color: AppColors.gray400, letterSpacing: .6)),
                  const SizedBox(height: 8),
                  Text(_nextStep(o, isEPooja), style: AppText.poppins(size: 14, weight: FontWeight.w500, color: AppColors.gray800, height: 1.6)),
                  const SizedBox(height: 8),
                  Text(_statusDescription(o, isEPooja), style: AppText.poppins(size: 12, color: AppColors.gray500, height: 1.6)),
                  if (orderStatus == 2)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: GestureDetector(
                        onTap: () => context.push(
                          '/${Cookies.get('language_name')?.toLowerCase()}/${Cookies.get('location_name')?.toLowerCase()}/pooja/${str(pick(o, ['pooja', 'slug']))}',
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text('Learn More', style: AppText.poppins(size: 12, weight: FontWeight.w500, color: AppColors.blue600)),
                          const Icon(Icons.chevron_right, size: 14, color: AppColors.blue600),
                        ]),
                      ),
                    ),
                ]),
              ),
            ],
            if (remaining > 0 && !isCancelled) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.red50, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.red100)),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Pending Balance: ₹${toLocale(remaining)}',
                          style: AppText.poppins(size: 14, weight: FontWeight.w700, color: const Color(0xFF991B1B))),
                      const SizedBox(height: 2),
                      Text('Please clear your remaining balance to proceed.', style: AppText.poppins(size: 12, color: AppColors.red500)),
                    ]),
                  ),
                  const SizedBox(width: 16),
                  Material(
                    color: AppColors.red600,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _payRemaining,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        child: Text('Pay Now', style: AppText.poppins(size: 14, weight: FontWeight.w700, color: Colors.white)),
                      ),
                    ),
                  ),
                ]),
              ),
            ],
            if (orderStatus != 1 && orderStatus != 4 && bookingStatus != 3) ...[
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: _outlined('Cancel Booking', AppColors.red600, const Color(0xFFFECACA), () => _policyModal(withCancel: true)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _outlined('Reschedule', AppColors.gray700, AppColors.gray200, () {
                    context.push(
                      '/booking?reschedule=true&orderId=${str(o['_id'])}&bookingDate=${str(o['bookingDate'])}&bookingTimeSlot=${Uri.encodeComponent(str(o['bookingTimeSlot']))}',
                    );
                  }),
                ),
              ]),
            ],
            if (orderStatus != 4 && orderStatus != 3) ...[
              const SizedBox(height: 20),
              _policyCard('Cancellation Policy', 'Need to cancel? Check our cancellation policy for refund details.', () => _policyModal(withCancel: false)),
              const SizedBox(height: 12),
              _policyCard('Reschedule Policy', 'Plans changed? We offer flexible rescheduling for your convenience.', _rescheduleModal),
            ],
          ]);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        gradient: isEPooja ? const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.blue50, Colors.white]) : null,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isEPooja ? const Color(0xFFBFDBFE) : AppColors.gray200),
        boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 2, offset: Offset(0, 1))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.gray100))),
          child: Row(children: [
            Text('Order', style: AppText.poppins(size: 12, weight: FontWeight.w500, color: AppColors.gray500)),
            const SizedBox(width: 8),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: AppColors.gray100, borderRadius: BorderRadius.circular(8)),
                child: Text(str(o['receipt']),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.gray800)),
              ),
            ),
            const Spacer(),
            if (!isReview)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999), border: Border.all(color: bd)),
                child: Text(label, style: AppText.poppins(size: 11, weight: FontWeight.w700, color: fg, letterSpacing: .4)),
              ),
          ]),
        ),
        Padding(padding: const EdgeInsets.all(16), child: body),
      ]),
    );
  }

  String capitalizeFirst(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  Widget _outlined(String t, Color fg, Color border, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: border)),
          child: Text(t, textAlign: TextAlign.center, style: AppText.poppins(size: 14, weight: FontWeight.w500, color: fg)),
        ),
      );

  Widget _policyCard(String title, String text, VoidCallback onTap) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.gray50, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.gray200)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: AppText.poppins(size: 12, weight: FontWeight.w600, color: AppColors.gray800)),
          const SizedBox(height: 4),
          Text(text, style: AppText.poppins(size: 11, color: AppColors.gray500, height: 1.6)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: onTap,
            child: Text('View Policy →', style: AppText.poppins(size: 11, weight: FontWeight.w600, color: AppColors.blue600)),
          ),
        ]),
      );

  Widget _reviewForm(Json o) {
    const max = 160;
    final d = _review.text;
    final empty = d.trim().isEmpty;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 48,
        height: 48,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: const Color(0xFF4ADE80), borderRadius: BorderRadius.circular(8)),
        child: SiteImage(strOrNull(pick(o, ['pooja', 'media', 0, 'mediaUrl'])) ?? '/images/aigenerated/Deities.jpeg'),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(str(pick(o, ['pooja', 'name'])),
              maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.poppins(size: 14, weight: FontWeight.w600, color: AppColors.defaultText)),
          const SizedBox(height: 4),
          Text('Rate this Pooja', style: AppText.poppins(size: 14, color: AppColors.defaultText)),
          Row(children: [
            for (var i = 1; i <= 5; i++)
              GestureDetector(
                onTap: () => setState(() => _rating = i),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Text('★', style: TextStyle(fontSize: 15, color: i <= _rating ? const Color(0xFFFFD700) : Colors.grey)),
                ),
              ),
          ]),
          const SizedBox(height: 16),
          Stack(children: [
            TextField(
              controller: _review,
              minLines: 6,
              maxLines: 6,
              style: AppText.poppins(size: 12),
              decoration: InputDecoration(
                labelText: 'Review this pooja',
                labelStyle: AppText.poppins(size: 12, weight: FontWeight.w500),
                floatingLabelBehavior: FloatingLabelBehavior.always,
                hintText: 'Description (160 character)',
                hintStyle: AppText.poppins(size: 12, color: AppColors.headerQuote),
                filled: false,
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: AppColors.lightGrey)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: AppColors.lightGrey)),
              ),
            ),
            if (d.isNotEmpty)
              Positioned(
                right: 8,
                top: 0,
                child: Text(
                  d.length > max ? ' - ${d.length - max} limit exceeded' : '${max - d.length} character remaining',
                  style: AppText.poppins(size: 8, weight: FontWeight.w500, color: d.length > max ? const Color(0xFFF87171) : AppColors.defaultText, letterSpacing: .4),
                ),
              ),
          ]),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: empty ? null : _submitReview,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 38, vertical: 14),
                decoration: BoxDecoration(color: empty ? AppColors.lightGrey : AppColors.bluntRed, borderRadius: BorderRadius.circular(8)),
                child: Text('SUBMIT', style: AppText.poppins(size: 14, color: empty ? AppColors.foreground : Colors.white)),
              ),
            ),
          ),
        ]),
      ),
    ]);
  }

  String _nextStep(Json o, bool e) {
    final b = intOf(o['poojaBookingStatus'], -1);
    final s = intOf(o['poojaOrderStatus'], -1);
    final cancelled = s == 1 || s == 4;
    if ((b == 0 || b == 1) && !cancelled) return e ? 'Preparing for Online Session' : 'Assigning Pandit Ji';
    if (b == 2 && !cancelled) return e ? 'Online Session Scheduled' : 'Panditji will be on time';
    if (!cancelled && intOf(o['poojaPaymentType'], -1) == 1) return 'Pay the outstanding balance';
    if (cancelled) return 'Refund in process';
    return '';
  }

  String _statusDescription(Json o, bool e) {
    final b = intOf(o['poojaBookingStatus'], -1);
    final s = intOf(o['poojaOrderStatus'], -1);
    if (s == 0) {
      return e ? 'An online session will be scheduled 24–72 hours before booking time.' : 'A pandit will be assigned 24–72 hours before booking time.';
    }
    if (s == 3 || (b == 3 && s != 4 && s != 1)) {
      return e ? 'E-Pooja completed successfully. You can access the recording above.' : 'Pooja completed successfully.';
    }
    return '';
  }

  void _policyModal({required bool withCancel}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: .5),
      builder: (ctx) => ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * .9),
        child: Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.gray100))),
              child: Text('Refund & Cancellation Policy', style: AppText.poppins(size: 16, weight: FontWeight.w700, color: AppColors.gray900)),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  _p('We understand that you may have to cancel the Pooja ceremony for some reasons.'),
                  _p('In case of customer initiated cancellations, please get in touch with our customer care number or email us on our official support email ID.'),
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppColors.gray50, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.gray200)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('REFUND SCHEDULE', style: AppText.poppins(size: 12, weight: FontWeight.w600, color: AppColors.gray900, letterSpacing: .4)),
                      const SizedBox(height: 8),
                      _bullet('Cancelled more than 96 hours before — ', '90% refund'),
                      _bullet('Cancelled between 48–96 hours — ', '50% refund'),
                      _bullet('Cancelled within 48 hours — ', 'No refund'),
                    ]),
                  ),
                  _p('If Panditji cannot attend the scheduled Pooja, BookMyPooja shall refund the entire amount within 5 working days.'),
                  _p("The Pooja Items amount shall be charged in case you have selected the add on 'All Puja Items' Option."),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppColors.orange50, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFED7AA))),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Special Notice – Festival Dates 2026', style: AppText.poppins(size: 12, weight: FontWeight.w600, color: const Color(0xFF7C2D12))),
                      const SizedBox(height: 8),
                      Text.rich(
                        const TextSpan(children: [
                          TextSpan(text: 'Regular cancellation and reschedule rules will '),
                          TextSpan(text: 'not', style: TextStyle(fontWeight: FontWeight.w700)),
                          TextSpan(text: ' apply on festival dates and ±1 day. After pandit assignment, no timing reschedule is allowed. Cancellation penalty is '),
                          TextSpan(text: '100%', style: TextStyle(fontWeight: FontWeight.w700)),
                          TextSpan(text: ' of charges.'),
                        ]),
                        style: AppText.poppins(size: 12, color: const Color(0xFF9A3412), height: 1.6),
                      ),
                      const SizedBox(height: 12),
                      Text(_festivalShort, style: AppText.poppins(size: 10, color: AppColors.gray700, height: 1.6)),
                    ]),
                  ),
                ]),
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + MediaQuery.paddingOf(ctx).bottom),
              decoration: const BoxDecoration(color: AppColors.gray50, border: Border(top: BorderSide(color: AppColors.gray100))),
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                _modalBtn('Close', Colors.white, AppColors.gray600, () => Navigator.of(ctx).pop(), border: AppColors.gray200),
                if (withCancel) ...[
                  const SizedBox(width: 12),
                  _modalBtn('Cancel Pooja', AppColors.red600, Colors.white, () {
                    Navigator.of(ctx).pop();
                    _confirmCancel();
                  }),
                ],
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  void _rescheduleModal() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .5),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * .9),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.gray200))),
              child: Text('Reschedule Policy – BookMyPoojaOnline.com',
                  style: AppText.poppins(size: 20, weight: FontWeight.w600, color: AppColors.gray900)),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  for (final s in _rescheduleSections) ...[
                    Text(s.$1, style: AppText.poppins(weight: FontWeight.w600, color: AppColors.gray900)),
                    const SizedBox(height: 8),
                    for (final l in s.$2)
                      s.$3
                          ? Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text('•  $l', style: AppText.poppins(color: AppColors.gray700)),
                            )
                          : Text(l, style: AppText.poppins(color: AppColors.gray700)),
                    const SizedBox(height: 24),
                  ],
                  Text('9. Special Notice – Festival Dates 2026 (Cancellations & Reschedules)',
                      style: AppText.poppins(weight: FontWeight.w600, color: AppColors.gray900)),
                  const SizedBox(height: 8),
                  Text.rich(
                    const TextSpan(children: [
                      TextSpan(text: 'Regular cancellations and reschedule rules will '),
                      TextSpan(text: 'not', style: TextStyle(fontWeight: FontWeight.w700)),
                      TextSpan(
                          text:
                              ' apply on the dates mentioned. Any bookings made for these dates and dates +/−1 day, after the pandit ji is assigned, there will not be any reschedule allowed with regards to timing. The cancellation penalty will be '),
                      TextSpan(text: '100% of the charges', style: TextStyle(fontWeight: FontWeight.w700)),
                      TextSpan(
                          text:
                              '. This is due to the fact that – because of festive rush demands, managing and reshuffling pandit ji schedules becomes an impossible task. Your cooperation is appreciated.'),
                    ]),
                    style: AppText.poppins(color: AppColors.gray700),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppColors.orange50, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFFED7AA))),
                    child: Text(_festivalFull, style: AppText.poppins(size: 12, color: AppColors.gray700, height: 1.6)),
                  ),
                ]),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(color: AppColors.gray50, border: Border(top: BorderSide(color: AppColors.gray200))),
              child: Align(
                alignment: Alignment.centerRight,
                child: _modalBtn('Close', Colors.white, AppColors.gray600, () => Navigator.of(ctx).pop(), border: AppColors.gray300),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _p(String t) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(t, style: AppText.poppins(size: 14, color: AppColors.gray700)));

  Widget _bullet(String t, String b) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 6, right: 8),
            decoration: const BoxDecoration(color: AppColors.gray400, shape: BoxShape.circle),
          ),
          Expanded(
            child: Text.rich(
              TextSpan(children: [TextSpan(text: t), TextSpan(text: b, style: const TextStyle(fontWeight: FontWeight.w700))]),
              style: AppText.poppins(size: 12, color: AppColors.gray700),
            ),
          ),
        ]),
      );

  Widget _modalBtn(String t, Color bg, Color fg, VoidCallback onTap, {Color? border}) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12), border: border == null ? null : Border.all(color: border)),
          child: Text(t, style: AppText.poppins(size: 14, weight: FontWeight.w600, color: fg)),
        ),
      );
}

/// OrderComponent/OrderProgressBar.jsx (vertical on phones).
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.status});
  final int status;

  @override
  Widget build(BuildContext context) {
    final progress = switch (status) {
      0 => 1,
      1 => 2,
      2 => 3,
      3 => 4,
      4 => 5,
      _ => 0,
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (var i = 0; i < _poojaStages.length; i++) ...[
        Row(children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(shape: BoxShape.circle, color: i < progress ? AppColors.bluntRed : AppColors.lightGrey),
          ),
          const SizedBox(width: 12),
          Opacity(
            opacity: i < progress ? 1 : .2,
            child: Container(
              padding: i < progress && i == _poojaStages.length - 1 ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4) : EdgeInsets.zero,
              decoration: i < progress && i == _poojaStages.length - 1
                  ? BoxDecoration(color: AppColors.bluntRed, borderRadius: BorderRadius.circular(4))
                  : null,
              child: Text(_poojaStages[i],
                  style: AppText.poppins(size: 10, color: i < progress && i == _poojaStages.length - 1 ? Colors.white : AppColors.foreground)),
            ),
          ),
        ]),
        if (i < _poojaStages.length - 1)
          Container(width: 2, height: 40, margin: const EdgeInsets.only(left: 5), color: i < progress ? AppColors.bluntRed : AppColors.lightGrey),
      ],
    ]);
  }
}

const _rescheduleSections = [
  ('1. Eligibility for Rescheduling', [
    'Bookings can be rescheduled up to 48 hours before the scheduled pooja time.',
    'Rescheduling requests made within 48 hours are subject to pandit availability and approval.',
  ], true),
  ('2. Number of Reschedules', [
    'Additional reschedule requests may attract a fee (10%–30% of booking fee), depending on the pooja type and arrangements already made.',
  ], true),
  ('3. Process to Reschedule', [
    'Customers must request rescheduling by contacting BookMyPooja Online customer support via call or WhatsApp, and by submitting a reschedule request through their booking portal if booked via the website.',
    'The new date and time will be confirmed based on pandit availability and muhurat.',
  ], true),
  ('4. Samagri & Setup Impact', [
    'If samagri or logistics have already been arranged, rescheduling may involve additional charges.',
    'Fresh samagri requirements due to date change will be charged separately, if applicable.',
  ], true),
  ('5. Force Majeure / Unavoidable Situations', [
    'In cases of emergencies, health issues, or unavoidable circumstances, BookMyPooja Online will make best efforts to accommodate rescheduling without penalty.',
  ], false),
  ('6. No-Show Policy', [
    'If the customer is unavailable at the scheduled time without prior notice, the booking will be treated as completed, and rescheduling will not be permitted.',
  ], false),
  ('7. Company Rights', [
    'BookMyPooja Online reserves the right to reschedule or assign an alternate pandit in rare situations due to availability, emergencies, or unforeseen circumstances, while maintaining ritual integrity.',
  ], false),
  ('8. Acceptance of Policy', [
    'By booking a pooja on BookMyPoojaOnline.com, the customer agrees to this reschedule policy.',
  ], false),
];

const _festivalShort = '''📅 FESTIVAL DATES FOR 2026

── JANUARY ──
03 Jan (Sat)  •  Pausha Purnima
06 Jan (Tue)  •  Sakat Chauth
14 Jan (Wed)  •  Makar Sankranti / Pongal
18 Jan (Sun)  •  Mauni Amavasya
23 Jan (Fri)  •  Vasant Panchami

── FEBRUARY ──
15 Feb (Sun)  •  Maha Shivaratri

── MARCH ──
04 Mar (Wed)  •  Holi
19 Mar (Thu)  •  Ugadi / Gudi Padwa
26 Mar (Thu)  •  Rama Navami

── APRIL ──
02 Apr (Thu)  •  Hanuman Jayanti
19 Apr (Sun)  •  Akshaya Tritiya

── AUGUST ──
28 Aug (Fri)  •  Raksha Bandhan

── SEPTEMBER ──
04 Sep (Fri)  •  Krishna Janmashtami
14 Sep (Mon)  •  Ganesh Chaturthi

── OCTOBER ──
20 Oct (Tue)  •  Vijaya Dashami / Dussehra

── NOVEMBER ──
08 Nov (Sun)  •  Diwali
09 Nov (Mon)  •  Govardhan Puja

Note: Dates +/- 1 day from each are also covered.''';

const _festivalFull = '''📅 FESTIVAL DATES FOR 2026

── JANUARY ──
03 Jan (Sat)  •  Pausha Purnima
06 Jan (Tue)  •  Sakat Chauth
14 Jan (Wed)  •  Makar Sankranti / Pongal / Shattila Ekadashi
18 Jan (Sun)  •  Mauni Amavasya
23 Jan (Fri)  •  Vasant Panchami
25 Jan (Sun)  •  Ratha Saptami
26 Jan (Mon)  •  Bhishma Ashtami
29 Jan (Thu)  •  Jaya Ekadashi

── FEBRUARY ──
01 Feb (Sun)  •  Magha Purnima (Shukla Purnima)
13 Feb (Fri)  •  Kumbha Sankranti / Vijaya Ekadashi
15 Feb (Sun)  •  Maha Shivaratri
17 Feb (Tue)  •  Surya Grahan
26 Feb (Thu)  •  Republic Day (observed)
27 Feb (Fri)  •  Amalaki Ekadashi

── MARCH ──
03 Mar (Tue)  •  Chhoti Holi / Lunar Eclipse
04 Mar (Wed)  •  Holi
11 Mar (Wed)  •  Sheetala Ashtami
15 Mar (Sun)  •  Meena Sankranti / Papamochani Ekadashi
19 Mar (Thu)  •  Ugadi / Gudi Padwa
21 Mar (Sat)  •  Gauri Puja / Gangaur
26 Mar (Thu)  •  Rama Navami (Smarta)
27 Mar (Fri)  •  Rama Navami (ISKCON) / Swaminarayan Jayanti
29 Mar (Sun)  •  Kamada Ekadashi

── APRIL ──
02 Apr (Thu)  •  Hanuman Jayanti / Hanuman Janmotsava
13 Apr (Mon)  •  Varuthini Ekadashi
14 Apr (Tue)  •  Mesha Sankranti
19 Apr (Sun)  •  Parashurama Jayanti & Akshaya Tritiya
23 Apr (Thu)  •  Ganga Saptami
25 Apr (Sat)  •  Sita Navami
27 Apr (Mon)  •  Mohini Ekadashi
30 Apr (Thu)  •  Narasimha Jayanti

── MAY ──
01 May (Fri)  •  Buddha Purnima / Vaishakha Purnima
02 May (Sat)  •  Narada Jayanti
13 May (Wed)  •  Apara Ekadashi
15 May (Fri)  •  Vrishabha Sankranti
16 May (Sat)  •  Vat Savitri Vrat & Shani Jayanti
25 May (Mon)  •  Ganga Dussehra
27 May (Wed)  •  Padmini Ekadashi
31 May (Sun)  •  Jyeshtha Adhika Purnima

── JUNE ──
11 Jun (Thu)  •  Parama Ekadashi
15 Jun (Mon)  •  Mithuna Sankranti
25 Jun (Thu)  •  Nirjala Ekadashi
29 Jun (Mon)  •  Vat Purnima Vrat / Jyeshtha Purnima

── JULY ──
10 Jul (Fri)  •  Yogini Ekadashi
11 Jul (Sat)  •  Gauna Yogini Ekadashi
16 Jul (Thu)  •  Jagannath Rathyatra & Karka Sankranti
25 Jul (Sat)  •  Devshayani Ekadashi
29 Jul (Wed)  •  Guru Purnima / Ashadha Purnima

── AUGUST ──
15 Aug (Sat)  •  Independence Day (National Observance)
26 Aug (Wed)  •  Onam
28 Aug (Fri)  •  Raksha Bandhan / Rakhi

── SEPTEMBER ──
04 Sep (Fri)  •  Krishna Janmashtami
14 Sep (Mon)  •  Ganesh Chaturthi

── OCTOBER ──
06 Oct (Tue)  •  Indira Ekadashi
11 Oct (Sun)  •  Navratri Begins
19 Oct (Mon)  •  Durga Ashtami / Maha Navami
20 Oct (Tue)  •  Vijaya Dashami / Dussehra
22 Oct (Thu)  •  Papankusha Ekadashi
25 Oct (Sun)  •  Sharad Purnima / Kojagara Puja
29 Oct (Thu)  •  Karwa Chauth

── NOVEMBER ──
01 Nov (Sun)  •  Ahoi Ashtami
05 Nov (Thu)  •  Govatsa Dwadashi / Rama Ekadashi
06 Nov (Fri)  •  Dhanteras
08 Nov (Sun)  •  Lakshmi Puja / Diwali / Narak Chaturdashi
09 Nov (Mon)  •  Govardhan Puja
11 Nov (Wed)  •  Bhai Dooj / Bhaiya Dooj
15 Nov (Sun)  •  Chhath Puja
16 Nov (Mon)  •  Vrishchika Sankranti
20 Nov (Fri)  •  Devutthana Ekadashi
24 Nov (Tue)  •  Kartika Purnima

── DECEMBER ──
25 Dec (Fri)  •  Jaya Ekadashi

Note: Dates +/- 1 day from each of the above are also covered under this special notice.''';
