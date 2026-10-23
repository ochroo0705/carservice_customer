import 'package:carservice_customer/features/booking/domain/appointment_repository.dart';
import 'package:carservice_customer/features/booking/domain/availability.dart';
import 'package:carservice_customer/features/booking/domain/next_available_slot.dart';
import 'package:flutter_test/flutter_test.dart';

AvailabilitySlot _slot(DateTime date, int hour, {bool available = true}) =>
    AvailabilitySlot(
      hour: hour,
      minute: 0,
      available: available,
      remaining: available ? 1 : 0,
      // Ulaanbaatar wall clock → UTC, as the endpoint's `iso` field does.
      utc: DateTime.utc(
        date.year,
        date.month,
        date.day,
        hour,
      ).subtract(const Duration(hours: 8)),
    );

/// Serves per-day slots from [days] (keyed by day offset from [today]).
class _Availability extends Fake implements AppointmentRepository {
  _Availability(this.today, this.days);

  final DateTime today;
  final Map<int, List<int>> days;
  final requested = <DateTime>[];

  @override
  Future<DayAvailability> getAvailability({
    required String branchId,
    required DateTime date,
    List<String> categoryIds = const [],
  }) async {
    requested.add(date);
    final offset = date.difference(today).inDays;
    return DayAvailability(
      open: true,
      durationMinutes: 30,
      slots: [for (final hour in days[offset] ?? const <int>[]) _slot(date, hour)],
    );
  }
}

void main() {
  final today = DateTime(2026, 10, 22);
  // 15:00 in Ulaanbaatar.
  final now = DateTime.utc(2026, 10, 22, 7);

  test('skips today\'s past slots and rolls over to tomorrow', () async {
    final repository = _Availability(today, {
      0: [9, 12],
      1: [9, 10],
    });
    final next = await findNextAvailableSlot(
      repository,
      branchId: 'b',
      now: now,
    );
    expect(next?.dayOffset, 1);
    expect(next?.label, 'Маргааш 09:00');
  });

  test('labels a later slot today', () async {
    final repository = _Availability(today, {
      0: [9, 16],
    });
    final next = await findNextAvailableSlot(
      repository,
      branchId: 'b',
      now: now,
    );
    expect(next?.label, 'Өнөөдөр 16:00');
  });

  test('stops after three days without a free slot', () async {
    final repository = _Availability(today, {5: [9]});
    final next = await findNextAvailableSlot(
      repository,
      branchId: 'b',
      now: now,
    );
    expect(next, isNull);
    expect(repository.requested, hasLength(3));
  });
}
