import 'package:carcare_customer_mobile/app/theme/app_theme.dart';
import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/features/booking/data/fake_appointment_repository.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_repository.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_status.dart';
import 'package:carcare_customer_mobile/features/booking/domain/service_progress.dart';
import 'package:carcare_customer_mobile/features/booking/domain/walk_in_order.dart';
import 'package:carcare_customer_mobile/features/booking/presentation/controllers/appointments_controller.dart';
import 'package:carcare_customer_mobile/features/booking/presentation/screens/appointment_detail_screen.dart';
import 'package:carcare_customer_mobile/features/booking/presentation/screens/walk_in_order_detail_screen.dart';
import 'package:carcare_customer_mobile/features/discovery/data/fake_organization_repository.dart';
import 'package:carcare_customer_mobile/features/history/data/fake_service_history_repository.dart';
import 'package:carcare_customer_mobile/features/history/domain/order_intake.dart';
import 'package:carcare_customer_mobile/features/history/domain/service_order_detail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

AppointmentServiceProgress _progress({required bool hasIntake}) =>
    AppointmentServiceProgress(
      id: 'order-1',
      number: 'A-1',
      status: ServiceProgressStatus.inProgress,
      items: const [],
      hasIntake: hasIntake,
    );

class _Repo extends Fake implements AppointmentRepository {
  _Repo({this.appointments = const [], this.walkIns = const []});
  final List<Appointment> appointments;
  final List<WalkInOrder> walkIns;

  @override
  Future<List<Appointment>> getAppointments() async => appointments;
  @override
  Future<List<WalkInOrder>> getWalkInOrders() async => walkIns;
}

class _HistoryRepo extends FakeServiceHistoryRepository {
  _HistoryRepo({this.failure, this.intake});
  final AppFailure? failure;
  final OrderIntake? intake;
  final requested = <String>[];

  @override
  Future<ServiceOrderDetail> getServiceOrderDetail(String id) async {
    requested.add(id);
    if (failure != null) throw failure!;
    final base = await super.getServiceOrderDetail('seed-history-1');
    return ServiceOrderDetail(
      order: base.order,
      items: const [],
      reports: const [],
      intake: intake,
    );
  }
}

Future<void> _pump(
  WidgetTester tester,
  AppointmentsController controller,
  Widget Function(_HistoryRepo) screen,
  _HistoryRepo history,
) async {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => screen(history)),
      GoRoute(
        path: '/orders/:id/intake',
        builder: (_, state) => Scaffold(
          body: Text('INTAKE:${(state.extra! as OrderIntake).notes}'),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: controller,
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final tileKey = find.byKey(const ValueKey('intake-tile'));
  final recorded = OrderIntake(
    recordedAt: DateTime(2026, 10, 1),
    notes: 'Тэмдэглэл',
  );

  WalkInOrder walkIn(bool has) => WalkInOrder(
    tenantName: 'Инфосистемс',
    tenantSlug: 'infosystems',
    branchName: 'Үндсэн салбар',
    progress: _progress(hasIntake: has),
  );

  Future<AppointmentsController> walkInController(bool has) async {
    final c = AppointmentsController(_Repo(walkIns: [walkIn(has)]));
    await c.load();
    addTearDown(c.dispose);
    return c;
  }

  Widget walkInScreen(_HistoryRepo h) => WalkInOrderDetailScreen(
    orderId: 'order-1',
    onBack: () {},
    historyRepository: h,
  );

  group('walk-in order detail', () {
    testWidgets('hides the tile without hasIntake', (tester) async {
      await _pump(
        tester,
        await walkInController(false),
        walkInScreen,
        _HistoryRepo(intake: recorded),
      );
      expect(tileKey, findsNothing);
    });

    testWidgets('shows the tile and loads then navigates on tap', (
      tester,
    ) async {
      final history = _HistoryRepo(intake: recorded);
      await _pump(tester, await walkInController(true), walkInScreen, history);
      expect(tileKey, findsOneWidget);
      await tester.tap(tileKey);
      await tester.pumpAndSettle();
      expect(history.requested, ['order-1']);
      expect(find.text('INTAKE:Тэмдэглэл'), findsOneWidget);
    });

    testWidgets('shows a Mongolian snackbar on failure and stays put', (
      tester,
    ) async {
      final history = _HistoryRepo(failure: const NetworkFailure());
      await _pump(tester, await walkInController(true), walkInScreen, history);
      await tester.tap(tileKey);
      await tester.pumpAndSettle();
      expect(find.text('Сүлжээний холболтоо шалгана уу.'), findsOneWidget);
      expect(tileKey, findsOneWidget);
      expect(find.textContaining('INTAKE'), findsNothing);
      expect(find.byKey(const ValueKey('intake-tile-loading')), findsNothing);
    });

    testWidgets('missing intake in the detail reports not found', (
      tester,
    ) async {
      await _pump(
        tester,
        await walkInController(true),
        walkInScreen,
        _HistoryRepo(),
      );
      await tester.tap(tileKey);
      await tester.pumpAndSettle();
      expect(find.text('Хүлээн авах бүртгэл олдсонгүй.'), findsOneWidget);
    });

    test('fake repositories expose a walk-in with matching intake', () async {
      final walkIns = await FakeAppointmentRepository().getWalkInOrders();
      final withIntake = walkIns.firstWhere((o) => o.progress.hasIntake);
      final detail = await FakeServiceHistoryRepository().getServiceOrderDetail(
        withIntake.progress.id,
      );
      expect(detail.intake, isNotNull);
    });
  });

  group('appointment detail', () {
    Appointment apt(bool has) => Appointment(
      id: 'apt-1',
      status: AppointmentStatus.confirmed,
      requestedAt: DateTime(2026, 10, 1, 10),
      tenantName: 'Инфосистемс',
      tenantSlug: 'infosystems',
      branchName: 'Үндсэн салбар',
      serviceProgress: _progress(hasIntake: has),
    );

    Future<AppointmentsController> controller(bool has) async {
      final c = AppointmentsController(_Repo(appointments: [apt(has)]));
      await c.load();
      addTearDown(c.dispose);
      return c;
    }

    Widget screen(_HistoryRepo h) => AppointmentDetailScreen(
      appointmentId: 'apt-1',
      organizationRepository: FakeOrganizationRepository(),
      onBack: () {},
      onPay: (_) {},
      historyRepository: h,
    );

    testWidgets('hides the tile without hasIntake', (tester) async {
      await _pump(
        tester,
        await controller(false),
        screen,
        _HistoryRepo(intake: recorded),
      );
      expect(tileKey, findsNothing);
    });

    testWidgets('shows the tile and navigates with the fetched intake', (
      tester,
    ) async {
      final history = _HistoryRepo(intake: recorded);
      await _pump(tester, await controller(true), screen, history);
      await tester.ensureVisible(tileKey);
      await tester.tap(tileKey);
      await tester.pumpAndSettle();
      expect(history.requested, ['order-1']);
      expect(find.text('INTAKE:Тэмдэглэл'), findsOneWidget);
    });
  });
}
