import 'dart:ui' show ImageFilter;

import 'package:carservice_customer/app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Building blocks of the 2026-11 customer-app design ("carservice.mn өнгөний
/// схем" canvas, Хэрэглэгч boards). Every screen composes these instead of
/// restyling Material defaults one by one, so the look stays in one place.

/// Geist Mono text style for plates, prices, times and small labels.
TextStyle csMono({
  double fontSize = 13,
  FontWeight fontWeight = FontWeight.w500,
  Color? color,
  double? letterSpacing,
}) => TextStyle(
  fontFamily: AppFonts.mono,
  fontSize: fontSize,
  fontWeight: fontWeight,
  color: color,
  letterSpacing: letterSpacing,
);

/// The 44px round outlined icon button used for back / notifications.
class CsCircleButton extends StatelessWidget {
  const CsCircleButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.badge = false,
    super.key,
  });

  /// A back button that pops the current route.
  factory CsCircleButton.back(BuildContext context, {Key? key, VoidCallback? onPressed}) =>
      CsCircleButton(
        key: key,
        icon: Icons.chevron_left_rounded,
        // Material's localized "Back" — also what `tester.pageBack()` finds.
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
      );

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  /// Shows the small accent dot (unread notifications).
  final bool badge;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: theme.card,
        shape: CircleBorder(side: BorderSide(color: theme.cardBorder)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(icon, size: 22, color: theme.ink, semanticLabel: tooltip),
                if (badge)
                  const Positioned(
                    top: 10,
                    right: 11,
                    child: _Dot(color: AppColors.accent, size: 8),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

/// White (light) / panel (dark) card with a 1px border and 16px corners.
class CsCard extends StatelessWidget {
  const CsCard({
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
    this.highlighted = false,
    this.radius = AppRadii.card,
    this.color,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  /// A 2px ink outline: the selected / recommended item in a list.
  final bool highlighted;
  final double radius;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: highlighted
          ? BorderSide(color: theme.ink, width: 2)
          : BorderSide(color: theme.cardBorder),
    );
    return Material(
      color: color ?? theme.card,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// The navy hero card ("Миний машин", repair status).
class CsHeroCard extends StatelessWidget {
  const CsHeroCard({
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    return Material(
      color: theme.hero,
      borderRadius: BorderRadius.circular(AppRadii.hero),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: DefaultTextStyle.merge(
          style: TextStyle(color: theme.onHero),
          child: IconTheme.merge(
            data: IconThemeData(color: theme.onHero),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

/// `ҮЙЛЧИЛГЭЭ`-style section label: Geist Mono, 11px, uppercase, tracked.
class CsSectionLabel extends StatelessWidget {
  const CsSectionLabel(this.text, {this.color, this.trailing, super.key});

  final String text;
  final Color? color;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      text.toUpperCase(),
      style: csMono(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.66,
        color: color ?? CarserviceTheme.of(context).mutedText,
      ),
    );
    if (trailing == null) return label;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [Expanded(child: label), trailing!],
    );
  }
}

/// A section title row: "Ойролцоох сервис ............ Бүгд".
class CsSectionHeader extends StatelessWidget {
  const CsSectionHeader(this.title, {this.actionLabel, this.onAction, super.key});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
        ),
        if (actionLabel != null)
          InkWell(
            onTap: onAction,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Text(
                actionLabel!,
                style: TextStyle(fontSize: 13, color: theme.link, fontWeight: FontWeight.w500),
              ),
            ),
          ),
      ],
    );
  }
}

enum CsTone { success, warning, accent, info, neutral }

/// A tinted pill badge ("Нээлттэй", "Засварт", "Явагдаж байна").
class CsBadge extends StatelessWidget {
  const CsBadge(this.label, {this.tone = CsTone.neutral, this.dot = false, this.solid = false, super.key});

  final String label;
  final CsTone tone;

  /// Prefix a small dot (live status).
  final bool dot;

  /// Solid accent fill with white text ("Засварт" on the hero card).
  final bool solid;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    final brightness = Theme.of(context).brightness;
    final (Color bg, Color fg) = solid
        ? (AppColors.accent, Colors.white)
        : switch (tone) {
            CsTone.success => (theme.successSoft, AppColors.readable(AppColors.green, brightness)),
            CsTone.warning => (theme.warningSoft, AppColors.readable(AppColors.warning, brightness)),
            CsTone.accent => (theme.accentSoft, theme.link),
            CsTone.info => (AppColors.blue.withValues(alpha: 0.16), AppColors.readable(AppColors.blue, brightness)),
            CsTone.neutral => (theme.shellBackground, theme.ink),
          };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadii.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[_Dot(color: fg, size: 6), const SizedBox(width: 5)],
          Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: fg, height: 1.2),
          ),
        ],
      ),
    );
  }
}

