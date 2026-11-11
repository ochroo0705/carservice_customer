import 'package:carservice_customer/app/theme/app_theme.dart';
import 'package:carservice_customer/features/booking/domain/availability.dart';
import 'package:carservice_customer/features/booking/domain/next_available_slot.dart';
import 'package:carservice_customer/features/discovery/domain/branch.dart';
import 'package:carservice_customer/features/discovery/domain/organization.dart';
import 'package:carservice_customer/features/discovery/presentation/controllers/organization_detail_controller.dart';
import 'package:carservice_customer/features/discovery/presentation/screens/organization_detail_screen.dart';
import 'package:carservice_customer/features/discovery/presentation/widgets/branch_open_status_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

BranchDetail _branch({int categoryCount = 2}) => BranchDetail(
  id: 'main',
  name: 'Үндсэн салбар',
  city: 'Улаанбаатар',
  district: 'Баянзүрх',
  khoroo: '26-р хороо',
  address: 'Нарны зам 18',
  openTime: '09:00',
  closeTime: '18:00',
  schedules: [
    for (final day in _weekdays)
      BranchScheduleRule(
        weekday: day,
        isOpen: true,
        openTime: '09:00',
        closeTime: '18:00',
      ),
  ],
  categories: [
    for (var i = 1; i <= categoryCount; i++)
      BranchServiceCategory(
        id: 'c$i',
        name: 'Үйлчилгээ $i',
        durationMinutes: 30 * i,
        systemServiceKeyId: 'k$i',
      ),
  ],
);

Future<void> _pump(
  WidgetTester tester, {
  BranchDetail? branch,
  String? phone = '7011 6543',
  Future<NextAvailableSlot?> Function(String branchId)? nextAvailableSlot,
  VoidCallback? onBook,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      home: OrganizationDetailScreen(
        organization: OrganizationDetail(
          slug: 'lexus',
          name: 'Lexus Service',
          phone: phone,
          branches: [branch ?? _branch()],
        ),
        status: OrganizationDetailStatus.data,
        errorMessage: null,
        onRetry: () {},
        onBack: () {},
        onBook: onBook ?? () {},
        nextAvailableSlot: nextAvailableSlot,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('leads with the identity row, actions and grouped info', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.text('LS'), findsOneWidget);
    expect(find.text('Lexus Service'), findsOneWidget);
    expect(find.text('Үндсэн салбар'), findsOneWidget);
    // No coordinates: call and share, but no directions.
    expect(find.byKey(const ValueKey('detail-action-call')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('detail-action-directions')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('detail-action-share')), findsOneWidget);
    expect(find.text('Баянзүрх, 26-р хороо, Нарны зам 18'), findsOneWidget);
    expect(find.text('Өнөөдөр 09:00–18:00'), findsOneWidget);
    expect(find.text('7011 6543'), findsOneWidget);
  });

  testWidgets('hides call without a phone number', (tester) async {
    await _pump(tester, phone: null);
    expect(find.byKey(const ValueKey('detail-action-call')), findsNothing);
    expect(find.byKey(const ValueKey('detail-phone-row')), findsNothing);
  });

  testWidgets('the hours row expands into the weekly schedule', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.text('Даваа'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('detail-hours-row')));
    await tester.pumpAndSettle();
    expect(find.text('Даваа'), findsOneWidget);
    expect(find.text('Ням'), findsOneWidget);
  });

  testWidgets('lists four services, then "Бүгд" reveals the rest', (
    tester,
  ) async {
    await _pump(tester, branch: _branch(categoryCount: 6));
    expect(find.text('Үйлчилгээ 4'), findsOneWidget);
    expect(find.text('Үйлчилгээ 5'), findsNothing);
    expect(find.text('~ 30 мин'), findsOneWidget);

    final all = find.byKey(const ValueKey('detail-services-all'));
    await tester.scrollUntilVisible(all, 200);
    await tester.tap(all);
    await tester.pumpAndSettle();
    expect(find.text('Үйлчилгээ 6', skipOffstage: false), findsOneWidget);
  });

  testWidgets('the booking bar shows the next free slot and books', (
    tester,
  ) async {
    var booked = 0;
    await _pump(
      tester,
      onBook: () => booked++,
      nextAvailableSlot: (_) async => NextAvailableSlot(
        dayOffset: 1,
        slot: AvailabilitySlot(
          hour: 11,
          minute: 0,
          available: true,
          remaining: 1,
          utc: DateTime.utc(2026, 10, 23, 3),
        ),
      ),
    );
    expect(find.text('Ойрын сул цаг'), findsOneWidget);
    expect(find.text('Маргааш 11:00'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('detail-book-button')));
    expect(booked, 1);
  });

  testWidgets('a failed slot lookup falls back to the open status', (
    tester,
  ) async {
    await _pump(
      tester,
      nextAvailableSlot: (_) async => throw Exception('offline'),
    );
    expect(find.text('Ойрын сул цаг'), findsNothing);
    // The booking bar falls back to the status line (the identity row shows
    // the open state as a badge instead).
    expect(find.byType(BranchOpenStatusLine), findsOneWidget);
  });
}
