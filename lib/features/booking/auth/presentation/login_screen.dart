import 'dart:async';

import 'package:carservice_customer/app/theme/app_theme.dart';
import 'package:carservice_customer/core/widgets/cs_ui.dart';
import 'package:carservice_customer/features/booking/auth/presentation/auth_controller.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

/// Phone + OTP login (the CustPhone / CustOtp boards): a big +976 phone field,
/// then six code boxes, with phone + password as an alternative to the code
/// for accounts that set a password.
///
/// Closing the page after a successful sign-in is not this screen's job:
/// `CustomerNavigation` does it for every entry point, off the auth session.
class LoginScreen extends StatefulWidget {
  const LoginScreen({
    required this.onBack,
    required this.onOpenTerms,
    required this.onOpenPrivacy,
    super.key,
  });

  final VoidCallback onBack;

  /// Open the bundled legal pages from the terms line.
  final VoidCallback onOpenTerms;
  final VoidCallback onOpenPrivacy;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _resendCooldownSeconds = 60;
  static const _codeLength = 6; // AuthController.verifyOtp expects 6 digits

  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneFocus = FocusNode();
  final _codeFocus = FocusNode();
  var _obscurePassword = true;
  Timer? _resendTimer;
  int _resendSecondsRemaining = 0;
  late final TapGestureRecognizer _termsTap = TapGestureRecognizer()..onTap = widget.onOpenTerms;
  late final TapGestureRecognizer _privacyTap = TapGestureRecognizer()
    ..onTap = widget.onOpenPrivacy;
  late final TapGestureRecognizer _changePhoneTap = TapGestureRecognizer()
    ..onTap = () {
      if (!context.read<AuthController>().isBusy) _editPhone();
    };

  @override
  void initState() {
    super.initState();
    // Every login page starts on the phone step. Silent (no notify), so it is
    // safe here, and verifyOtp leaves the code step up until the page closes.
    context.read<AuthController>().resetFlow();
  }

