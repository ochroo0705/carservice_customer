import 'package:carservice_customer/app/theme/app_theme.dart';
import 'package:carservice_customer/core/widgets/cs_ui.dart';
import 'package:carservice_customer/features/vehicles/presentation/controllers/vehicles_controller.dart';
import 'package:carservice_customer/features/vehicles/presentation/controllers/vehicles_state.dart';
import 'package:flutter/material.dart';

// Menu values. `PopupMenuButton` treats a null result as "dismissed", so the
// "no vehicle" and "add vehicle" choices need non-null sentinels.
const _noneValue = '\u0000none';
const _addValue = '\u0000add';

/// The vehicle plate chip in the booking header (CustBook: "1234 УБА ▾").
/// Tapping it opens a menu: no vehicle, the customer's vehicles, or adding a
/// new one. Choosing a vehicle stays optional.
class VehiclePicker extends StatelessWidget {
  const VehiclePicker({
    super.key,
    required this.controller,
    required this.selectedVehicleId,
    required this.onChanged,
    required this.onAddVehicle,
  });

  final VehiclesController controller;
  final String? selectedVehicleId;
  final ValueChanged<String?> onChanged;
  final VoidCallback onAddVehicle;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    final state = controller.state;
    if (state.isLoading) {
      return const _Chip(
        child: SizedBox.square(
          dimension: 14,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (state.status == VehiclesStatus.error || state.vehicles.isEmpty) {
      return Tooltip(
        message: 'Машин нэмэх (заавал биш)',
        child: _Chip(
          key: const ValueKey('booking-add-vehicle'),
          onTap: onAddVehicle,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, size: 16, color: theme.ink),
              const SizedBox(width: 4),
              Text(
                'Машин',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: theme.ink,
                ),
              ),
            ],
          ),
        ),
      );
    }
    final selected = state.vehicles
        .where((vehicle) => vehicle.id == selectedVehicleId)
        .firstOrNull;
    return PopupMenuButton<String>(
      key: const ValueKey('booking-vehicle'),
      tooltip: 'Тээврийн хэрэгсэл (заавал биш)',
      initialValue: selected?.id ?? _noneValue,
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.control),
        side: BorderSide(color: theme.cardBorder),
      ),
      color: theme.card,
      onSelected: (value) {
        if (value == _addValue) {
          onAddVehicle();
        } else {
          onChanged(value == _noneValue ? null : value);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem<String>(
          value: _noneValue,
          child: Text('Сонгохгүй'),
        ),
        for (final vehicle in state.vehicles)
          PopupMenuItem<String>(
            value: vehicle.id,
            child: Text('${vehicle.plate} · ${vehicle.make} ${vehicle.model}'),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          key: ValueKey('booking-add-vehicle'),
          value: _addValue,
          child: Row(
            children: [
              Icon(Icons.add_circle_outline, size: 18),
              SizedBox(width: 8),
              Text('Шинэ машин нэмэх'),
            ],
          ),
        ),
      ],
      child: _Chip(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              selected?.plate ?? 'Машин',
              style: csMono(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: selected == null ? theme.mutedText : theme.ink,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.expand_more_rounded, size: 16, color: theme.mutedText),
          ],
        ),
      ),
    );
  }
}

/// The 8px-radius outlined chip shape of the plate selector.
class _Chip extends StatelessWidget {
  const _Chip({required this.child, this.onTap, super.key});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    final body = Container(
      constraints: const BoxConstraints(minHeight: 32),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(AppRadii.small),
        border: Border.all(color: theme.cardBorder),
      ),
      child: Center(widthFactor: 1, heightFactor: 1, child: child),
    );
    if (onTap == null) return body;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.small),
        onTap: onTap,
        child: body,
      ),
    );
  }
}
