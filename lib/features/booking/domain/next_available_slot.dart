import 'package:carservice_customer/features/booking/domain/appointment_repository.dart';
import 'package:carservice_customer/features/booking/domain/availability.dart';

/// How many days (today included) the "Ойрын сул цаг" lookup scans — each
/// day is one availability request, so this stays small.
const _lookaheadDays = 3;

/// The earliest bookable slot at a branch — for the detail page's booking
/// bar ("Ойрын сул цаг · Маргааш 11:00").
class NextAvailableSlot {
  const NextAvailableSlot({required this.dayOffset, required this.slot});

  /// 0 = today, 1 = tomorrow, 2 = the day after.
  final int dayOffset;
  final AvailabilitySlot slot;

  /// "Өнөөдөр 14:30", "Маргааш 09:00", "Нөгөөдөр 11:00" — in the branch's
  /// own (Ulaanbaatar) clock, as the availability endpoint reports it.
  String get label {
    final day = switch (dayOffset) {
      0 => 'Өнөөдөр',
      1 => 'Маргааш',
      _ => 'Нөгөөдөр',
    };
    final hour = slot.hour.toString().padLeft(2, '0');
    final minute = slot.minute.toString().padLeft(2, '0');
    return '$day $hour:$minute';
  }
}

/// The first free slot at [branchId] from today through the next two days,
/// at the branch's default slot length (no services picked yet), or null
/// when none is free. Days are device-local calendar dates, as the booking
/// form sends them. Availability errors propagate to the caller.
Future<NextAvailableSlot?> findNextAvailableSlot(
  AppointmentRepository repository, {
  required String branchId,
  DateTime? now,
}) async {
  final current = now ?? DateTime.now();
  for (var offset = 0; offset < _lookaheadDays; offset++) {
    final date = DateTime(current.year, current.month, current.day + offset);
    final day = await repository.getAvailability(
      branchId: branchId,
      date: date,
    );
    for (final slot in day.slots) {
      // `available` already means "in the future" server-side; the clock
      // check also covers sources that don't (the fake repository).
      if (slot.available && slot.utc.isAfter(current.toUtc())) {
        return NextAvailableSlot(dayOffset: offset, slot: slot);
      }
    }
  }
  return null;
}
