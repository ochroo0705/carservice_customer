import 'package:carservice_customer/app/theme/app_theme.dart';
import 'package:carservice_customer/features/discovery/domain/branch.dart';
import 'package:flutter/material.dart';

const _weekdayLabels = ['Да', 'Мя', 'Лх', 'Пү', 'Ба', 'Бя', 'Ня'];

/// Monday-first month grid for picking a booking date, mirroring the web
/// booking flow's `BookingCalendar`. The branch's effective schedule disables
/// weekly closures, one-off exceptions, and seasonal closures; the server's
/// per-date availability remains authoritative at selection/submission time.
class BookingCalendar extends StatelessWidget {
  const BookingCalendar({
    required this.month,
    required this.selectedDate,
    required this.onDateSelected,
    required this.onMonthChanged,
    this.branch,
    super.key,
  });

  /// Any date within the displayed month.
  final DateTime month;
  final DateTime? selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final ValueChanged<DateTime> onMonthChanged;
  final BranchDetail? branch;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);
    final currentMonthKey = DateTime(month.year, month.month);
    final canGoBack = currentMonthKey.isAfter(
      DateTime(today.year, today.month),
    );
    final firstWeekday = DateTime(month.year, month.month).weekday;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leadingBlanks = firstWeekday - 1;
    final totalCells = ((leadingBlanks + daysInMonth) / 7).ceil() * 7;
    final muted = CarserviceTheme.of(context).mutedText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              key: const ValueKey('booking-calendar-prev'),
              onPressed: canGoBack
                  ? () => onMonthChanged(
                      DateTime(currentMonthKey.year, currentMonthKey.month - 1),
                    )
                  : null,
              tooltip: 'Өмнөх сар',
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              child: Text(
                '${month.year} оны ${month.month}-р сар',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              key: const ValueKey('booking-calendar-next'),
              onPressed: () => onMonthChanged(
                DateTime(currentMonthKey.year, currentMonthKey.month + 1),
              ),
              tooltip: 'Дараах сар',
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final label in _weekdayLabels)
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: muted,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
          ),
          itemCount: totalCells,
          itemBuilder: (context, index) {
            final dayNumber = index - leadingBlanks + 1;
            if (dayNumber < 1 || dayNumber > daysInMonth) {
              return const SizedBox.shrink();
            }
            final date = DateTime(month.year, month.month, dayNumber);
            final isPast = date.isBefore(todayKey);
            final effective = branch?.effectiveScheduleAt(
              DateTime.utc(date.year, date.month, date.day, 12),
            );
            final isClosed = effective != null && !effective.isOpen;
            final isToday = date == todayKey;
            final isSelected =
                selectedDate != null &&
                DateTime(
                      selectedDate!.year,
                      selectedDate!.month,
                      selectedDate!.day,
                    ) ==
                    date;
            return _DayCell(
              key: ValueKey(
                'booking-date-${date.year}-${date.month}-${date.day}',
              ),
              day: dayNumber,
              selected: isSelected,
              today: isToday,
              closed: isClosed && !isPast,
              enabled: !isPast && !isClosed,
              onTap: () => onDateSelected(date),
            );
          },
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.selected,
    required this.today,
    required this.closed,
    required this.enabled,
    required this.onTap,
    super.key,
  });

  final int day;
  final bool selected;
  final bool today;

  /// A future day the branch's schedule keeps closed (vs. simply past).
  final bool closed;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final muted = CarserviceTheme.of(context).mutedText;
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      enabled: enabled,
      hint: closed ? 'Хаалттай' : null,
      child: Material(
        color: selected ? AppColors.accent : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          side: today && !selected
              ? const BorderSide(color: AppColors.accent, width: 1.5)
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: Center(
            child: Text(
              '$day',
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                color: selected
                    ? AppColors.onAccent
                    : enabled
                    ? scheme.onSurface
                    : muted.withValues(alpha: 0.4),
                decoration: closed ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
