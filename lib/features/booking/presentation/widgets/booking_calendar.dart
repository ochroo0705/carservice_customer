import 'package:carservice_customer/app/theme/app_theme.dart';
import 'package:carservice_customer/features/discovery/domain/branch.dart';
import 'package:flutter/material.dart';

const _weekdayLabels = ['Дав', 'Мяг', 'Лха', 'Пүр', 'Баа', 'Бям', 'Ням'];

/// Booking date picker (CustBook "ӨДӨР"): the displayed month's remaining
/// days as a horizontally scrolling row of day chips — weekday (or
/// "Өнөөдөр") over the day number, selected = inverse fill — with month
/// arrows to reach later dates. Same rules as the web `BookingCalendar`:
/// past days are not offered, and the branch's effective schedule disables
/// weekly closures, one-off exceptions and seasonal closures; the server's
/// per-date availability stays authoritative at selection/submission time.
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
    final theme = CarserviceTheme.of(context);
    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);
    final currentMonthKey = DateTime(month.year, month.month);
    final canGoBack = currentMonthKey.isAfter(
      DateTime(today.year, today.month),
    );
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final selected = selectedDate == null
        ? null
        : DateTime(selectedDate!.year, selectedDate!.month, selectedDate!.day);
    final days = [
      for (var day = 1; day <= daysInMonth; day++)
        DateTime(month.year, month.month, day),
    ].where((date) => !date.isBefore(todayKey)).toList(growable: false);
    final monthLabel = month.year == today.year
        ? '${month.month}-р сар'
        : '${month.year} оны ${month.month}-р сар';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                monthLabel,
                style: TextStyle(fontSize: 13, color: theme.mutedText),
              ),
            ),
            _MonthArrow(
              key: const ValueKey('booking-calendar-prev'),
              icon: Icons.chevron_left_rounded,
              tooltip: 'Өмнөх сар',
              onPressed: canGoBack
                  ? () => onMonthChanged(
                      DateTime(currentMonthKey.year, currentMonthKey.month - 1),
                    )
                  : null,
            ),
            const SizedBox(width: 6),
            _MonthArrow(
              key: const ValueKey('booking-calendar-next'),
              icon: Icons.chevron_right_rounded,
              tooltip: 'Дараах сар',
              onPressed: () => onMonthChanged(
                DateTime(currentMonthKey.year, currentMonthKey.month + 1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          // A fresh scroll position per month, so it starts at its first day.
          key: ValueKey('booking-days-${month.year}-${month.month}'),
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            children: [
              for (final (index, date) in days.indexed) ...[
                if (index > 0) const SizedBox(width: 6),
                Builder(
                  builder: (context) {
                    final effective = branch?.effectiveScheduleAt(
                      DateTime.utc(date.year, date.month, date.day, 12),
                    );
                    final closed = effective != null && !effective.isOpen;
                    return _DayChip(
                      key: ValueKey(
                        'booking-date-${date.year}-${date.month}-${date.day}',
                      ),
                      day: date.day,
                      caption: date == todayKey
                          ? 'Өнөөдөр'
                          : _weekdayLabels[date.weekday - 1],
                      selected: selected == date,
                      closed: closed,
                      onTap: () => onDateSelected(date),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MonthArrow extends StatelessWidget {
  const _MonthArrow({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    final enabled = onPressed != null;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: enabled ? theme.card : Colors.transparent,
        shape: CircleBorder(side: BorderSide(color: theme.cardBorder)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox.square(
            dimension: 34,
            child: Icon(
              icon,
              size: 20,
              semanticLabel: tooltip,
              color: enabled
                  ? theme.ink
                  : theme.mutedText.withValues(alpha: 0.4),
            ),
          ),
        ),
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.day,
    required this.caption,
    required this.selected,
    required this.closed,
    required this.onTap,
    super.key,
  });

  final int day;

  /// "Өнөөдөр" or the short weekday.
  final String caption;
  final bool selected;

  /// A day the branch's schedule keeps closed.
  final bool closed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    final Color foreground;
    final Color captionColor;
    if (selected) {
      foreground = theme.onInverse;
      captionColor = theme.onInverse.withValues(alpha: 0.75);
    } else if (closed) {
      foreground = theme.mutedText.withValues(alpha: 0.5);
      captionColor = foreground;
    } else {
      foreground = theme.ink;
      captionColor = theme.mutedText;
    }
    return Semantics(
      selected: selected,
      enabled: !closed,
      hint: closed ? 'Хаалттай' : null,
      child: Material(
        color: selected
            ? theme.inverse
            : closed
            ? Colors.transparent
            : theme.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.large),
          side: BorderSide(color: selected ? theme.inverse : theme.cardBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: closed ? null : onTap,
          child: SizedBox(
            width: 60,
            height: 58,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  caption,
                  maxLines: 1,
                  style: TextStyle(fontSize: 11, color: captionColor),
                ),
                const SizedBox(height: 2),
                Text(
                  '$day',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: foreground,
                    decoration: closed ? TextDecoration.lineThrough : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
