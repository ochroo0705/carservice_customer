import 'package:carservice_customer/app/theme/app_theme.dart';
import 'package:carservice_customer/core/widgets/cs_ui.dart';
import 'package:carservice_customer/features/discovery/domain/branch.dart';
import 'package:carservice_customer/features/discovery/domain/organization.dart';
import 'package:flutter/material.dart';

/// Захиалгын хуудасны толгой (CustBook): дугуй буцах товч, байгууллагын нэр,
/// доор нь "салбар · хаяг · цаг" гэсэн бүдэг мөр, баруун талд машины дугаарын
/// чип ([trailing]). Салбар сонгогдоогүй үед салбар/үйлчилгээний тоог харуулна.
class BookingHeader extends StatelessWidget {
  const BookingHeader({
    super.key,
    required this.organization,
    required this.selectedBranch,
    required this.categoryCount,
    this.onBack,
    this.trailing,
  });

  final OrganizationDetail organization;
  final BranchDetail? selectedBranch;
  final int categoryCount;

  /// Shows the round back button when set.
  final VoidCallback? onBack;

  /// The vehicle plate chip on the right.
  final Widget? trailing;

  static const _unknownHours = 'Цагийн мэдээлэл тодорхойгүй';

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    final branch = selectedBranch;
    final String subtitle;
    if (branch == null) {
      subtitle = [
        '${organization.branches.length} салбар',
        if (categoryCount > 0) '$categoryCount үйлчилгээ',
      ].join(' · ');
    } else {
      final address = [
        branch.district,
        branch.fullAddress,
      ].where((part) => part.trim().isNotEmpty).join(', ');
      final hours = branch.hoursLabel;
      subtitle = [
        branch.name,
        address,
        if (hours != _unknownHours) hours,
      ].where((part) => part.trim().isNotEmpty).join(' · ');
    }
    return Row(
      children: [
        if (onBack != null) ...[
          CsCircleButton.back(context, onPressed: onBack),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                organization.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
              if (subtitle.isNotEmpty)
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: theme.mutedText),
                ),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 10), trailing!],
      ],
    );
  }
}
