import 'package:carservice_customer/app/theme/app_surfaces.dart';
import 'package:carservice_customer/app/theme/app_theme.dart';
import 'package:carservice_customer/core/widgets/state_views.dart';
import 'package:carservice_customer/features/booking/auth/domain/auth_repository.dart';
import 'package:carservice_customer/features/profile/presentation/controllers/account_password_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

final _destructiveStyle = FilledButton.styleFrom(
  backgroundColor: AppColors.red,
  foregroundColor: Colors.white,
);

/// Set, change or remove the account password used by the login page's
/// "Нууц үгээр нэвтрэх". Every change is confirmed with a code sent to the
/// account's own phone, like account closure.
class AccountPasswordScreen extends StatefulWidget {
  const AccountPasswordScreen({
    required this.repository,
    this.onPasswordChanged,
    super.key,
  });

  final AuthRepository repository;

  /// Called after a successful save or removal with the new `hasPassword`.
  /// The router confirms it through the app's global message.
  final ValueChanged<bool>? onPasswordChanged;

  @override
  State<AccountPasswordScreen> createState() => _AccountPasswordScreenState();
}

class _AccountPasswordScreenState extends State<AccountPasswordScreen> {
  late final AccountPasswordController _controller = AccountPasswordController(
    widget.repository,
  )..load();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  var _obscurePassword = true;

