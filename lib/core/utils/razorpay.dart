import 'package:flutter/services.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../config.dart';
import 'json.dart';

/// What `displayRazorpay` resolves with on the website.
class RazorpayResult {
  RazorpayResult(this.paymentId, this.orderId, this.signature);
  final String paymentId;
  final String orderId;
  final String signature;
}

/// Thrown when checkout fails or is dismissed; [cancelled] mirrors the
/// website's `e.error.code === "PAYMENT_CANCELLED"` check.
class RazorpayFailure implements Exception {
  RazorpayFailure(this.code, this.message);
  final int? code;
  final String? message;
  bool get cancelled => code == Razorpay.PAYMENT_CANCELLED;

  /// A toast for anything but a user cancel; null when the user dismissed it.
  String? get toast => cancelled
      ? null
      : code == Razorpay.INVALID_OPTIONS && message != null
          ? message
          : 'Payment failed. Please try again.';
  @override
  String toString() => 'RazorpayFailure($code, $message)';
}

/// The razorpay_flutter plugin's channel. `Razorpay.open` is fire-and-forget
/// (`async void`): a platform exception there is swallowed and the caller
/// waits forever, so checkout is driven through the channel directly and
/// every outcome — success, failure, cancel, plugin error — returns here.
const _channel = MethodChannel('razorpay_flutter');

bool _open = false;

/// utils/utils.jsx `displayRazorpay` on the native Razorpay Android/iOS SDK
/// (standard checkout: UPI apps, cards, netbanking, wallets).
Future<RazorpayResult> displayRazorpay({
  required int amount,
  required String razorpayOrderId,
  Json? userData,
}) async {
  if (AppConfig.razorpayKey.isEmpty) {
    // Built without `--dart-define-from-file=env/prod.json`.
    throw RazorpayFailure(Razorpay.INVALID_OPTIONS, 'Payments are not configured in this build');
  }
  if (razorpayOrderId.isEmpty) throw RazorpayFailure(Razorpay.INVALID_OPTIONS, 'Missing payment order');
  if (_open) throw RazorpayFailure(Razorpay.PAYMENT_CANCELLED, 'Checkout already open');

  final name = strOrNull(userData?['username']) ?? strOrNull(userData?['userName']);
  final email = strOrNull(userData?['email']);
  final phone = strOrNull(userData?['phone']);

  _open = true;
  try {
    final reply = await _channel.invokeMethod<Map<dynamic, dynamic>>('open', {
      'key': AppConfig.razorpayKey,
      'amount': amount,
      'currency': 'INR',
      'name': 'BookMyPooja',
      'description': 'Transaction',
      'order_id': razorpayOrderId,
      'prefill': {'name': ?name, 'email': ?email, 'contact': ?phone},
      'theme': {'color': '#8A1C23'},
      'retry': {'enabled': true, 'max_count': 3},
      'send_sms_hash': true,
    });
    final data = reply?['data'];
    final d = data is Map ? data : const {};
    switch (reply?['type']) {
      case 0:
        return RazorpayResult(
          str(d['razorpay_payment_id']),
          strOrNull(d['razorpay_order_id']) ?? razorpayOrderId,
          str(d['razorpay_signature']),
        );
      case 1:
        throw RazorpayFailure(d['code'] is int ? d['code'] as int : Razorpay.UNKNOWN_ERROR, strOrNull(d['message']));
      case 2:
        // External wallet chosen: the website ignores it too.
        throw RazorpayFailure(Razorpay.PAYMENT_CANCELLED, 'External wallet: ${str(d['external_wallet'])}');
      default:
        throw RazorpayFailure(Razorpay.UNKNOWN_ERROR, 'No response from checkout');
    }
  } on PlatformException catch (e) {
    throw RazorpayFailure(Razorpay.UNKNOWN_ERROR, e.message ?? e.code);
  } on MissingPluginException catch (e) {
    throw RazorpayFailure(Razorpay.INCOMPATIBLE_PLUGIN, e.message);
  } finally {
    _open = false;
  }
}
