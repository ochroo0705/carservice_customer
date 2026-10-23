import 'package:carservice_customer/app/theme/app_theme.dart';
import 'package:carservice_customer/features/discovery/data/fake_organization_repository.dart';
import 'package:carservice_customer/features/discovery/domain/branch.dart';
import 'package:carservice_customer/features/discovery/domain/organization.dart';
import 'package:carservice_customer/features/discovery/presentation/branch_open_style.dart';
import 'package:carservice_customer/features/discovery/presentation/controllers/discovery_controller.dart';
import 'package:carservice_customer/features/discovery/presentation/controllers/organization_detail_controller.dart';
import 'package:carservice_customer/features/discovery/presentation/widgets/branch_card.dart';
import 'package:carservice_customer/features/discovery/presentation/widgets/discovery_header.dart';
import 'package:carservice_customer/features/discovery/presentation/widgets/organization_avatar.dart';
import 'package:carservice_customer/features/discovery/presentation/widgets/selected_branch_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
  theme: AppTheme.dark,
  home: Scaffold(body: child),
);

void main() {
  group('branchOpenHint', () {
    BranchDetail branch({
      String? openTime = '09:00',
      String? closeTime = '18:00',
      List<BranchScheduleRule> schedules = const [],
    }) => BranchDetail(
      id: 'b',
      name: 'Branch',
      city: '',
      district: '',
      khoroo: '',
      address: '',
      openTime: openTime,
      closeTime: closeTime,
      schedules: schedules,
    );

    String? hintAt(BranchDetail subject, DateTime now) =>
        branchOpenHint(subject, subject.openStatusAt(now), now);

    test('says when an open branch closes', () {
      expect(hintAt(branch(), DateTime(2026, 9, 1, 12)), '18:00 хүртэл');
    });

    test('says when a closed branch opens later today', () {
      expect(
        hintAt(branch(), DateTime(2026, 9, 1, 7, 30)),
        '09:00-д нээгдэнэ',
      );
    });

    test('rolls over to tomorrow once today\'s hours are over', () {
      expect(
        hintAt(branch(), DateTime(2026, 9, 1, 19)),
        'Маргааш 09:00-д нээгдэнэ',
      );
    });

    test('skips a day the weekday schedule keeps closed', () {
      final now = DateTime(2026, 9, 1, 12);
      // Weekday codes as the schedule resolver derives them (business day,
      // UTC+8), so the test doesn't depend on the machine's time zone.
      const codes = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];
      String code(DateTime value) =>
          codes[value.toUtc().add(const Duration(hours: 8)).weekday % 7];
      final subject = branch(
        schedules: [
          BranchScheduleRule(weekday: code(now), isOpen: false),
          BranchScheduleRule(
            weekday: code(now.add(const Duration(days: 1))),
            isOpen: true,
            openTime: '10:00',
            closeTime: '16:00',
          ),
        ],
      );
      expect(hintAt(subject, now), 'Маргааш 10:00-д нээгдэнэ');
    });

    test('has nothing to add without usable hours', () {
      expect(
        hintAt(branch(openTime: null, closeTime: null), DateTime(2026, 9, 1)),
        isNull,
      );
    });
  });

  test('organizationInitials takes the first letters of two words', () {
    expect(organizationInitials('Lexus Service'), 'LS');
    expect(organizationInitials('  хурд   моторс '), 'ХМ');
    expect(organizationInitials('Toyota'), 'T');
    expect(organizationInitials(''), '?');
  });

  testWidgets('quick filter chips toggle open-now and a single tag', (
    tester,
  ) async {
    final controller = DiscoveryController(
      FakeOrganizationRepository(delay: Duration.zero),
    );
    addTearDown(controller.dispose);
    await controller.loadTagOptions();
    await tester.pumpWidget(
      _host(
        ListenableBuilder(
          listenable: controller,
          builder: (_, _) => DiscoveryQuickFilters(controller: controller),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('discovery-chip-open-now')));
    await tester.pumpAndSettle();
    expect(controller.openNow, isTrue);

    final wash = find.byKey(const ValueKey('discovery-chip-tag-car-wash-tag'));
    final tire = find.byKey(const ValueKey('discovery-chip-tag-tire-shop-tag'));
    await tester.tap(wash);
    await tester.pumpAndSettle();
    expect(controller.tag, 'car-wash-tag');

    await tester.tap(tire);
    await tester.pumpAndSettle();
    expect(controller.tag, 'tire-shop-tag');

    // Tapping the active tag clears it.
    await tester.tap(tire);
    await tester.pumpAndSettle();
    expect(controller.tag, isEmpty);
  });

  testWidgets('list card leads with the organization, then branch · distance', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(
        BranchCard(
          organization: const Organization(
            slug: 'lexus',
            name: 'Lexus Service',
            branches: [],
          ),
          branch: const Branch(
            id: 'main',
            name: 'Үндсэн салбар',
            city: 'Улаанбаатар',
            district: 'Сүхбаатар',
            distanceKm: 1.25,
            tags: [
              BranchTagOption(id: '1', name: 'Тоормос'),
              BranchTagOption(id: '2', name: 'Хөдөлгүүр'),
              BranchTagOption(id: '3', name: 'Тос солих'),
              BranchTagOption(id: '4', name: 'Угаалга'),
            ],
          ),
          onTap: () => taps++,
        ),
      ),
    );

    expect(find.text('LS'), findsOneWidget);
    expect(find.text('Lexus Service'), findsOneWidget);
    expect(find.text('Үндсэн салбар · 1.3 км'), findsOneWidget);
    expect(find.text('Улаанбаатар · Сүхбаатар'), findsOneWidget);
    expect(find.text('Тос солих'), findsOneWidget);
    expect(find.text('Угаалга'), findsNothing);
    expect(find.text('+1'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('branch-lexus-main')));
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  testWidgets('map sheet shows loaded hours and wires its actions', (
    tester,
  ) async {
    final detail = OrganizationDetailController(
      FakeOrganizationRepository(delay: Duration.zero),
    );
    addTearDown(detail.dispose);
    await detail.load('auto-doctor');
    final calls = <String>[];
    await tester.pumpWidget(
      _host(
        Align(
          alignment: Alignment.bottomCenter,
          child: SelectedBranchSheet(
            organization: const Organization(
              slug: 'auto-doctor',
              name: 'Auto Doctor Service',
              branches: [],
            ),
            branch: const Branch(
              id: 'auto-doctor-bzd',
              name: 'Баянзүрх салбар',
              city: 'Улаанбаатар',
              district: 'Баянзүрх',
              latitude: 47.9187,
              longitude: 106.9684,
            ),
            detailController: detail,
            onClose: () => calls.add('close'),
            onDetails: () => calls.add('details'),
            onBook: () => calls.add('book'),
          ),
        ),
      ),
    );

    expect(find.text('Auto Doctor Service'), findsOneWidget);
    expect(find.text('Баянзүрх салбар'), findsOneWidget);
    expect(find.text('26-р хороо, Нарны зам 18'), findsOneWidget);
    expect(find.text('09:00–19:00'), findsOneWidget);
    expect(find.text('Тос солих'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('selected-branch-call')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('selected-branch-directions')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('selected-branch-book')));
    await tester.tap(find.byKey(const ValueKey('selected-branch-details')));
    await tester.tap(find.byKey(const ValueKey('selected-branch-handle')));
    expect(calls, ['book', 'details', 'close']);
  });
}