/// A small rectangular tag ("Хайбрид", "Оношилгоо") on a card.
class CsTag extends StatelessWidget {
  const CsTag(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: theme.shellBackground, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(fontSize: 11, color: theme.ink)),
    );
  }
}

/// A licence-plate chip in Geist Mono ("1234 УБА").
class CsPlate extends StatelessWidget {
  const CsPlate(this.plate, {this.onHero = false, this.fontSize = 13, super.key});

  final String plate;

  /// Light chip for the navy hero card; otherwise an outlined card chip.
  final bool onHero;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: onHero ? theme.onHero : theme.card,
        borderRadius: BorderRadius.circular(7),
        border: onHero ? null : Border.all(color: theme.cardBorder),
      ),
      child: Text(
        plate,
        style: csMono(
          fontSize: fontSize,
          color: onHero ? const Color(0xFF2C3E50) : theme.ink,
        ),
      ),
    );
  }
}

/// A rounded pill choice ("Ойрхон", "Toyota"); selected = navy fill.
class CsChoicePill extends StatelessWidget {
  const CsChoicePill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    final fg = selected ? theme.onInverse : theme.ink;
    return Material(
      color: selected ? theme.inverse : theme.card,
      shape: StadiumBorder(side: BorderSide(color: selected ? theme.inverse : theme.cardBorder)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap!();
              },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 36),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[Icon(icon, size: 16, color: fg), const SizedBox(width: 6)],
                Text(label, style: TextStyle(fontSize: 13, color: fg, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A rounded-square icon tile used in front of a card's title.
class CsIconTile extends StatelessWidget {
  const CsIconTile({required this.icon, this.size = 32, this.color, this.background, super.key});

  final IconData icon;
  final double size;
  final Color? color;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? theme.accentSoft,
        borderRadius: BorderRadius.circular(size * 0.31),
      ),
      child: Icon(icon, size: size * 0.56, color: color ?? theme.link),
    );
  }
}

/// Initials avatar on a navy square ("LS"), or a network logo.
class CsMonogram extends StatelessWidget {
  const CsMonogram({required this.name, this.size = 52, this.imageUrl, super.key});

  final String name;
  final double size;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final initials = words.isEmpty
        ? '?'
        : words.take(2).map((w) => w.characters.first.toUpperCase()).join();
    final box = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: theme.hero, borderRadius: BorderRadius.circular(size * 0.27)),
      child: Text(
        initials,
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: size * 0.3, color: theme.onHero),
      ),
    );
    final url = imageUrl?.trim();
    if (url == null || url.isEmpty) return box;
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.27),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => box,
      ),
    );
  }
}

/// One destination of [CsFloatingNav].
class CsNavItem {
  const CsNavItem({required this.icon, required this.label, this.badge = false, this.key});

  final IconData icon;
  final String label;
  final bool badge;
  final Key? key;
}

/// The floating, blurred pill bottom navigation: the active item is a navy
/// pill with its label, the others icon-only.
class CsFloatingNav extends StatelessWidget {
  const CsFloatingNav({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  final List<CsNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// Height the nav occupies above the bottom inset; scroll views pad by this.
  static const double reservedHeight = 64 + 24 + 12;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset > 0 ? bottomInset : 24),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2C3E50).withValues(alpha: dark ? 0.4 : 0.16),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: theme.card.withValues(alpha: dark ? 0.85 : 0.8),
                borderRadius: BorderRadius.circular(AppRadii.pill),
                border: Border.all(color: theme.cardBorder.withValues(alpha: 0.9)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var i = 0; i < items.length; i++)
                    _NavButton(
                      item: items[i],
                      selected: i == selectedIndex,
                      onTap: () => onSelected(i),
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

class _NavButton extends StatelessWidget {
  const _NavButton({required this.item, required this.selected, required this.onTap});

  final CsNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    final fg = selected ? theme.onInverse : theme.mutedText;
    return Semantics(
      selected: selected,
      button: true,
      label: item.label,
      excludeSemantics: true,
      child: Material(
        key: item.key,
        color: Colors.transparent,
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            height: 48,
            constraints: const BoxConstraints(minWidth: 48),
            padding: EdgeInsets.symmetric(horizontal: selected ? 16 : 12),
            decoration: BoxDecoration(
              color: selected ? theme.inverse : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(item.icon, size: selected ? 20 : 22, color: fg),
                    if (item.badge)
                      const Positioned(top: -2, right: -2, child: _Dot(color: AppColors.accent, size: 8)),
                  ],
                ),
                if (selected) ...[
                  const SizedBox(width: 6),
                  Text(item.label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: fg)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
