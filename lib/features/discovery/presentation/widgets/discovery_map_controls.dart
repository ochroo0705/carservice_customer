import 'package:carservice_customer/app/theme/app_theme.dart';
import 'package:carservice_customer/features/booking/auth/presentation/auth_controller.dart';
import 'package:carservice_customer/features/notifications/presentation/controllers/notifications_controller.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// The soft drop shadow every control floating over the map carries, so it
/// reads as lifted off the tiles in light mode as well as dark.
List<BoxShadow> floatingControlShadow(BuildContext context) => [
  BoxShadow(
    color: Colors.black.withValues(
      alpha: Theme.of(context).brightness == Brightness.dark ? 0.35 : 0.1,
    ),
    blurRadius: 16,
    offset: const Offset(0, 4),
  ),
];

/// A bare, unobtrusive spinner under the map's floating header, shown while a
/// filter/search change is re-fetching markers for the on-screen viewport.
/// Deliberately not a banner with text — the map itself is the content here.
class MapRefreshSpinner extends StatelessWidget {
  const MapRefreshSpinner({super.key});

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('discovery-map-refreshing'),
    width: 30,
    height: 30,
    decoration: BoxDecoration(
      color: CarserviceTheme.of(context).shellSurface,
      shape: BoxShape.circle,
      boxShadow: floatingControlShadow(context),
    ),
    padding: const EdgeInsets.all(6),
    child: const CircularProgressIndicator(strokeWidth: 2.5),
  );
}

/// A round floating control on the map (locate-me, notifications): the
/// shell surface ringed in the shell border, with an optional count badge.
class MapRoundButton extends StatelessWidget {
  const MapRoundButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = 48,
    this.iconColor,
    this.badgeCount = 0,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final double size;
  final Color? iconColor;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    return Tooltip(
      message: tooltip,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: floatingControlShadow(context),
        ),
        child: Material(
          color: theme.shellSurface,
          shape: CircleBorder(side: BorderSide(color: theme.glassBorder)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: SizedBox.square(
              dimension: size,
              child: Center(
                child: Badge(
                  isLabelVisible: badgeCount > 0,
                  backgroundColor: AppColors.accent,
                  textColor: AppColors.onAccent,
                  label: Text(badgeCount > 9 ? '9+' : '$badgeCount'),
                  child: Icon(
                    icon,
                    size: 22,
                    color: iconColor ?? Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The notifications bell beside the map's search bar — only for a signed-in
/// account. Scoped to the two values it shows, so an unread-count push or an
/// account change rebuilds this button and never the map behind it.
class MapNotificationsButton extends StatelessWidget {
  const MapNotificationsButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final signedIn = context.select<AuthController, bool>(
      (auth) => auth.account != null,
    );
    if (!signedIn) return const SizedBox.shrink();
    final unreadCount = context.select<NotificationsController, int>(
      (notifications) => notifications.unreadCount,
    );
    return Padding(
      padding: const EdgeInsets.only(left: 10),
      child: MapRoundButton(
        key: const ValueKey('discovery-map-notifications'),
        icon: Icons.notifications_outlined,
        tooltip: 'Мэдэгдэл',
        size: 52,
        badgeCount: unreadCount,
        onPressed: onPressed,
      ),
    );
  }
}

/// The high-contrast pill that flips Хайх between the map and the list
/// ("Жагсаалт" / "Газрын зураг"). Inverted against the page — near-white on
/// the dark theme, near-black on the light one — so it stands out over map
/// tiles and list cards alike.
class MapViewToggleButton extends StatelessWidget {
  const MapViewToggleButton({
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
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: scheme.onSurface,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: SizedBox(
              height: 44,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18, color: scheme.surface),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      color: scheme.surface,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
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
