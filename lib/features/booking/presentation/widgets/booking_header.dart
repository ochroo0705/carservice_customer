import 'package:carservice_customer/app/theme/app_surfaces.dart';
import 'package:carservice_customer/app/theme/app_theme.dart';
import 'package:carservice_customer/features/discovery/domain/branch.dart';
import 'package:carservice_customer/features/discovery/domain/organization.dart';
import 'package:carservice_customer/features/discovery/presentation/widgets/branch_open_status_line.dart';
import 'package:carservice_customer/features/discovery/presentation/widgets/organization_avatar.dart';
import 'package:flutter/material.dart';

/// Захиалгын хуудасны толгой — хаана цаг хүсч буйг товч сануулна: лого,
/// байгууллагын нэр, сонгосон салбар (эсвэл салбар/үйлчилгээний тоо), хаяг
/// болон одоогийн нээлттэй/хаалттай төлөв. Зөвхөн танилцуулах — сонголтгүй.
class BookingHeader extends StatelessWidget {
  const BookingHeader({
    super.key,
    required this.organization,
    required this.selectedBranch,
    required this.categoryCount,
  });

  final OrganizationDetail organization;
  final BranchDetail? selectedBranch;
  final int categoryCount;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    final branch = selectedBranch;
    final subtitle = branch != null
        ? branch.name
        : [
            '${organization.branches.length} салбар',
            if (categoryCount > 0) '$categoryCount үйлчилгээ',
          ].join(' · ');
    final address = branch == null
        ? ''
        : [
            branch.district,
            branch.fullAddress,
          ].where((part) => part.trim().isNotEmpty).join(', ');
    return GlassSurface(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          OrganizationLogoTile(
            name: organization.name,
            logoUrl: organization.logoUrl,
            size: 52,
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
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: theme.mutedText),
                ),
                if (address.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: theme.mutedText),
                  ),
                ],
                if (branch != null) ...[
                  const SizedBox(height: 4),
                  BranchOpenStatusLine(branch: branch),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
