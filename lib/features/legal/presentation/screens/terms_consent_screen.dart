import 'package:carcare_customer_mobile/app/customer_routes.dart';
import 'package:carcare_customer_mobile/app/theme/app_theme.dart';
import 'package:carcare_customer_mobile/features/legal/presentation/widgets/legal_widgets.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Shown after sign-in until this customer accepts the current terms (see
/// `customerRedirect`). The router listens to the store, so [onAccept] only
/// has to record the acceptance; the redirect then moves on by itself.
/// Declining signs out, since the terms say not to use the service without
/// accepting them; browsing as a guest stays open.
class TermsConsentScreen extends StatefulWidget {
  const TermsConsentScreen({
    required this.onAccept,
    required this.onDecline,
    super.key,
  });

  final Future<void> Function() onAccept;
  final Future<void> Function() onDecline;

  @override
  State<TermsConsentScreen> createState() => _TermsConsentScreenState();
}

class _TermsConsentScreenState extends State<TermsConsentScreen> {
  bool _agreed = false;
  bool _busy = false;

  // The underlined names in the checkbox sentence open their pages instead
  // of toggling the checkbox.
  late final TapGestureRecognizer _termsTap = TapGestureRecognizer()
    ..onTap = () => context.push(CustomerRoutes.terms);
  late final TapGestureRecognizer _privacyTap = TapGestureRecognizer()
    ..onTap = () => context.push(CustomerRoutes.privacy);

  @override
  void dispose() {
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      // The router normally replaces this page; if it is still here (the
      // action failed), let the user try again.
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Signs out and says so: the router drops the user on the guest home
  /// page, which would otherwise look like the decline did nothing. The
  /// app-level messenger outlives this route, so the snack bar stays.
  Future<void> _decline() async {
    final messenger = ScaffoldMessenger.of(context);
    await _run(widget.onDecline);
    messenger.showSnackBar(
      const SnackBar(
        key: ValueKey('terms-consent-declined-snack'),
        content: Text('Нөхцөлийг зөвшөөрөөгүй тул системээс гарлаа.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = AppColors.readable(AppColors.accent, theme.brightness);
    final link = theme.textTheme.bodyMedium?.copyWith(
      color: accent,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
      decorationColor: accent,
    );
    return PopScope(
      // Back would only bounce here again; decline is the way out.
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Үйлчилгээний нөхцөл'),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  Text(
                    'Үргэлжлүүлэхийн өмнө',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Carservice-ийг ашиглахын тулд Үйлчилгээний нөхцөл болон '
                    'Нууцлалын бодлоготой танилцана уу.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: CarCareTheme.of(context).mutedText,
                    ),
                  ),
                  const SizedBox(height: 16),
                  LegalLinkRow(
                    key: const ValueKey('terms-consent-terms-link'),
                    icon: Icons.description_outlined,
                    label: 'Үйлчилгээний нөхцөл',
                    onTap: () => context.push(CustomerRoutes.terms),
                  ),
                  LegalLinkRow(
                    key: const ValueKey('terms-consent-privacy-link'),
                    icon: Icons.privacy_tip_outlined,
                    label: 'Нууцлалын бодлого',
                    onTap: () => context.push(CustomerRoutes.privacy),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    key: const ValueKey('terms-consent-checkbox'),
                    onTap: _busy
                        ? null
                        : () => setState(() => _agreed = !_agreed),
                    borderRadius: BorderRadius.circular(AppRadii.small),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: _agreed,
                          onChanged: _busy
                              ? null
                              : (v) => setState(() => _agreed = v ?? false),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text.rich(
                              TextSpan(
                                style: theme.textTheme.bodyMedium,
                                children: [
                                  const TextSpan(text: 'Би '),
                                  TextSpan(
                                    text: 'Үйлчилгээний нөхцөл',
                                    style: link,
                                    recognizer: _termsTap,
                                  ),
                                  const TextSpan(text: ' болон '),
                                  TextSpan(
                                    text: 'Нууцлалын бодлого',
                                    style: link,
                                    recognizer: _privacyTap,
                                  ),
                                  const TextSpan(
                                    text:
                                        '-той танилцаж, хүлээн зөвшөөрч '
                                        'байна.',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    key: const ValueKey('terms-consent-accept'),
                    onPressed: _agreed && !_busy
                        ? () => _run(widget.onAccept)
                        : null,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text('Зөвшөөрөх'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    key: const ValueKey('terms-consent-decline'),
                    onPressed: _busy ? null : _decline,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text('Татгалзаж гарах'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
