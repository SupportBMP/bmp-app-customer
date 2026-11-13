import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/api/bmp_api.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/json.dart';
import '../../core/utils/razorpay.dart';
import '../../core/widgets/form_fields.dart';
import '../../core/widgets/site_image.dart';
import '../../core/widgets/toast.dart';
import '../pooja/listing_widgets.dart';
import '../pooja/pooja_detail_page.dart';
import 'profile_page.dart';
import '../../core/widgets/ui.dart';

/// `Number.toLocaleString()` (en-US grouping, as the browser renders it).
String toLocale(num n) => NumberFormat.decimalPattern('en_US').format(n);

/// pages/user/orders/index.jsx (pooja orders; the temple order types are
/// out of scope for the app).
class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  static const _perPage = 6;
  List<Json> _orders = [];
  int _total = 0;
  int _page = 1;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _orders = [];
      _total = 0;
      _error = null;
      _loading = true;
    });
    try {
      final r = await BmpApi.allOrders(_page, _perPage, orderType: 1);
      final d = obj(r.data);
      final code = intOf(d['statusCode']);
      if (code == 200) {
        _orders = objList(d['body']);
        _total = intOf(d['totalCount']);
      } else if (code == 400 && '${d['message']} ${d['error']}'.toLowerCase().contains('not found')) {
        // BMP_BE answers "Order not found" (400 in the body) when the user
        // has no orders yet; that's the empty state, not an error.
      } else {
        _error = strOrNull(d['error']) ?? strOrNull(d['message']) ?? 'Failed to fetch orders';
        Toast.error(_error!);
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        // Expired session: sign out so the router sends the user to /auth.
        if (mounted) ProviderScope.containerOf(context).read(authProvider.notifier).logout();
        return;
      }
      _error = apiErrorMessage(e, 'Could not load your orders. Check your connection and try again.');
      Toast.error(_error!);
    } catch (e) {
      _error = 'An unexpected error occurred';
      Toast.error(_error!);
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _payRemaining(Json order) async {
    final receipt = strOrNull(order['receipt']);
    final id = strOrNull(order['_id']);
    if (receipt == null || id == null) {
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
          razorPayPaymentId: paid.paymentId, razorPayOrderId: rzp, razorPaySignature: paid.signature, orderId: id);
      if (v.statusCode == 201 && intOf(obj(v.data)['statusCode']) == 200) {
        Toast.success('Payment successful!');
        await _fetch();
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
    final nPages = (_total / _perPage).ceil();
    return UserShell(padding: EdgeInsets.zero, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: AppColors.gray200)),
          boxShadow: [BoxShadow(color: Color(0x0D000000), blurRadius: 2, offset: Offset(0, 1))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('My Orders', style: AppText.poppins(size: 20, weight: FontWeight.w600, color: AppColors.gray900)),
          const SizedBox(height: 4),
          Text('$_total ${_total == 1 ? 'Item' : 'Items'}', style: AppText.poppins(size: 14, color: AppColors.gray500)),
          const SizedBox(height: 16),
          AppSelectField<String>(
            value: 'pooja',
            options: const ['pooja'],
            labelOf: (_) => 'Pooja Orders',
            minHeight: 50,
            radius: 8,
            borderColor: AppColors.bluntRed,
            textStyle: AppText.poppins(size: 16, weight: FontWeight.w500, color: AppColors.gray900),
            onChanged: (_) {},
          ),
          if (_total > 0) ...[
            const SizedBox(height: 16),
            PaginationBar(
              nPages: nPages,
              currentPage: _page,
              onPageChange: (p) {
                _page = p;
                _fetch();
              },
            ),
          ],
        ]),
      ),
      Container(
        color: AppColors.gray50,
        constraints: const BoxConstraints(minHeight: 400),
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        child: _loading
            ? SizedBox(
                height: 400,
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const AppSpinner(size: 36),
                  const SizedBox(width: 12),
                  Text('Loading orders...', style: AppText.poppins(size: 18, color: AppColors.gray600)),
                ]),
              )
            : _error != null
                ? SizedBox(
                    height: 400,
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(color: AppColors.red100, shape: BoxShape.circle),
                        child: const Icon(Icons.error_outline, size: 32, color: AppColors.red600),
                      ),
                      const SizedBox(height: 16),
                      Text('Something went wrong', style: AppText.poppins(size: 18, weight: FontWeight.w500, color: AppColors.gray900)),
                      const SizedBox(height: 8),
                      Text(_error!, textAlign: TextAlign.center, style: AppText.poppins(color: AppColors.gray600)),
                      const SizedBox(height: 24),
                      Material(
                        color: AppColors.bluntRed,
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          onTap: _fetch,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            child: Text('Try Again', style: AppText.poppins(weight: FontWeight.w500, color: Colors.white)),
                          ),
                        ),
                      ),
                    ]),
                  )
                : _orders.isEmpty
                    ? SizedBox(
                        height: 400,
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Container(
                            width: 96,
                            height: 96,
                            decoration: const BoxDecoration(color: AppColors.gray100, shape: BoxShape.circle),
                            child: const Icon(Icons.description_outlined, size: 48, color: AppColors.gray400),
                          ),
                          const SizedBox(height: 24),
                          Text('No pooja orders yet', style: AppText.poppins(size: 20, weight: FontWeight.w600, color: AppColors.gray900)),
                          const SizedBox(height: 8),
                          Text(
                            'Your pooja orders will appear here once you make a purchase. Start shopping to see your order history!',
                            textAlign: TextAlign.center,
                            style: AppText.poppins(color: AppColors.gray600),
                          ),
                        ]),
                      )
                    : Column(children: [
                        for (final o in _orders)
                          PoojaOrderCard(
                            order: o,
                            onViewDetails: () => context.push('/user/orders/${str(o['_id'])}'),
                            onPayRemaining: () => _payRemaining(o),
                          ),
                      ]),
      ),
    ]);
  }
}

