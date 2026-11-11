import 'package:carservice_customer/app/theme/app_theme.dart';
import 'package:carservice_customer/core/widgets/cs_ui.dart';
import 'package:carservice_customer/features/discovery/domain/branch.dart';
import 'package:carservice_customer/features/discovery/domain/organization.dart';
import 'package:carservice_customer/features/discovery/presentation/branch_actions.dart';
import 'package:carservice_customer/features/discovery/presentation/branch_open_style.dart';
import 'package:carservice_customer/features/discovery/presentation/controllers/organization_detail_controller.dart';
import 'package:carservice_customer/features/discovery/presentation/widgets/discovery_list_parts.dart';
import 'package:carservice_customer/features/discovery/presentation/widgets/organization_avatar.dart';
import 'package:flutter/material.dart';

/// Пин дарахад доороос гарч ирэх sheet — web-ийн газрын зураг дээрх карттай
/// ижил түвшний мэдээлэл (лого, нээлттэй/хаалттай төлөв + цаг, хаяг, утас,
/// ангилалууд) харуулахын тулд тухайн байгууллагын дэлгэрэнгүйг
/// (`detailController`) цөөнгүй ачаалж, ирэх хүртэл зөвхөн жагсаалтаас аль
/// хэдийн байгаа нэр/зай мэдээллийг харуулна.
/// This sheet is a quick preview docked under the map — it shows a handful
/// of categories plus a "+N" count rather than every single one (unlike the
/// organization detail page, which has room for the full list).
const _maxPreviewCategories = 4;

class SelectedBranchSheet extends StatelessWidget {
  const SelectedBranchSheet({
    required this.organization,
    required this.branch,
    required this.detailController,
    required this.onClose,
    required this.onDetails,
    required this.onBook,
    super.key,
  });

  final Organization organization;
  final Branch branch;
  final OrganizationDetailController detailController;
  final VoidCallback onClose;
  final VoidCallback onDetails;
  final VoidCallback onBook;

