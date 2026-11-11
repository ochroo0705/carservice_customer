import 'package:carservice_customer/app/theme/app_theme.dart';
import 'package:carservice_customer/core/widgets/cs_ui.dart';
import 'package:carservice_customer/features/discovery/services/location_permission_service.dart';
import 'package:flutter/material.dart';

class LocationPermissionBanner extends StatelessWidget {
  const LocationPermissionBanner({
    required this.state,
    required this.onRequest,
    required this.onOpenSettings,
    super.key,
  });

  final LocationAccessState state;
  final VoidCallback onRequest;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    final permanentlyDenied = state == LocationAccessState.permanentlyDenied;
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.4;
    final message = Text(
      permanentlyDenied
          ? 'Байршлыг тохиргооноос зөвшөөрнө үү'
          : 'Одоогийн байршлаа харуулах уу?',
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: theme.ink,
      ),
    );
    final action = TextButton(
      key: ValueKey(
        permanentlyDenied ? 'location-open-settings' : 'location-request-again',
      ),
      onPressed: permanentlyDenied ? onOpenSettings : onRequest,
      style: TextButton.styleFrom(foregroundColor: theme.link),
      child: Text(permanentlyDenied ? 'Тохиргоо' : 'Зөвшөөрөх'),
    );
    return Semantics(
      container: true,
      liveRegion: true,
      label: permanentlyDenied
          ? 'Байршлын зөвшөөрөл хаалттай. Аппын тохиргоог нээнэ үү.'
          : 'Байршлын зөвшөөрөл өгөөгүй байна.',
      child: Container(
        decoration: BoxDecoration(
          color: theme.card,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: theme.cardBorder),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.black.withValues(alpha: 0.35)
                  : const Color(0xFF2C3E50).withValues(alpha: 0.14),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
          child: largeText
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const CsIconTile(icon: Icons.location_off_outlined),
                        const SizedBox(width: 10),
                        Expanded(child: message),
                      ],
                    ),
                    Align(alignment: Alignment.centerRight, child: action),
                  ],
                )
              : Row(
                  children: [
                    const CsIconTile(icon: Icons.location_off_outlined),
                    const SizedBox(width: 10),
                    Expanded(child: message),
                    action,
                  ],
                ),
        ),
      ),
    );
  }
}
