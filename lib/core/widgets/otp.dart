import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'fieldset.dart';
import 'site_image.dart';
import 'toast.dart';

/// react-otp-input with the website's inline style: N boxes 32×32, 1px
/// slate border, 8px gap.
class OtpBoxes extends StatefulWidget {
  const OtpBoxes({super.key, required this.onChanged, this.length = 6, this.boxSize = 32, this.gap = 8, this.autofocus = true});
  final ValueChanged<String> onChanged;
  final int length;
  final double boxSize;
  final double gap;
  final bool autofocus;

  @override
  State<OtpBoxes> createState() => _OtpBoxesState();
}

class _OtpBoxesState extends State<OtpBoxes> {
  final _c = TextEditingController();
  final _f = FocusNode();

  @override
  void dispose() {
    _c.dispose();
    _f.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = _c.text;
    return GestureDetector(
      onTap: () => _f.requestFocus(),
      child: Stack(children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < widget.length; i++)
            Container(
              width: widget.boxSize,
              height: widget.boxSize,
              margin: EdgeInsets.only(right: i == widget.length - 1 ? 0 : widget.gap),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: i == v.length && _f.hasFocus ? AppColors.blue500 : AppColors.headerQuote),
              ),
              child: Text(i < v.length ? v[i] : '', style: AppText.poppins(size: 16, color: AppColors.defaultText)),
            ),
        ]),
        Positioned.fill(
          child: Opacity(
            opacity: 0,
            child: TextField(
              controller: _c,
              focusNode: _f,
              autofocus: widget.autofocus,
              keyboardType: TextInputType.number,
              maxLength: widget.length,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              autofillHints: const [AutofillHints.oneTimeCode],
              onChanged: (s) {
                setState(() {});
                widget.onChanged(s);
              },
              decoration: const InputDecoration(counterText: '', border: InputBorder.none),
            ),
          ),
        ),
      ]),
    );
  }
}

/// FormComponents/InputWithOTPComponent.jsx — fieldset input + Send OTP /
/// 50 s resend timer + OTP boxes + VERIFY OTP.
class InputWithOtp extends StatefulWidget {
  const InputWithOtp({
    super.key,
    required this.inputKey,
    required this.value,
    required this.onChanged,
    required this.sendOtp,
    required this.verifyOtp,
    this.isVerified = false,
    this.disabled = false,
  });

  final String inputKey;
  final String value;
  final ValueChanged<String> onChanged;
  final Future<void> Function(String key, String value) sendOtp;
  final Future<void> Function(String key, String value, String otp) verifyOtp;
  final bool isVerified;
  final bool disabled;

  @override
  State<InputWithOtp> createState() => _InputWithOtpState();
}

class _InputWithOtpState extends State<InputWithOtp> {
  int _timer = -1;
  Timer? _t;
  String _otp = '';
  String _error = '';
  late final _c = TextEditingController(text: widget.value);

  @override
  void dispose() {
    _t?.cancel();
    _c.dispose();
    super.dispose();
  }

  void _send() {
    if (_c.text.isEmpty) {
      Toast.error('Kindly Fill the required field');
      return;
    }
    widget.sendOtp(widget.inputKey, _c.text);
    setState(() => _timer = 50);
    _t?.cancel();
    _t = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _timer = _timer > 0 ? _timer - 1 : 0);
      if (_timer == 0) t.cancel();
    });
  }

  void _onChanged(String v) {
    widget.onChanged(v);
    setState(() {
      if (widget.inputKey == 'email') {
        _error = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v) ? '' : 'Invalid email address';
      } else if (widget.inputKey == 'phone') {
        _error = RegExp(r'^[6-9]\d{9}$').hasMatch(v) ? '' : 'Invalid mobile number';
      }
    });
  }

  Widget _red(String label, VoidCallback onTap, {double w = 80}) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: 32,
          width: w,
          margin: const EdgeInsets.only(top: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: AppColors.bluntRed, borderRadius: BorderRadius.circular(4)),
          child: Text(label, style: AppText.poppins(size: 12, color: Colors.white)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final showOtpUi = (widget.inputKey == 'email' || widget.inputKey == 'phone') && !widget.disabled && !widget.isVerified && _error.isEmpty;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextField(
        controller: _c,
        enabled: !widget.disabled,
        onChanged: _onChanged,
        keyboardType: widget.inputKey == 'phone' ? TextInputType.phone : TextInputType.emailAddress,
        style: AppText.poppins(size: 14),
        decoration: fieldsetDecoration('${widget.inputKey.toUpperCase()} ', required: true, hint: 'Enter ${widget.inputKey}').copyWith(
          suffixIcon: widget.disabled || widget.isVerified
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SiteImage('/icons/tick.svg', width: 16, height: 16, placeholderColor: Colors.transparent),
                )
              : null,
        ),
      ),
      if (_error.isNotEmpty) Text(_error, style: AppText.poppins(size: 12, color: AppColors.red500)),
      if (showOtpUi) ...[
        Align(
          alignment: Alignment.centerRight,
          child: _timer == -1
              ? _red('Send OTP', _send)
              : _timer > 0
                  ? Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('Resend OTP in $_timer seconds ', style: AppText.poppins(size: 12)),
                    )
                  : _red('Resend OTP!', _send, w: 96),
        ),
        if (_timer != -1)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, spacing: 4, runSpacing: 8, children: [
              OtpBoxes(onChanged: (v) => setState(() => _otp = v)),
              if (_otp.length == 6)
                GestureDetector(
                  onTap: () => widget.verifyOtp(widget.inputKey, _c.text, _otp),
                  child: Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: AppColors.bluntRed, borderRadius: BorderRadius.circular(8)),
                    child: Text('VERIFY OTP', style: AppText.poppins(size: 14, color: Colors.white, letterSpacing: 1)),
                  ),
                ),
            ]),
          ),
      ],
    ]);
  }
}
