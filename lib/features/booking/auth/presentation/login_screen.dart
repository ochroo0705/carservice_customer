import 'dart:async';

import 'package:carservice_customer/app/theme/app_surfaces.dart';
import 'package:carservice_customer/app/theme/app_theme.dart';
import 'package:carservice_customer/features/booking/auth/presentation/auth_controller.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

/// Phone + OTP login, mirroring the web customer login page's copy and
/// step structure (static title/subtitle over a card whose form content
/// swaps between the phone step and the code step), with phone + password
/// as an alternative to the code for accounts that set a password.
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

  /// Open the bundled legal pages from the code step's terms line.
  final VoidCallback onOpenTerms;
  final VoidCallback onOpenPrivacy;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _resendCooldownSeconds = 60;

  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  var _obscurePassword = true;
  Timer? _resendTimer;
  int _resendSecondsRemaining = 0;
  late final TapGestureRecognizer _termsTap = TapGestureRecognizer()..onTap = widget.onOpenTerms;
  late final TapGestureRecognizer _privacyTap = TapGestureRecognizer()
    ..onTap = widget.onOpenPrivacy;

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
    _resendTimer?.cancel();
    _phoneController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AuthController>();
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: widget.onBack),
        title: const CarserviceBrand(compact: true),
        centerTitle: false,
      ),
      body: AppShellBackground(
        child: SafeArea(
          top: false,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: GlassSurface(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        // Password login never creates an account.
                        controller.step == AuthStep.password
                            ? 'Нэвтрэх'
                            : 'Нэвтрэх / Бүртгүүлэх',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        switch (controller.step) {
                          AuthStep.phone =>
                            'Утасны дугаараа оруулаад, ирэх 6 оронтой кодоор нэвтэрнэ.',
                          AuthStep.otp =>
                            '${controller.phone} дугаарт ирсэн 6 оронтой кодоо оруулна уу.',
                          AuthStep.password => 'Утасны дугаар, нууц үгээрээ нэвтэрнэ.',
                        },
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 24),
                      if (controller.step == AuthStep.phone)
                        _phoneField()
                      else if (controller.step == AuthStep.password)
                        // One group so password managers offer and save the
                        // phone + password pair together.
                        AutofillGroup(
                          child: Column(
                            children: [
                              _phoneField(),
                              const SizedBox(height: 12),
                              TextField(
                                key: const ValueKey('login-password'),
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                autofillHints: const [AutofillHints.password],
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => controller.isBusy ? null : _submit(),
                                decoration: InputDecoration(
                                  labelText: 'Нууц үг',
                                  suffixIcon: IconButton(
                                    tooltip: _obscurePassword ? 'Нууц үг харуулах' : 'Нууц үг нуух',
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
                            ],
                          ),
                        )
                      else
                        TextField(
                          key: const ValueKey('login-otp'),
                          controller: _codeController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          autofillHints: const [AutofillHints.oneTimeCode],
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(letterSpacing: 8, fontWeight: FontWeight.w700),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Баталгаажуулах код',
                            hintText: '000000',
                          ),
                        ),
                      if (controller.errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          controller.errorMessage!,
                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                        ),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed:
                              controller.isBusy ||
                                  (controller.step == AuthStep.phone && _resendSecondsRemaining > 0)
                              ? null
                              : _submit,
                          child: controller.isBusy
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Text(
                                  controller.step == AuthStep.phone ? 'Код авах →' : 'Нэвтрэх →',
                                ),
                        ),
                      ),
                      if (controller.step == AuthStep.phone)
                        Center(
                          child: TextButton(
                            key: const ValueKey('login-use-password'),
                            onPressed: controller.isBusy ? null : controller.usePassword,
                            child: const Text('Нууц үгээр нэвтрэх'),
                          ),
                        ),
                      if (controller.step == AuthStep.password) ...[
                        const SizedBox(height: 12),
                        _TermsNotice(termsTap: _termsTap, privacyTap: _privacyTap),
                        const SizedBox(height: 4),
                        Center(
                          child: TextButton(
                            key: const ValueKey('login-use-otp'),
                            onPressed: controller.isBusy ? null : controller.useOtp,
                            child: const Text('← Кодоор нэвтрэх'),
                          ),
                        ),
                        Text(
                          'Нууц үгээ мартсан бол кодоор нэвтэрч, Профайл → Нууц үг '
                          'хэсгээс шинээр тохируулна.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      if (controller.step == AuthStep.otp) ...[
                        const SizedBox(height: 12),
                        _TermsNotice(termsTap: _termsTap, privacyTap: _privacyTap),
                        const SizedBox(height: 4),
                        Center(
                          child: TextButton(
                            onPressed: controller.isBusy || _resendSecondsRemaining > 0
                                ? null
                                : _resendOtp,
                            child: Text(_resendButtonLabel),
                          ),
                        ),
                        Center(
                          child: TextButton(
                            onPressed: controller.isBusy ? null : _editPhone,
                            child: const Text('← Өөр дугаар оруулах'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _phoneField() => TextField(
    key: const ValueKey('login-phone'),
    controller: _phoneController,
    keyboardType: TextInputType.phone,
    autofillHints: const [AutofillHints.telephoneNumber],
    inputFormatters: const [_MongolianPhoneFormatter()],
    decoration: const InputDecoration(
      labelText: 'Утасны дугаар',
      prefixText: '+976 ',
      hintText: '99112233',
    ),
  );

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

  String get _resendButtonLabel {
    if (_resendSecondsRemaining <= 0) return 'Код дахин авах';
    final minutes = _resendSecondsRemaining ~/ 60;
    final seconds = (_resendSecondsRemaining % 60).toString().padLeft(2, '0');
    return 'Код дахин авах ($minutes:$seconds)';
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
    final theme = Theme.of(context);
    final base = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      height: 1.5,
    );
    final link = base?.copyWith(
      color: AppColors.readable(AppColors.accent, theme.brightness),
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
    );
    return Text.rich(
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
    );
  }
}