  @override
  void dispose() {
    _termsTap.dispose();
    _privacyTap.dispose();
    _changePhoneTap.dispose();
    _resendTimer?.cancel();
    _phoneController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _phoneFocus.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AuthController>();
    final theme = CarserviceTheme.of(context);
    final step = controller.step;
    final subtitleStyle = TextStyle(fontSize: 15, height: 22 / 15, color: theme.mutedText);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                  sliver: SliverFillRemaining(
                    hasScrollBody: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CsCircleButton.back(context, onPressed: widget.onBack),
                        const SizedBox(height: 24),
                        Text(
                          switch (step) {
                            AuthStep.phone => 'Утасны дугаараа оруулна уу',
                            AuthStep.otp => 'Кодоо оруулна уу',
                            // Password login never creates an account.
                            AuthStep.password => 'Нэвтрэх',
                          },
                          style: TextStyle(
                            fontSize: 28,
                            height: 34 / 28,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 28 * -0.02,
                            color: theme.ink,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (step == AuthStep.otp)
                          Text.rich(
                            TextSpan(
                              style: subtitleStyle,
                              children: [
                                TextSpan(
                                  text: '+976 ${_groupPhone(controller.phone)}',
                                  style: TextStyle(color: theme.ink, fontWeight: FontWeight.w600),
                                ),
                                const TextSpan(text: ' руу 6 оронтой код илгээлээ. '),
                                TextSpan(
                                  text: 'Дугаар солих',
                                  style: TextStyle(color: theme.link, fontWeight: FontWeight.w500),
                                  recognizer: _changePhoneTap,
                                ),
                              ],
                            ),
                          )
                        else
                          Text(
                            step == AuthStep.phone
                                ? 'Бид таны дугаарт 6 оронтой баталгаажуулах код илгээнэ. '
                                      'Бүртгэлгүй бол шинээр бүртгэнэ.'
                                : 'Утасны дугаар, нууц үгээрээ нэвтэрнэ.',
                            style: subtitleStyle,
                          ),
                        const SizedBox(height: 24),
                        if (step == AuthStep.phone)
                          _labeled('Утасны дугаар', _phoneField())
                        else if (step == AuthStep.password)
                          // One group so password managers offer and save the
                          // phone + password pair together.
                          AutofillGroup(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _labeled('Утасны дугаар', _phoneField()),
                                const SizedBox(height: 16),
                                _labeled(
                                  'Нууц үг',
                                  TextField(
                                    key: const ValueKey('login-password'),
                                    controller: _passwordController,
                                    obscureText: _obscurePassword,
                                    autofillHints: const [AutofillHints.password],
                                    textInputAction: TextInputAction.done,
                                    onSubmitted: (_) => controller.isBusy ? null : _submit(),
                                    style: const TextStyle(fontSize: 16),
                                    decoration: InputDecoration(
                                      hintText: 'Нууц үг',
                                      suffixIcon: IconButton(
                                        tooltip: _obscurePassword
                                            ? 'Нууц үг харуулах'
                                            : 'Нууц үг нуух',
                                        icon: Icon(
                                          _obscurePassword
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined,
                                        ),
                                        onPressed: () =>
                                            setState(() => _obscurePassword = !_obscurePassword),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          _codeBoxes(hasError: controller.errorMessage != null),
                        if (controller.errorMessage != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            controller.errorMessage!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontSize: 14,
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed:
                                controller.isBusy ||
                                    (step == AuthStep.phone && _resendSecondsRemaining > 0)
                                ? null
                                : _submit,
                            child: controller.isBusy
                                ? const SizedBox.square(
                                    dimension: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.onAccent,
                                    ),
                                  )
                                : Text(step == AuthStep.phone ? 'Код авах →' : 'Нэвтрэх →'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (step == AuthStep.phone)
                          Center(
                            child: TextButton(
                              key: const ValueKey('login-use-password'),
                              onPressed: controller.isBusy ? null : controller.usePassword,
                              style: TextButton.styleFrom(foregroundColor: theme.ink),
                              child: const Text('Нууц үгээр нэвтрэх'),
                            ),
                          ),
                        if (step == AuthStep.otp)
                          SizedBox(
                            width: double.infinity,
                            child: Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  'Код ирээгүй юу?',
                                  style: TextStyle(fontSize: 14, color: theme.mutedText),
                                ),
                                TextButton(
                                  onPressed: controller.isBusy || _resendSecondsRemaining > 0
                                      ? null
                                      : _resendOtp,
                                  child: _resendLabel(theme),
                                ),
                              ],
                            ),
                          ),
                        if (step == AuthStep.password) ...[
                          Center(
                            child: TextButton(
                              key: const ValueKey('login-use-otp'),
                              onPressed: controller.isBusy ? null : controller.useOtp,
                              style: TextButton.styleFrom(foregroundColor: theme.ink),
                              child: const Text('← Кодоор нэвтрэх'),
                            ),
                          ),
                          SizedBox(
                            width: double.infinity,
                            child: Text(
                              'Нууц үгээ мартсан бол кодоор нэвтэрч, Профайл → Нууц үг '
                              'хэсгээс шинээр тохируулна.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, height: 1.5, color: theme.mutedText),
                            ),
                          ),
                        ],
                        const Spacer(),
                        const SizedBox(height: 24),
                        _TermsNotice(termsTap: _termsTap, privacyTap: _privacyTap),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _labeled(String label, Widget field) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      const SizedBox(height: 8),
      field,
    ],
  );

  /// The 64px "+976 | 9911 2233" field; the ink outline and halo show focus.
  Widget _phoneField() {
    final theme = CarserviceTheme.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([_phoneFocus, _phoneController]),
      builder: (context, child) {
        final focused = _phoneFocus.hasFocus;
        final complete = _phoneController.text.length == 8;
        return GestureDetector(
          onTap: _phoneFocus.requestFocus,
          child: Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: theme.card,
              borderRadius: BorderRadius.circular(AppRadii.card),
              border: Border.all(
                color: focused ? theme.ink : theme.cardBorder,
                width: focused ? 2 : 1,
              ),
              boxShadow: focused
                  ? [BoxShadow(color: theme.ink.withValues(alpha: 0.10), spreadRadius: 4)]
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    border: Border(right: BorderSide(color: theme.cardBorder)),
                  ),
                  child: Text('+976', style: csMono(fontSize: 16, color: theme.ink)),
                ),
                const SizedBox(width: 12),
                Expanded(child: child!),
                if (complete)
                  ExcludeSemantics(
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        color: AppColors.greenLightText,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_rounded, size: 15, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
      child: TextField(
        key: const ValueKey('login-phone'),
        controller: _phoneController,
        focusNode: _phoneFocus,
        keyboardType: TextInputType.phone,
        autofillHints: const [AutofillHints.telephoneNumber],
        inputFormatters: const [_MongolianPhoneFormatter()],
        style: csMono(fontSize: 22, color: theme.ink, letterSpacing: 22 * 0.04),
        cursorColor: theme.ink,
        decoration: InputDecoration(
          isCollapsed: true,
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          hintText: '99112233',
          hintStyle: csMono(
            fontSize: 22,
            color: theme.mutedText.withValues(alpha: 0.5),
            letterSpacing: 22 * 0.04,
          ),
        ),
      ),
    );
  }

  /// Six 64px code boxes drawn under one transparent [TextField], which still
  /// takes the typing, paste and one-time-code autofill.
  Widget _codeBoxes({required bool hasError}) {
    final errorColor = Theme.of(context).colorScheme.error;
    return SizedBox(
      height: 64,
      child: Stack(
        children: [
          ExcludeSemantics(
            child: ListenableBuilder(
              listenable: Listenable.merge([_codeFocus, _codeController]),
              builder: (context, _) {
                final code = _codeController.text;
                final focused = _codeFocus.hasFocus;
                return Row(
                  children: [
                    for (var i = 0; i < _codeLength; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(
                        child: _CodeBox(
                          digit: i < code.length ? code[i] : '',
                          active:
                              focused &&
                              (i == code.length ||
                                  (code.length == _codeLength && i == _codeLength - 1)),
                          borderColor: hasError ? errorColor : null,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
          Positioned.fill(
            child: TextField(
              key: const ValueKey('login-otp'),
              controller: _codeController,
              focusNode: _codeFocus,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              showCursor: false,
              cursorColor: Colors.transparent,
              style: const TextStyle(color: Colors.transparent, fontSize: 1),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(_codeLength),
              ],
              decoration: const InputDecoration(
                // Read by screen readers; never visible.
                labelText: 'Баталгаажуулах код',
                labelStyle: TextStyle(color: Colors.transparent, fontSize: 1),
                floatingLabelBehavior: FloatingLabelBehavior.never,
                filled: false,
                isCollapsed: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                counterText: '',
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// "Код дахин авах (0:51)" with the countdown in Geist Mono.
  Widget _resendLabel(CarserviceTheme theme) {
    if (_resendSecondsRemaining <= 0) return const Text('Код дахин авах');
    final minutes = _resendSecondsRemaining ~/ 60;
    final seconds = (_resendSecondsRemaining % 60).toString().padLeft(2, '0');
    return Text.rich(
      TextSpan(
        children: [
          const TextSpan(text: 'Код дахин авах ('),
          TextSpan(
            text: '$minutes:$seconds',
            style: csMono(fontSize: 14, color: theme.ink),
          ),
          const TextSpan(text: ')'),
        ],
      ),
    );
  }

  static String _groupPhone(String phone) =>
      phone.length == 8 ? '${phone.substring(0, 4)} ${phone.substring(4)}' : phone;

  Future<void> _submit() async {
    final controller = context.read<AuthController>();
    final success = switch (controller.step) {
      AuthStep.phone => await controller.requestOtp(_phoneController.text),
      AuthStep.otp => await controller.verifyOtp(_codeController.text),
      AuthStep.password => await controller.loginWithPassword(
        _phoneController.text,
        _passwordController.text,
      ),
    };
    if (success && controller.step == AuthStep.otp && !controller.isAuthenticated && mounted) {
      _startResendCooldown();
    }
  }

  Future<void> _resendOtp() async {
    final controller = context.read<AuthController>();
    if (_resendSecondsRemaining > 0 || controller.isBusy) return;
    final success = await controller.requestOtp(controller.phone);
    if (success && mounted) _startResendCooldown();
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    setState(() => _resendSecondsRemaining = _resendCooldownSeconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _resendSecondsRemaining--;
        if (_resendSecondsRemaining <= 0) {
          _resendSecondsRemaining = 0;
          timer.cancel();
        }
      });
    });
  }

  void _editPhone() {
    // Keep the resend cooldown ticking (do not cancel/reset the timer) so
    // backing out and re-entering the code step can't be used to dodge it.
    context.read<AuthController>().editPhone();
  }
}

class _CodeBox extends StatelessWidget {
  const _CodeBox({required this.digit, required this.active, this.borderColor});

  final String digit;
  final bool active;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    final filled = digit.isNotEmpty;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(
          color: borderColor ?? (active || filled ? theme.ink : theme.cardBorder),
          width: active ? 2 : 1,
        ),
      ),
      child: Text(
        digit,
        style: csMono(fontSize: 26, fontWeight: FontWeight.w500, color: theme.ink),
      ),
    );
  }
}

/// Keeps the phone field to the 8-digit local number. Pasted or autofilled
/// numbers often carry the country code ("+976 9911 2233"); a plain
/// digits-then-truncate filter would turn that into "97699112". This strips
/// non-digits, then a leading 976 when the remainder is still too long.
class _MongolianPhoneFormatter extends TextInputFormatter {
  const _MongolianPhoneFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 8 && digits.startsWith('976')) {
      digits = digits.substring(3);
    }
    if (digits.length > 8) digits = digits.substring(0, 8);
    return TextEditingValue(
      text: digits,
      selection: TextSelection.collapsed(offset: digits.length),
    );
  }
}

/// "Нэвтэрснээр ... зөвшөөрнө" — signing in is the terms acceptance (recorded
/// by `AuthController.beforeSignIn`), so the names link to the bundled pages.
class _TermsNotice extends StatelessWidget {
  const _TermsNotice({required this.termsTap, required this.privacyTap});

  final TapGestureRecognizer termsTap;
  final TapGestureRecognizer privacyTap;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    final base = TextStyle(fontSize: 12, height: 1.5, color: theme.mutedText);
    final link = base.copyWith(
      color: theme.ink,
      fontWeight: FontWeight.w500,
      decoration: TextDecoration.underline,
      decorationColor: theme.ink,
    );
    return SizedBox(
      width: double.infinity,
      child: Text.rich(
        key: const ValueKey('login-terms-notice'),
        textAlign: TextAlign.center,
        TextSpan(
          style: base,
          children: [
            const TextSpan(text: 'Нэвтэрснээр та '),
            TextSpan(text: 'Үйлчилгээний нөхцөл', style: link, recognizer: termsTap),
            const TextSpan(text: ' болон '),
            TextSpan(text: 'Нууцлалын бодлого', style: link, recognizer: privacyTap),
            const TextSpan(text: '-г зөвшөөрч байна.'),
          ],
        ),
      ),
    );
  }
}
