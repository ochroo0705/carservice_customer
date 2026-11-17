import 'package:cached_network_image/cached_network_image.dart';
import 'package:carservice_customer/app/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Rounded-square organization logo — the leading tile of the Хайх list
/// cards and the map's branch sheet. Falls back to the Carservice mark
/// (`assets/brand/mark.png`, web `/brand/mark.svg`) while loading, on error,
/// or without a logo URL — same as the web discover pins/cards since
/// 2026-11-17. Both sit on white, since most logos are drawn for a light
/// background.
class OrganizationLogoTile extends StatelessWidget {
  const OrganizationLogoTile({
    required this.name,
    required this.logoUrl,
    this.size = 56,
    super.key,
  });

  final String name;
  final String? logoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    // 14px on the design's 48px tile.
    final radius = BorderRadius.circular(size * 0.29);
    final fallback = Semantics(
      label: name,
      child: DecoratedBox(
        key: const ValueKey('organization-logo-fallback'),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: radius,
          border: Border.all(color: theme.cardBorder),
        ),
        child: Padding(
          // Web: the mark at ~70% of the tile.
          padding: EdgeInsets.all(size * 0.17),
          child: Image.asset(
            'assets/brand/mark.png',
            fit: BoxFit.contain,
            excludeFromSemantics: true,
          ),
        ),
      ),
    );
    final url = logoUrl?.trim();
    return SizedBox.square(
      dimension: size,
      child: url == null || url.isEmpty
          ? fallback
          : CachedNetworkImage(
              imageUrl: url,
              imageBuilder: (_, image) => DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: radius,
                  image: DecorationImage(image: image, fit: BoxFit.cover),
                ),
              ),
              placeholder: (_, _) => fallback,
              errorWidget: (_, _, _) => fallback,
            ),
    );
  }
}

/// Up to two initials from a name's first two words ("Lexus Service" →
/// "LS", "Toyota" → "T"), or "?" for a blank name.
String organizationInitials(String name) {
  final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  final initials = words.take(2).map((w) => w.characters.first.toUpperCase());
  return initials.isEmpty ? '?' : initials.join();
}
