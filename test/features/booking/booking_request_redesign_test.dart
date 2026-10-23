import 'package:carservice_customer/app/theme/app_theme.dart';
import 'package:carservice_customer/core/errors/app_failure.dart';
import 'package:carservice_customer/features/booking/data/fake_appointment_repository.dart';
import 'package:carservice_customer/features/booking/domain/appointment_repository.dart';
import 'package:carservice_customer/features/booking/domain/availability.dart';
import 'package:carservice_customer/features/booking/presentation/screens/booking_request_screen.dart';
import 'package:carservice_customer/features/booking/presentation/widgets/booking_form_sections.dart';
import 'package:carservice_customer/features/discovery/domain/branch.dart';
import 'package:carservice_customer/features/discovery/domain/organization.dart';
import 'package:carservice_customer/features/vehicles/data/fake_vehicle_repository.dart';
import 'package:carservice_customer/features/vehicles/presentation/controllers/vehicles_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

const _oil = BranchServiceCategory(
  id: 'oil',
  name: 'Тос солих',
  durationMinutes: 30,
  systemServiceKeyId: 'k-oil',
);
const _tire = BranchServiceCategory(
  id: 'tire',
  name: 'Дугуй солих',
  durationMinutes: 20,
  systemServiceKeyId: 'k-tire',
);

BranchDetail _branch(String id, {List<BranchServiceCategory> categories = const []}) =>
    BranchDetail(
      id: id,
      name: 'Салбар $id',
      city: 'Улаанбаатар',
      district: 'Баянзүрх',
      khoroo: '1-р хороо',
      address: 'Энхтайваны өргөн чөлөө',
      openTime: '09:00',
      closeTime: '18:00',
      categories: categories,
    );

/// Fails every availability lookup once, then defers to the fake.
class _FlakyAvailability extends FakeAppointmentRepository {
  int calls = 0;

  @override
  Future<DayAvailability> getAvailability({
    required String branchId,
    required DateTime date,
    List<String> categoryIds = const [],
  }) {
    calls += 1;
    if (calls == 1) throw const ServerFailure('Цаг ачаалж чадсангүй.');
    return super.getAvailability(
      branchId: branchId,
      date: date,
      categoryIds: categoryIds,
    );
  }
}

Future<void> _pump(
  WidgetTester tester,
  OrganizationDetail organization, {
  AppointmentRepository? repository,
}) async {
  await tester.binding.setSurfaceSize(const Size(1000, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final vehicles = VehiclesController(FakeVehicleRepository());
  await vehicles.load();
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: vehicles,
      child: MaterialApp(
        theme: AppTheme.dark,
        home: BookingRequestScreen(
          organization: organization,
          repository: repository ?? FakeAppointmentRepository(),
          onAddVehicle: () {},
          onBack: () {},
          onCompleted: (_) {},
          onUnauthenticated: () {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

String _summary(WidgetTester tester) => tester
    .widgetList<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('booking-summary')),
        matching: find.byType(Text),
      ),
    )
    .map((text) => text.data)
    .join(' | ');

Future<DateTime> _pickFirstOfNextMonth(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('booking-calendar-next')));
  await tester.pumpAndSettle();
  final now = DateTime.now();
  final date = DateTime(now.year, now.month + 1);
  await tester.tap(
    find.byKey(ValueKey('booking-date-${date.year}-${date.month}-1')),
  );
  await tester.pumpAndSettle();
  return date;
}

void main() {
  test('bookingDateLabel names today and tomorrow, then the date', () {
    final now = DateTime(2026, 10, 23, 15);
    expect(bookingDateLabel(DateTime(2026, 10, 23), now), 'Өнөөдөр');
    expect(bookingDateLabel(DateTime(2026, 10, 24), now), 'Маргааш');
    // 2026-10-26 is a Monday.
    expect(bookingDateLabel(DateTime(2026, 10, 26), now), '10-р сарын 26, Да');
  });

  testWidgets('the summary bar walks through the missing steps', (
    tester,
  ) async {
    await _pump(
      tester,
      OrganizationDetail(slug: 'o', name: 'Org', branches: [_branch('a')]),
    );
    expect(_summary(tester), 'Дараагийн алхам | Өдрөө сонгоно уу');

    final date = await _pickFirstOfNextMonth(tester);
    expect(_summary(tester), 'Дараагийн алхам | Цагаа сонгоно уу');

    await tester.tap(find.byKey(const ValueKey('booking-slot-9-0')));
    await tester.pumpAndSettle();
    expect(
      _summary(tester),
      'Сонгосон цаг | ${bookingDateLabel(date, DateTime.now())} · 09:00',
    );
  });

  testWidgets('service rows toggle and total their durations', (tester) async {
    await _pump(
      tester,
      OrganizationDetail(
        slug: 'o',
        name: 'Org',
        branches: [
          _branch('a', categories: const [_oil, _tire]),
        ],
      ),
    );
    await tester.tap(find.text('Тос солих'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Дугуй солих'));
    await tester.pumpAndSettle();
    expect(find.text('Нийт ~50 мин'), findsOneWidget);

    await tester.tap(find.text('Дугуй солих'));
    await tester.pumpAndSettle();
    expect(find.text('Нийт ~30 мин'), findsOneWidget);
  });

  testWidgets('branches follow from the services picked', (tester) async {
    await _pump(
      tester,
      OrganizationDetail(
        slug: 'o',
        name: 'Org',
        branches: [
          _branch('a', categories: const [_oil, _tire]),
          _branch('b', categories: const [_oil]),
        ],
      ),
    );
    expect(find.byKey(const ValueKey('booking-branch-a')), findsNothing);
    expect(_summary(tester), 'Дараагийн алхам | Үйлчилгээгээ сонгоно уу');

    // Both branches offer oil changes; only "a" also does tyres.
    await tester.tap(find.text('Тос солих'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('booking-branch-a')), findsOneWidget);
    expect(find.byKey(const ValueKey('booking-branch-b')), findsOneWidget);
    expect(_summary(tester), 'Дараагийн алхам | Салбараа сонгоно уу');

    await tester.tap(find.byKey(const ValueKey('booking-branch-b')));
    await tester.pumpAndSettle();
    expect(_summary(tester), 'Дараагийн алхам | Өдрөө сонгоно уу');

    await tester.tap(find.text('Дугуй солих'));
    await tester.pumpAndSettle();
    // "b" can't do both, so the choice falls to the only branch that can.
    expect(find.byKey(const ValueKey('booking-branch-b')), findsNothing);
    expect(find.byKey(const ValueKey('booking-branch-a')), findsOneWidget);
  });

  testWidgets('a failed slot lookup offers a retry', (tester) async {
    final repository = _FlakyAvailability();
    await _pump(
      tester,
      OrganizationDetail(slug: 'o', name: 'Org', branches: [_branch('a')]),
      repository: repository,
    );
    await _pickFirstOfNextMonth(tester);
    expect(find.text('Цаг ачаалж чадсангүй.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('booking-slots-retry')));
    await tester.pumpAndSettle();
    expect(repository.calls, 2);
    expect(find.byKey(const ValueKey('booking-slot-9-0')), findsOneWidget);
  });

  testWidgets('sending too early explains what is missing', (tester) async {
    await _pump(
      tester,
      OrganizationDetail(slug: 'o', name: 'Org', branches: [_branch('a')]),
    );
    await tester.tap(find.byKey(const ValueKey('submit-booking')));
    await tester.pumpAndSettle();
    expect(find.text('Ирээдүйн өдөр, цаг сонгоно уу.'), findsOneWidget);
  });
}
