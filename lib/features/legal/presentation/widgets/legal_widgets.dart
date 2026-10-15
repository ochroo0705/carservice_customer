import 'package:carservice_customer/app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

// Building blocks shared by the two legal documents (Үйлчилгээний нөхцөл,
// Нууцлалын бодлого) so both read as one set.

const legalContactEmail = 'contact@infosystems.mn';
const legalTermsUrl = 'https://carservice.mn/terms';
const legalPrivacyUrl = 'https://carservice.mn/privacy';
const legalDeletionUrl = 'https://carservice.mn/account-deletion';

/// Best-effort: with no mail/phone/browser app there is nothing to open.
Future<void> openLegalLink(Uri uri) async {
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {}
}

Uri legalMailto([String email = legalContactEmail]) =>
    Uri(scheme: 'mailto', path: email);

Color _accent(BuildContext context) =>
    AppColors.readable(AppColors.accent, Theme.of(context).brightness);

/// The «Вэбээр нээх» app-bar action every bundled document carries.
class LegalOpenOnWebAction extends StatelessWidget {
  const LegalOpenOnWebAction({required this.url, super.key});

  final String url;

  @override
  Widget build(BuildContext context) => IconButton(
    key: const ValueKey('legal-open-on-web'),
    tooltip: 'Вэбээр нээх',
    icon: const Icon(Icons.open_in_new_rounded),
    onPressed: () => openLegalLink(Uri.parse(url)),
  );
}

/// A document's scroll view: a readable measure on tablets, selectable text,
/// title and effective-date badge on top.
class LegalDocumentView extends StatelessWidget {
  const LegalDocumentView({
    required this.title,
    required this.effectiveDate,
    required this.children,
    super.key,
  });

  final String title;
  final String effectiveDate;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final gutter = ((constraints.maxWidth - 720) / 2).clamp(
        20.0,
        double.infinity,
      );
      final accent = _accent(context);
      return SelectionArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 40),
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: Text(
                  'Хүчин төгөлдөр болсон: $effectiveDate',
                  style: Theme.of(context).textTheme.labelMedium
                      ?.copyWith(color: accent, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      );
    },
  );
}

/// Инфосистемс ХХК-ийн холбоо барих блок, хоёр баримтад ижил.
class LegalContactCard extends StatelessWidget {
  const LegalContactCard({super.key});

  static const _phones = ['8870116399', '70126399', '91916549'];

  @override
  Widget build(BuildContext context) => _LegalCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Инфосистемс ХХК',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        LegalLinkRow(
          icon: Icons.mail_outline_rounded,
          label: legalContactEmail,
          onTap: () => openLegalLink(legalMailto()),
        ),
        for (final phone in _phones)
          LegalLinkRow(
            icon: Icons.phone_outlined,
            label: phone,
            onTap: () => openLegalLink(Uri(scheme: 'tel', path: phone)),
          ),
        const LegalLinkRow(
          icon: Icons.place_outlined,
          label:
              'Улаанбаатар хот, Чингэлтэй дүүрэг, 5-р хороо, '
              'Баянбогд плаза, 402 тоот',
        ),
      ],
    ),
  );
}

class _LegalCard extends StatelessWidget {
  const _LegalCard({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    return Material(
      color: theme.shellSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.medium),
        side: BorderSide(color: theme.glassBorder),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.medium),
        child: Padding(padding: const EdgeInsets.all(14), child: child),
      ),
    );
  }
}

class LegalSection extends StatelessWidget {
  const LegalSection({
    required this.number,
    required this.title,
    required this.children,
    super.key,
  });

  final int number;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final accent = _accent(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$number',
                  style: Theme.of(context).textTheme.labelMedium
                      ?.copyWith(color: accent, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final (i, child) in children.indexed) ...[
            if (i > 0) const SizedBox(height: 10),
            child,
          ],
        ],
      ),
    );
  }
}

class LegalPara extends StatelessWidget {
  const LegalPara(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6),
  );
}

class LegalSubHeading extends StatelessWidget {
  const LegalSubHeading(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleMedium
          ?.copyWith(fontWeight: FontWeight.w700),
    ),
  );
}

class LegalBullets extends StatelessWidget {
  const LegalBullets(this.items, {super.key});

  final List<String> items;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final item in items)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(top: 9, right: 10, left: 2),
                decoration: BoxDecoration(
                  color: _accent(context),
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(child: LegalPara(item)),
            ],
          ),
        ),
    ],
  );
}

/// A titled card: an optional icon, then either [body] text or labelled
/// [rows] (the policy's table columns, stacked for phone widths).
class LegalItemCard extends StatelessWidget {
  const LegalItemCard({
    required this.title,
    this.icon,
    this.body,
    this.rows = const [],
    this.onTap,
    super.key,
  });

  final String title;
  final IconData? icon;
  final String? body;
  final List<(String, String)> rows;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final muted = CarserviceTheme.of(context).mutedText;
    final accent = _accent(context);
    return _LegalCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadii.medium),
              ),
              child: Icon(icon, size: 20, color: accent),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (body != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    body!,
                    style: text.bodyMedium?.copyWith(height: 1.5, color: muted),
                  ),
                ],
                for (final (label, value) in rows) ...[
                  const SizedBox(height: 8),
                  Text(
                    label.toUpperCase(),
                    style: text.labelSmall?.copyWith(color: muted),
                  ),
                  const SizedBox(height: 2),
                  Text(value, style: text.bodyMedium?.copyWith(height: 1.5)),
                ],
              ],
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 8),
            Icon(Icons.open_in_new_rounded, size: 18, color: muted),
          ],
        ],
      ),
    );
  }
}

class LegalNote extends StatelessWidget {
  const LegalNote({
    required this.icon,
    required this.text,
    this.warning = false,
    super.key,
  });

  final IconData icon;
  final String text;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final color = warning ? AppColors.warning : AppColors.green;
    final readable = AppColors.readable(color, Theme.of(context).brightness);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadii.medium),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: readable),
          const SizedBox(width: 10),
          Expanded(child: LegalPara(text)),
        ],
      ),
    );
  }
}

/// The policy's retention table: rows in one card, divided.
class LegalKeyValueCard extends StatelessWidget {
  const LegalKeyValueCard({required this.rows, super.key});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return _LegalCard(
      child: Column(
        children: [
          for (final (i, r) in rows.indexed) ...[
            if (i > 0) const Divider(height: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.$1,
                  style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  r.$2,
                  style: text.bodyMedium?.copyWith(
                    color: CarserviceTheme.of(context).mutedText,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class LegalLinkRow extends StatelessWidget {
  const LegalLinkRow({
    required this.icon,
    required this.label,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final link = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.small),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: CarserviceTheme.of(context).mutedText),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: link ? _accent(context) : null,
                    fontWeight: link ? FontWeight.w600 : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
