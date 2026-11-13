import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/site_image.dart';

/// components/bookingComponent/BookingModal.jsx (success state). Shown after
/// payment verification; redirects to `/user/orders/<orderId>` after 7 s.
Future<void> showBookingSuccess(BuildContext context, {required String orderId, bool loading = false}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: AppColors.black40,
    pageBuilder: (ctx, _, _) => _BookingSuccess(orderId: orderId, loading: loading),
  );
}

class _BookingSuccess extends StatefulWidget {
  const _BookingSuccess({required this.orderId, required this.loading});
  final String orderId;
  final bool loading;

  @override
  State<_BookingSuccess> createState() => _BookingSuccessState();
}

class _BookingSuccessState extends State<_BookingSuccess> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    if (!widget.loading) {
      _t = Timer(const Duration(seconds: 7), () {
        if (!mounted) return;
        final router = GoRouter.of(context);
        Navigator.of(context).pop();
        router.push('/user/orders/${widget.orderId}');
      });
    }
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width >= 425 ? 344.0 : 324.0;
    return Center(
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: w,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Container(
                constraints: const BoxConstraints(minHeight: 291),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: Stack(children: [
                  const Positioned(left: 8, top: 8, child: SiteImage('/icons/Group 6937.svg', width: 40, height: 40, placeholderColor: Colors.transparent)),
                  const Positioned(left: -28, bottom: -20, child: SiteImage('/icons/floral-design-orange.svg', width: 80, height: 80, placeholderColor: Colors.transparent)),
                  const Positioned(right: -32, top: 64, child: SiteImage('/icons/floral-design-orange.svg', width: 64, height: 64, placeholderColor: Colors.transparent)),
                  Padding(
                    padding: const EdgeInsets.only(top: 68),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const SiteImage('/icons/book-my-pooja.svg', height: 64, fit: BoxFit.contain, placeholderColor: Colors.transparent),
                      const SizedBox(height: 8),
                      if (widget.loading)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 48),
                          child: Text('Processing your payment', style: AppText.poppins(color: AppColors.defaultText)),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(children: [
                            const SizedBox(height: 8),
                            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Text('Order Successful', style: AppText.poppins(size: 18, weight: FontWeight.w500, color: AppColors.slate600)),
                              const SizedBox(width: 8),
                              const SiteImage('/icons/tick.svg', width: 20, height: 20, placeholderColor: Colors.transparent),
                            ]),
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.slate50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.slate100),
                                boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 2, offset: Offset(0, 1))],
                              ),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('NEXT STEP',
                                    style: AppText.poppins(size: 14, weight: FontWeight.w700, color: AppColors.bluntRed, letterSpacing: .4)),
                                const SizedBox(height: 8),
                                Text('Assigning pandit ji to the following:',
                                    style: AppText.poppins(size: 12, weight: FontWeight.w500, color: AppColors.slate600)),
                                const SizedBox(height: 8),
                                for (final t in const ['Pandit ji assignment', 'Home preparation checklist'])
                                  Padding(
                                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                                    child: Row(children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(color: AppColors.bluntRed, shape: BoxShape.circle),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(t, style: AppText.poppins(size: 12, color: AppColors.slate800)),
                                    ]),
                                  ),
                                Container(
                                  padding: const EdgeInsets.only(top: 12),
                                  decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.slate200))),
                                  child: Text(
                                    'Priest assignment is underway. Home preparation checklist will also be shared to you within 24-48 hours, for complete readiness from your end.',
                                    style: AppText.poppins(size: 10, color: AppColors.slate500, height: 1.6),
                                  ),
                                ),
                              ]),
                            ),
                            const SizedBox(height: 24),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 24),
                              child: Text('Redirecting to Order Page ...',
                                  style: AppText.poppins(size: 10, weight: FontWeight.w500, color: AppColors.blue500)),
                            ),
                          ]),
                        ),
                    ]),
                  ),
                ]),
              ),
              Positioned(
                top: -40,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.gray200),
                    boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 15, offset: Offset(0, 10))],
                  ),
                  alignment: Alignment.center,
                  child: const SiteImage('/icons/Group6728.svg', width: 32, height: 28, placeholderColor: Colors.transparent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