  BranchDetail? _matchingBranch(OrganizationDetail detail) {
    for (final candidate in detail.branches) {
      if (candidate.id == branch.id) return candidate;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final detail = detailController.organization;
    final detailMatches = detail != null && detail.slug == organization.slug;
    final loadingDetail =
        detailController.status == OrganizationDetailStatus.loading &&
        !detailMatches;
    final branchDetail = detailMatches ? _matchingBranch(detail) : null;
    final phone = detailMatches ? detail.phone?.trim() : null;
    final latitude = branch.latitude;
    final longitude = branch.longitude;
    final address = branchDetail?.fullAddress ?? '';
    final now = DateTime.now();
    final openStatus = branchDetail?.openStatusAt(now);
    final openHint = branchDetail == null || openStatus == null
        ? null
        : branchOpenHint(branchDetail, openStatus, now);
    final subtitle = [
      branch.name,
      ?branch.distanceLabel,
    ].where((part) => part.trim().isNotEmpty).join(' · ');
    final media = MediaQuery.of(context);
    const sheetRadius = BorderRadius.vertical(top: Radius.circular(24));

    return GestureDetector(
      // A downward fling dismisses the sheet, like a modal one would.
      onVerticalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) > 300) onClose();
      },
      // The design's rounded-top sheet: page-tone fill, 24px top corners and
      // a soft navy shadow cast upward over the map.
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: sheetRadius,
          boxShadow: [
            BoxShadow(
              color: dark
                  ? Colors.black.withValues(alpha: 0.4)
                  : const Color(0xFF2C3E50).withValues(alpha: 0.10),
              blurRadius: 24,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: Material(
          color: theme.shellBackground,
          shape: const RoundedRectangleBorder(borderRadius: sheetRadius),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: media.size.height * 0.6),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                0,
                20,
                20 + media.padding.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    button: true,
                    label: 'Хаах',
                    child: GestureDetector(
                      key: const ValueKey('selected-branch-handle'),
                      behavior: HitTestBehavior.opaque,
                      onTap: onClose,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 10, bottom: 12),
                        child: Center(
                          child: Container(
                            width: 40,
                            height: 5,
                            decoration: BoxDecoration(
                              color: theme.mutedText.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(
                                AppRadii.pill,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  CsCard(
                    key: const ValueKey('selected-branch-details'),
                    onTap: onDetails,
                    highlighted: true,
                    padding: const EdgeInsets.all(13),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            OrganizationLogoTile(
                              name: organization.name,
                              logoUrl: organization.logoUrl,
                              size: 48,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    organization.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (subtitle.isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      subtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: theme.mutedText,
                                      ),
                                    ),
                                  ],
                                  if (openHint != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      openHint,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: theme.mutedText,
                                      ),
                                    ),
                                  ],
                                  if (branchDetail == null &&
                                      loadingDetail) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      'Дэлгэрэнгүй ачаалж байна…',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: theme.mutedText,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (openStatus != null &&
                                openStatus != BranchOpenStatus.unknown)
                              Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: CsBadge(
                                  openStatus == BranchOpenStatus.open
                                      ? 'Нээлттэй'
                                      : 'Хаалттай',
                                  tone: openStatus == BranchOpenStatus.open
                                      ? CsTone.success
                                      : CsTone.warning,
                                  dot: true,
                                ),
                              ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: theme.mutedText,
                            ),
                          ],
                        ),
                        if (branchDetail != null &&
                            branchDetail.categories.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              // Quick preview: a taste of what's offered, not
                              // the full list — that's what the detail page
                              // is for.
                              for (final category
                                  in branchDetail.categories.take(
                                    _maxPreviewCategories,
                                  ))
                                DiscoveryPill(label: category.name),
                              if (branchDetail.categories.length >
                                  _maxPreviewCategories)
                                DiscoveryPill(
                                  label:
                                      '+${branchDetail.categories.length - _maxPreviewCategories}',
                                  muted: true,
                                ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 12),
                        _InfoLine(
                          icon: Icons.place_outlined,
                          text: address.isEmpty
                              ? branch.locationLabel
                              : address,
                        ),
                        if (branchDetail != null) ...[
                          const SizedBox(height: 8),
                          _InfoLine(
                            icon: Icons.schedule_rounded,
                            text: branchDetail.hoursLabel,
                            mono: true,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (phone != null && phone.isNotEmpty) ...[
                        _ActionTile(
                          key: const ValueKey('selected-branch-call'),
                          icon: Icons.call_outlined,
                          label: 'Залгах $phone',
                          onPressed: () => callBranchPhone(phone),
                        ),
                        const SizedBox(width: 10),
                      ],
                      if (latitude != null && longitude != null) ...[
                        _ActionTile(
                          key: const ValueKey('selected-branch-directions'),
                          icon: Icons.near_me_outlined,
                          label: 'Чиглэл',
                          onPressed: () => openBranchDirections(
                            latitude: latitude,
                            longitude: longitude,
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: FilledButton(
                          key: const ValueKey('selected-branch-book'),
                          onPressed: onBook,
                          child: const Text('Цаг захиалах'),
                        ),
                      ),
                    ],
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

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text, this.mono = false});

  final IconData icon;
  final String text;

  /// Hours read in Geist Mono, like every time in the design.
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.mutedText),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: mono
                ? csMono(fontSize: 13, color: theme.ink)
                : TextStyle(fontSize: 13, color: theme.ink),
          ),
        ),
      ],
    );
  }
}

/// A square outlined secondary action beside the booking button (call,
/// directions), matching the 54px primary button.
class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    return Tooltip(
      message: label,
      child: Material(
        color: theme.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          side: BorderSide(color: theme.cardBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox.square(
            dimension: 54,
            child: Icon(icon, size: 22, color: theme.ink),
          ),
        ),
      ),
    );
  }
}
