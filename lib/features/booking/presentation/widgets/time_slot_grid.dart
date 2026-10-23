import 'package:carservice_customer/app/theme/app_theme.dart';
import 'package:carservice_customer/features/booking/domain/availability.dart';
import 'package:flutter/material.dart';

/// Parts of the day the slots are grouped under, by start hour.
const _periods = [
  (label: 'Өглөө', from: 0, until: 12),
  (label: 'Өдөр', from: 12, until: 18),
  (label: 'Орой', from: 18, until: 24),
];

/// The slot grid driven by the branch availability endpoint (booking v2):
/// slots are sized to the selected categories' summed duration, grouped by
/// part of the day in even four-column rows; full or past slots render
/// disabled and struck through.
class TimeSlotGrid extends StatelessWidget {
  const TimeSlotGrid({
    required this.slots,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final List<AvailabilitySlot> slots;
  final ({int hour, int minute})? selected;
  final ValueChanged<({int hour, int minute})> onSelected;

  @override
  Widget build(BuildContext context) {
    final muted = CarserviceTheme.of(context).mutedText;
    if (slots.isEmpty) {
      return Text(
        'Энэ өдөр сул цаг алга.',
        style: TextStyle(fontSize: 13, color: muted),
      );
    }
    final groups = [
      for (final period in _periods)
        (
          label: period.label,
          slots: slots
              .where((s) => s.hour >= period.from && s.hour < period.until)
              .toList(growable: false),
        ),
    ].where((group) => group.slots.isNotEmpty).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (index, group) in groups.indexed) ...[
          if (index > 0) const SizedBox(height: 14),
          Text(
            group.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: muted,
            ),
          ),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.1,
            children: [
              for (final slot in group.slots)
                _SlotCell(
                  key: ValueKey('booking-slot-${slot.hour}-${slot.minute}'),
                  label: _formatSlot(slot),
                  selected: selected == slot.time,
                  enabled: slot.available,
                  onTap: slot.available ? () => onSelected(slot.time) : null,
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _SlotCell extends StatelessWidget {
  const _SlotCell({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    final scheme = Theme.of(context).colorScheme;
    final foreground = selected
        ? AppColors.onAccent
        : enabled
        ? scheme.onSurface
        : theme.mutedText.withValues(alpha: 0.6);
    return Semantics(
      selected: selected,
      enabled: enabled,
      child: Material(
        color: selected ? AppColors.accent : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          side: selected
              ? BorderSide.none
              : BorderSide(
                  color: enabled
                      ? theme.glassBorder
                      : theme.glassBorder.withValues(alpha: 0.5),
                ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: foreground,
                decoration: enabled ? null : TextDecoration.lineThrough,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _formatSlot(AvailabilitySlot slot) =>
    '${slot.hour.toString().padLeft(2, '0')}:${slot.minute.toString().padLeft(2, '0')}';
