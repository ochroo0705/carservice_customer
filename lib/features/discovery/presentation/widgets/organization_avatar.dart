import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Rounded-square organization logo — the leading tile of the Хайх list
/// cards and the map's branch sheet. Falls back to the name's initials
/// ("Lexus Service" → "LS") while loading, on error, or without a logo URL.
/// A loaded logo sits on white, since most are drawn for a light background.
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
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(size / 4);
    final initials = DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: radius,
      ),
      child: Center(
        child: Text(
          organizationInitials(name),
          style: TextStyle(
            color: scheme.primary,
            fontSize: size * 0.32,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
    final url = logoUrl?.trim();
    return SizedBox.square(
      dimension: size,
      child: url == null || url.isEmpty
          ? initials
          : CachedNetworkImage(
              imageUrl: url,
              imageBuilder: (_, image) => DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: radius,
                  image: DecorationImage(image: image, fit: BoxFit.cover),
                ),
              ),
              placeholder: (_, _) => initials,
              errorWidget: (_, _, _) => initials,
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
