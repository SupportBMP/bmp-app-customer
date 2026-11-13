import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api/api_client.dart';
import '../../core/api/bmp_api.dart';
import '../../core/state/app_state.dart';
import '../../core/storage/cookies.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/json.dart';
import '../../core/utils/launch.dart';
import '../../core/widgets/form_fields.dart';
import '../../core/widgets/native.dart';
import '../../core/widgets/otp.dart';
import '../../core/widgets/site_image.dart';
import '../../core/widgets/toast.dart';

/// pages/auth/index.jsx — phone OTP sign-in / sign-up, laid out as a native
/// mobile screen. The router sends every signed-out user here first.
///
/// The website gates "SEND OTP" behind reCAPTCHA v3 (`/api/registerFormSubmit`),
/// which only runs in a browser; the app sends the OTP straight through the
/// same relay.
class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key, this.redirect});
  final String? redirect;

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  static const _otpLength = 6;
  static const _phoneLength = 10;
  static const _resend = 60;

  bool _phoneInputVisible = true;
  bool _otpSent = false;
  String _error = '';
  String _phone = '';
  String _otp = '';
  bool _resendDisabled = false;
  int _countdown = _resend;
  bool _validNumber = false;
  int _otpRound = 0;
  bool _phoneVerified = false;
  bool _showAdditional = false;
  bool _loading = false;
  final _form = <String, String>{'userName': '', 'gender': '', 'dob': ''};
  Timer? _timer;
  final _phoneFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _phoneFocus.addListener(() {
      if (!_phoneFocus.hasFocus) {
        setState(() => _error = _phone.isNotEmpty && _phone.length < _phoneLength ? 'Please enter a valid 10-digit mobile number' : '');
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _phoneFocus.dispose();
    super.dispose();
  }

  ({bool ok, String error}) _validate(String p) {
    final n = p.replaceAll(RegExp(r'\D'), '');
    if (n.isEmpty) return (ok: false, error: 'Mobile number is required.');
    if (n.length != _phoneLength) return (ok: false, error: 'Mobile number must be 10 digits.');
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(n)) {
      return (ok: false, error: 'Please enter a valid Indian mobile number starting with 6-9.');
    }
    return (ok: true, error: '');
  }

  String _fmt(String p) => p.length != _phoneLength ? p : '+91-${p.substring(0, 3)}-${p.substring(3, 6)}-${p.substring(6)}';

  void _startCountdown() {
    _timer?.cancel();
    setState(() {
      _resendDisabled = true;
      _countdown = _resend;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        _countdown--;
        if (_countdown <= 0) {
          _resendDisabled = false;
          t.cancel();
        }
      });
    });
  }

  Future<void> _sendOtp() async {
    final v = _validate(_phone);
    if (!v.ok) {
      setState(() => _error = v.error);
      return;
    }
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final r = await BmpApi.sendPhoneOtp('+91-$_phone');
      final d = obj(r.data);
      if (r.statusCode == 201 && intOf(d['statusCode']) == 200) {
        Toast.success(strOrNull(d['message']) ?? 'OTP sent successfully');
        setState(() {
          _otp = '';
          _otpRound++;
          _phoneInputVisible = false;
          _otpSent = true;
        });
        _startCountdown();
      } else {
        throw Exception(strOrNull(d['message']) ?? 'Failed to send OTP');
      }
    } catch (e) {
      debugPrint('SEND OTP ERROR: $e');
      if (e is DioException) {
        debugPrint('STATUS: ${e.response?.statusCode}');
        debugPrint('BODY: ${e.response?.data}');
      }
      final msg = e is Exception && e.toString().startsWith('Exception: ')
          ? e.toString().substring(11)
          : apiErrorMessage(e, 'Error sending OTP');
      Toast.error(msg);
      setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyOtp() async {
    if (_otp.length != _otpLength) {
      setState(() => _error = 'Please enter a valid 6-digit OTP');
      return;
    }
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final r = await BmpApi.verifyPhoneOtp('+91-$_phone', _otp, null);
      final d = obj(r.data);
      if (r.statusCode == 201 && intOf(d['statusCode']) == 200) {
        Toast.success(strOrNull(d['message']) ?? 'OTP verified successfully');
        Cookies.set('accessToken', str(pick(d, ['body', 'accessToken'])));
        await _afterLogin();
      } else {
        throw Exception(strOrNull(d['error']) ?? 'Invalid OTP');
      }
    } catch (e) {
      final msg = e is Exception && e.toString().startsWith('Exception: ') ? e.toString().substring(11) : 'Invalid OTP. Please try again.';
      Toast.error(msg);
      setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _goRedirect() {
    ref.invalidate(authProvider);
    final path = widget.redirect != null && widget.redirect!.isNotEmpty ? Uri.decodeComponent(widget.redirect!) : '/';
    context.go(path.startsWith('/auth') ? '/' : path);
  }

  Future<void> _afterLogin() async {
    try {
      final r = await BmpApi.userDetails(Cookies.get('accessToken'));
      final d = obj(r.data);
      if (r.statusCode == 200 && intOf(d['statusCode']) == 200) {
        final u = obj(d['body']);
        final needsDetails = !boolOf(u['isEmailVerified']) && str(u['userName']).isEmpty;
        if (needsDetails) {
          Toast.success('Please complete your profile');
          setState(() => _showAdditional = true);
        } else {
          Toast.success('Login successful');
          _goRedirect();
        }
      } else {
        throw Exception();
      }
    } catch (_) {
      Toast.error('Failed to fetch user details');
    }
    if (mounted) {
      setState(() {
        _otp = '';
        _phoneVerified = true;
      });
    }
  }

  Future<void> _finish() async {
    final name = _form['userName']!.trim();
    if (name.isEmpty) return Toast.error('Name is required');
    if (name.length < 2) return Toast.error('Name must be at least 2 characters');
    if (_form['gender']!.isEmpty) return Toast.error('Gender is required');
    setState(() => _loading = true);
    try {
      final r = await BmpApi.updateUser({'userName': _form['userName'], 'gender': _form['gender'], 'dob': _form['dob'], 'email': ''});
      final d = obj(r.data);
      if (r.statusCode == 201 && intOf(d['statusCode']) == 200) {
        Toast.success(strOrNull(d['message']) ?? 'Profile updated successfully');
        _goRedirect();
      } else {
        throw Exception();
      }
    } catch (_) {
      Toast.error('Failed to update profile');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  bool get _verifying => _otpSent && !_phoneInputVisible;

  void _editNumber() => setState(() {
    _timer?.cancel();
    _phoneInputVisible = true;
    _otp = '';
    _error = '';
    _otpSent = false;
    _resendDisabled = false;
    _countdown = _resend;
  });

  @override
  Widget build(BuildContext context) {
    final step = _phoneVerified && _showAdditional ? 2 : (_verifying ? 1 : 0);
    final (title, subtitle) = switch (step) {
      0 => ('Welcome to BookMyPooja', 'Sign in or create your account with your mobile number.'),
      1 => ('Verify your number', 'Enter the 6-digit code sent to ${_fmt(_phone)}'),
      _ => ('Complete your profile', 'Tell us a little about yourself so our pandits can address you.'),
    };

    return PopScope(
      canPop: step != 1,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && step == 1) _editNumber();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          // Content on top, legal + help pinned to the bottom of a short page.
          // minHeight + spaceBetween does this without intrinsic measuring,
          // which LayoutBuilder-based children can't support.
          child: LayoutBuilder(
            builder: (context, box) => SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: box.maxHeight),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: 56,
                          child: step == 1
                              ? Align(
                                  alignment: Alignment.centerLeft,
                                  child: IconButton(
                                    tooltip: 'Change number',
                                    icon: Icon(Icons.adaptive.arrow_back),
                                    onPressed: _editNumber,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(height: 8),
                        const Center(
                          child: SizedBox(
                            width: 220,
                            height: 100,
                            child: SiteImage('/icons/book-my-pooja.svg', fit: BoxFit.contain, placeholderColor: Colors.transparent),
                          ),
                        ),
                        const SizedBox(height: 32),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: Column(
                            key: ValueKey(step),
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title, style: AppText.body(size: 26, weight: FontWeight.w700, letterSpacing: -.3)),
                              const SizedBox(height: 8),
                              Text(subtitle, style: AppText.body(size: 15, color: AppColors.mutedForeground, height: 1.4)),
                              const SizedBox(height: 28),
                              switch (step) {
                                0 => _phoneStep(),
                                1 => _otpStep(),
                                _ => _profileStep(),
                              },
                            ],
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 24),
                        _legal(),
                        TextButton.icon(
                          onPressed: () => callPhone(),
                          icon: const Icon(LucideIcons.phone, size: 16),
                          label: const Text('Need help? Call 9869 92 92 92'),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _primaryButton(String label, VoidCallback? onPressed) => SizedBox(
    height: 54,
    child: FilledButton(
      onPressed: _loading ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.bluntRed,
        disabledBackgroundColor: AppColors.bluntRed.withValues(alpha: .35),
        disabledForegroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: AppText.body(size: 16, weight: FontWeight.w600),
      ),
      child: _loading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator.adaptive(strokeWidth: 2.5, backgroundColor: Colors.white),
            )
          : Text(label),
    ),
  );

  Widget _phoneStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          focusNode: _phoneFocus,
          autofocus: true,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.telephoneNumberNational],
          maxLength: _phoneLength,
          inputFormatters: [digitsOnly],
          onChanged: (v) {
            final res = _validate(v);
            setState(() {
              _phone = v;
              _validNumber = res.ok;
              _error = v.length == _phoneLength ? res.error : '';
            });
          },
          onSubmitted: (_) => _validNumber ? _sendOtp() : null,
          style: AppText.body(size: 18, weight: FontWeight.w600, letterSpacing: 1.2),
          decoration: InputDecoration(
            labelText: 'Mobile number',
            labelStyle: AppText.body(size: 15, color: AppColors.mutedForeground),
            floatingLabelStyle: AppText.body(size: 15, color: AppColors.bluntRed),
            counterText: '',
            errorText: _error.isEmpty ? null : _error,
            filled: true,
            fillColor: AppColors.gray50,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 16, right: 8),
              child: Text('🇮🇳  +91', style: AppText.body(size: 18, weight: FontWeight.w600)),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
            suffixIcon: _validNumber ? const Icon(Icons.check_circle, color: AppColors.green600) : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.gray200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.bluntRed, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.destructive),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text("We'll send a one-time code by SMS to verify it's you.", style: AppText.body(size: 13, color: AppColors.mutedForeground)),
        const SizedBox(height: 24),
        _primaryButton('Send OTP', _validNumber ? _sendOtp : null),
      ],
    );
  }

  Widget _otpStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Sized from the screen; FittedBox shrinks the row on very narrow phones.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: OtpBoxes(
            key: ValueKey(_otpRound),
            boxSize: ((MediaQuery.sizeOf(context).width - 48 - 5 * 10) / 6).clamp(0, 56).toDouble(),
            gap: 10,
            onChanged: (v) {
              setState(() {
                _otp = v;
                _error = '';
              });
              if (v.length == _otpLength) _verifyOtp();
            },
          ),
        ),
        if (_error.isNotEmpty) ...[const SizedBox(height: 12), Text(_error, style: AppText.body(size: 13, color: AppColors.destructive))],
        const SizedBox(height: 16),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text("Didn't get the code?", style: AppText.body(size: 14, color: AppColors.mutedForeground)),
            const SizedBox(width: 4),
            TextButton(
              onPressed: _resendDisabled || _loading
                  ? null
                  : () {
                      setState(() {
                        _error = '';
                        _otp = '';
                      });
                      _sendOtp();
                    },
              child: Text(_resendDisabled ? 'Resend in ${_countdown}s' : 'Resend OTP'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _primaryButton('Verify & Continue', _otp.length == _otpLength ? _verifyOtp : null),
        const SizedBox(height: 8),
        TextButton(onPressed: _loading ? null : _editNumber, child: const Text('Use a different number')),
      ],
    );
  }

  Widget _profileStep() {
    InputDecoration deco(String label, {String? hint, Widget? suffix}) => InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: AppColors.gray50,
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.gray200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.bluntRed, width: 2),
      ),
    );
    const genders = [('male', 'Male'), ('female', 'Female'), ('others', 'Others')];
    final gender = _form['gender']!;
    final dob = _form['dob']!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: AppColors.green50, borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              const Icon(Icons.verified, color: AppColors.green600, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${_fmt(_phone)} verified',
                  style: AppText.body(size: 14, weight: FontWeight.w600, color: AppColors.green700),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          textCapitalization: TextCapitalization.words,
          autofillHints: const [AutofillHints.name],
          onChanged: (v) => _form['userName'] = v,
          style: AppText.body(size: 16),
          decoration: deco('Full name', hint: 'Enter your full name'),
        ),
        const SizedBox(height: 20),
        Text(
          'Gender',
          style: AppText.body(size: 14, weight: FontWeight.w600, color: AppColors.mutedForeground),
        ),
        const SizedBox(height: 8),
        if (useCupertino(context))
          CupertinoSlidingSegmentedControl<String>(
            groupValue: gender.isEmpty ? null : gender,
            children: {for (final g in genders) g.$1: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(g.$2))},
            onValueChanged: (v) => setState(() => _form['gender'] = v ?? ''),
          )
        else
          SegmentedButton<String>(
            emptySelectionAllowed: true,
            showSelectedIcon: false,
            segments: [for (final g in genders) ButtonSegment(value: g.$1, label: Text(g.$2))],
            selected: gender.isEmpty ? const {} : {gender},
            onSelectionChanged: (v) => setState(() => _form['gender'] = v.isEmpty ? '' : v.first),
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: AppColors.bluntRed.withValues(alpha: .1),
              selectedForegroundColor: AppColors.bluntRed,
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        const SizedBox(height: 20),
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () async {
            final d = await showNativeDatePicker(
              context,
              initialDate: DateTime(2000),
              firstDate: DateTime(1900),
              lastDate: DateTime.now(),
              title: 'Date of birth',
            );
            if (d != null) setState(() => _form['dob'] = DateFormat('yyyy-MM-dd').format(d));
          },
          child: InputDecorator(
            decoration: deco('Date of birth (optional)', suffix: const Icon(LucideIcons.calendar, size: 18)),
            isEmpty: dob.isEmpty,
            child: Text(dob.isEmpty ? '' : DateFormat('d MMMM y').format(DateTime.parse(dob)), style: AppText.body(size: 16)),
          ),
        ),
        const SizedBox(height: 28),
        _primaryButton('Finish', _finish),
      ],
    );
  }

  Widget _legal() {
    final base = AppText.body(size: 12, color: AppColors.mutedForeground, height: 1.5);
    final link = base.copyWith(color: AppColors.bluntRed, fontWeight: FontWeight.w600);
    return Text.rich(
      TextSpan(
        children: [
          const TextSpan(text: 'By continuing, you agree to our '),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: GestureDetector(
              onTap: () => context.push('/terms-and-conditions'),
              child: Text('Terms & Conditions', style: link),
            ),
          ),
          const TextSpan(text: ' and '),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: GestureDetector(
              onTap: () => context.push('/privacy-policy'),
              child: Text('Privacy Policy', style: link),
            ),
          ),
          const TextSpan(text: '.'),
        ],
      ),
      textAlign: TextAlign.center,
      style: base,
    );
  }
}