/// OrderComponent/PoojaOrderListComponent.jsx
class PoojaOrderCard extends StatelessWidget {
  const PoojaOrderCard({super.key, required this.order, required this.onViewDetails, required this.onPayRemaining});
  final Json order;
  final VoidCallback onViewDetails;
  final VoidCallback onPayRemaining;

  static (String, Color, Color)? statusChip(int s) => switch (s) {
        0 => ('PENDING', AppColors.pendingColor, AppColors.pendingBg),
        2 => ('ACCEPTED', AppColors.acceptedColor, AppColors.acceptedBg),
        3 => ('COMPLETED', AppColors.cancelledColor, AppColors.cancelledBg),
        4 => ('CANCELLED', AppColors.defaultText, AppColors.completedBg),
        1 => ('CANCELLED', AppColors.defaultText, Colors.transparent),
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final fb = obj(order['financialBreakdown']);
    final paid = numOf(fb['amountPaid']);
    final remaining = numOf(fb['remainingAmount']);
    final total = numOf(fb['totalEffectiveAmount']);
    final coupon = numOf(fb['couponDiscount']);
    final isFull = str(fb['paymentStatus'], 'PENDING') == 'FULL';
    final status = intOf(order['poojaOrderStatus'], -1);
    final cancelled = status == 1 || status == 4;
    final chip = statusChip(status);
    final media = strOrNull(pick(order, ['pooja', 'media', 0, 'mediaUrl']));
    final date = strOrNull(order['rescheduledBookingDate']) ?? str(order['bookingDate']);
    final slot = strOrNull(order['rescheduledBookingTimeSlot']) ?? str(order['bookingTimeSlot']);

    Widget stat(String l, String v, Color c) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l, style: AppText.poppins(size: 12, color: AppColors.headerQuote)),
          const SizedBox(height: 2),
          Text(v, style: AppText.poppins(size: 12, weight: FontWeight.w600, color: c)),
        ]);
    Widget sep() => Text('|', style: AppText.poppins(size: 12, color: AppColors.gray300));

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
      child: Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.profileBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0x268993AC)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (chip != null)
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(color: chip.$3, borderRadius: BorderRadius.circular(16)),
                child: Text(chip.$1, style: AppText.sans(size: 12, weight: FontWeight.w500, color: chip.$2)),
              ),
            ),
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 48,
              height: 48,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(color: const Color(0xFF4ADE80), borderRadius: BorderRadius.circular(8)),
              child: SiteImage(media ?? '/images/aigenerated/Deities.jpeg'),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(str(pick(order, ['pooja', 'name'])),
                  style: AppText.poppins(size: 14, weight: FontWeight.w600, color: AppColors.defaultText, height: 20 / 14)),
            ),
          ]),
          if (total > 0)
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.only(top: 12),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0x268993AC)))),
              child: Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
                stat('Order Total', '₹${toLocale(total)}', AppColors.gray800),
                sep(),
                stat('You Paid', '₹${toLocale(paid)}', AppColors.green600),
                if (coupon > 0) ...[sep(), stat('Coupon Savings', '- ₹${toLocale(coupon)}', AppColors.amber600)],
                if (remaining > 0 && !cancelled) ...[sep(), stat('Balance Due', '₹${toLocale(remaining)}', AppColors.red600)],
                if (isFull) ...[
                  sep(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.green100, borderRadius: BorderRadius.circular(999)),
                    child: Text('Fully Paid ✓', style: AppText.poppins(size: 10, weight: FontWeight.w500, color: AppColors.green700)),
                  ),
                ],
              ]),
            ),
          const SizedBox(height: 16),
          _labelValue('Performing Date', date),
          const SizedBox(height: 16),
          _labelValue('Performing Time', slot),
          const SizedBox(height: 16),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            if (status == 3)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const StarRow(rating: 5),
                  GestureDetector(
                    onTap: () => context.push('/user/orders/${str(order['_id'])}?type=review'),
                    child: Text('Write a Review', style: AppText.poppins(size: 12, color: const Color(0xFF0044FF), height: 1.5)),
                  ),
                ]),
              ),
            const Spacer(),
            GestureDetector(
              onTap: onViewDetails,
              child: Row(children: [
                Text(' View Details', style: AppText.poppins(size: 12, weight: FontWeight.w500, color: AppColors.bluntRed, height: 1.5)),
                const SizedBox(width: 8),
                const SiteImage('/icons/right-arrow.svg', width: 10, height: 10, placeholderColor: Colors.transparent),
              ]),
            ),
          ]),
          if (remaining > 0 && !cancelled)
            Padding(
              padding: const EdgeInsets.only(top: 28),
              child: Material(
                color: AppColors.bluntRed,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: onPayRemaining,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text('PAY REMAINING AMOUNT — ₹${toLocale(remaining)}',
                        textAlign: TextAlign.center, style: AppText.poppins(size: 14, color: Colors.white)),
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _labelValue(String l, String v) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l, style: AppText.poppins(size: 12, color: AppColors.headerQuote)),
        const SizedBox(height: 4),
        Text(v, style: AppText.poppins(size: 12, weight: FontWeight.w500, color: AppColors.defaultText)),
      ]);
}
