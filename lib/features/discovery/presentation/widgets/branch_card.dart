import 'package:carservice_customer/app/theme/app_surfaces.dart';
import 'package:carservice_customer/app/theme/app_theme.dart';
import 'package:carservice_customer/features/discovery/domain/branch.dart';
import 'package:carservice_customer/features/discovery/domain/organization.dart';
import 'package:carservice_customer/features/discovery/presentation/widgets/discovery_list_parts.dart';
import 'package:carservice_customer/features/discovery/presentation/widgets/organization_avatar.dart';
import 'package:flutter/material.dart';

/// Business-type pills a list card shows before collapsing the rest into
/// "+N" — the card is a scan line, not the branch's full profile.
const _maxCardTags = 3;

/// Салбарын карт — Хайх жагсаалт салбарын түвшинд харагдана. Газрын зургийн
/// салбарын sheet-ийн толгойтой ижил бүтэцтэй: байгууллагын нэр гарчиг,
/// салбарын нэр · зай дэд гарчиг, дараа нь байршил ба бизнесийн төрлүүд.
class BranchCard extends StatelessWidget {
  const BranchCard({
    required this.organization,
    required this.branch,
    required this.onTap,
    super.key,
  });
  final Organization organization;
  final Branch branch;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    final subtitle = [
      branch.name,
      ?branch.distanceLabel,
    ].where((part) => part.trim().isNotEmpty).join(' · ');
    return GlassSurface(
      key: ValueKey('branch-${organization.slug}-${branch.id}'),
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          OrganizationLogoTile(
            name: organization.name,
            logoUrl: organization.logoUrl,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  organization.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: theme.mutedText),
                  ),
                ],
                if (branch.locationLabel.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.place_outlined,
                        size: 15,
                        color: theme.mutedText,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          branch.locationLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ],
                if (branch.tags.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final tag in branch.tags.take(_maxCardTags))
                        DiscoveryPill(label: tag.name),
                      if (branch.tags.length > _maxCardTags)
                        DiscoveryPill(
                          label: '+${branch.tags.length - _maxCardTags}',
                          muted: true,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right_rounded, color: theme.mutedText),
        ],
      ),
    );
  }
}