  @override
  void dispose() {
    _controller.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: _controller.action == null ? null : _cancel,
        ),
        title: const Text('Нууц үг'),
      ),
      body: AppShellBackground(
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: _body(context),
          ),
        ),
      ),
    ),
  );

  Widget _body(BuildContext context) {
    final hasPassword = _controller.hasPassword;
    if (hasPassword == null) {
      if (_controller.loadError != null) {
        return ErrorView(
          message: _controller.loadError!,
          onRetry: _controller.load,
          retryKey: const ValueKey('password-retry'),
        );
      }
      return const Padding(
        padding: EdgeInsets.only(top: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final action = _controller.action;
    if (action == null) return _overview(context, hasPassword);
    return _ActionStep(
      title: switch (action) {
        PasswordAction.save =>
          hasPassword ? 'Нууц үг солих' : 'Нууц үг тохируулах',
        PasswordAction.remove => 'Нууц үг устгах',
      },
      destructive: action == PasswordAction.remove,
      askPassword: action == PasswordAction.save,
      maskedPhone: _controller.maskedPhone,
      isBusy: _controller.isBusy,
      errorMessage: _controller.errorMessage,
      codeController: _codeController,
      passwordController: _passwordController,
      confirmationController: _confirmationController,
      obscurePassword: _obscurePassword,
      onToggleObscure: () =>
          setState(() => _obscurePassword = !_obscurePassword),
      onRequestOtp: _controller.requestOtp,
      onConfirm: _confirm,
    );
  }

  Widget _overview(BuildContext context, bool hasPassword) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GlassSurface(
          key: const ValueKey('password-status'),
          child: Row(
            children: [
              Icon(
                hasPassword ? Icons.lock_outline : Icons.lock_open_outlined,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  hasPassword
                      ? 'Нууц үг тохируулсан. Утасны дугаар, нууц үгээрээ эсвэл '
                            'SMS кодоор нэвтэрнэ.'
                      : 'Нууц үг тохируулаагүй. Одоогоор зөвхөн SMS кодоор '
                            'нэвтэрнэ.',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _OptionCard(
          key: const ValueKey('password-action-save'),
          title: hasPassword ? 'Нууц үг солих' : 'Нууц үг тохируулах',
          description: hasPassword
              ? 'Одоогийн нууц үгийг шинээр солино.'
              : 'Дараа нь кодгүйгээр, утасны дугаар болон нууц үгээрээ '
                    'нэвтэрнэ.',
          destructive: false,
          onTap: () => _start(PasswordAction.save),
        ),
        if (hasPassword) ...[
          const SizedBox(height: 12),
          _OptionCard(
            key: const ValueKey('password-action-remove'),
            title: 'Нууц үг устгах',
            description: 'Цаашид зөвхөн SMS кодоор нэвтэрнэ.',
            destructive: true,
            onTap: () => _start(PasswordAction.remove),
          ),
        ],
      ],
    );
  }

  void _start(PasswordAction action) {
    _clearInputs();
    _controller.start(action);
  }

  void _cancel() {
    _clearInputs();
    _controller.cancel();
  }

  void _clearInputs() {
    _codeController.clear();
    _passwordController.clear();
    _confirmationController.clear();
    _obscurePassword = true;
  }

  Future<void> _confirm() async {
    final success = await _controller.submit(
      code: _codeController.text,
      password: _passwordController.text,
      confirmation: _confirmationController.text,
    );
    if (!success || !mounted) return;
    _clearInputs();
    widget.onPasswordChanged?.call(_controller.hasPassword ?? false);
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.title,
    required this.description,
    required this.destructive,
    required this.onTap,
    super.key,
  });

  final String title;
  final String description;
  final bool destructive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassSurface(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: destructive ? scheme.error : null,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _ActionStep extends StatelessWidget {
  const _ActionStep({
    required this.title,
    required this.destructive,
    required this.askPassword,
    required this.maskedPhone,
    required this.isBusy,
    required this.errorMessage,
    required this.codeController,
    required this.passwordController,
    required this.confirmationController,
    required this.obscurePassword,
    required this.onToggleObscure,
    required this.onRequestOtp,
    required this.onConfirm,
  });

  final String title;
  final bool destructive;
  final bool askPassword;
  final String? maskedPhone;
  final bool isBusy;
  final String? errorMessage;
  final TextEditingController codeController;
  final TextEditingController passwordController;
  final TextEditingController confirmationController;
  final bool obscurePassword;
  final VoidCallback onToggleObscure;
  final Future<bool> Function() onRequestOtp;
  final Future<void> Function() onConfirm;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final error = errorMessage == null
        ? null
        : Text(
            errorMessage!,
            key: const ValueKey('password-error'),
            style: TextStyle(color: scheme.error),
          );
    return GlassSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: destructive ? scheme.error : null,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Бүртгэлтэй утсанд тань баталгаажуулах код илгээнэ.',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          if (maskedPhone == null) ...[
            if (error != null) ...[error, const SizedBox(height: 12)],
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const ValueKey('password-request-otp'),
                style: destructive ? _destructiveStyle : null,
                onPressed: isBusy ? null : onRequestOtp,
                child: _label(isBusy, 'Код авах'),
              ),
            ),
          ] else ...[
            Text('$maskedPhone руу код илгээлээ'),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('password-code'),
              controller: codeController,
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
            if (askPassword) ...[
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('password-new'),
                controller: passwordController,
                obscureText: obscurePassword,
                autofillHints: const [AutofillHints.newPassword],
                decoration: InputDecoration(
                  labelText: 'Шинэ нууц үг',
                  helperText: '8–128 тэмдэгт, үсэг болон тоо агуулсан',
                  suffixIcon: IconButton(
                    tooltip: obscurePassword
                        ? 'Нууц үг харуулах'
                        : 'Нууц үг нуух',
                    icon: Icon(
                      obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: onToggleObscure,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('password-confirmation'),
                controller: confirmationController,
                obscureText: obscurePassword,
                autofillHints: const [AutofillHints.newPassword],
                decoration: const InputDecoration(labelText: 'Нууц үг давтах'),
              ),
            ],
            if (error != null) ...[const SizedBox(height: 12), error],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const ValueKey('password-submit'),
                style: destructive ? _destructiveStyle : null,
                onPressed: isBusy ? null : onConfirm,
                child: _label(isBusy, destructive ? 'Устгах' : 'Хадгалах'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _label(bool busy, String text) => busy
      ? const SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
      : Text(text);
}
