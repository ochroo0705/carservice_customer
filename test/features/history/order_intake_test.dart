import 'package:carservice_customer/app/theme/app_theme.dart';
import 'package:carservice_customer/features/history/data/fake_service_history_repository.dart';
import 'package:carservice_customer/features/history/data/service_order_dto.dart';
import 'package:carservice_customer/features/history/domain/order_intake.dart';
import 'package:carservice_customer/features/history/domain/service_order_detail.dart';
import 'package:carservice_customer/features/history/domain/upload_url.dart';
import 'package:carservice_customer/features/history/presentation/controllers/history_controller.dart';
import 'package:carservice_customer/features/history/presentation/screens/order_intake_screen.dart';
import 'package:carservice_customer/features/history/presentation/screens/service_order_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Map<String, dynamic> _order(Object? intake, {bool withKey = true}) => {
  'id': 'ord-1',
  'paymentStatus': 'PAID',
  'completedAt': '2026-09-01T10:00:00.000Z',
  'createdAt': '2026-08-30T10:00:00.000Z',
  'totalAmount': 1000,
  'paidAmount': 1000,
  'tenant': {'name': 'X', 'slug': 'x'},
  'branch': {'name': 'B'},
  if (withKey) 'intake': intake,
};

void main() {
  group('intake parsing', () {
    test('missing key and null give null', () {
      expect(
        serviceOrderDetailFromJson(_order(null, withKey: false)).intake,
        isNull,
      );
      expect(serviceOrderDetailFromJson(_order(null)).intake, isNull);
    });

    test('parses a full intake', () {
      final intake = serviceOrderDetailFromJson(
        _order({
          'notes': 'Зураас',
          'photos': [
            {'id': 'p1', 'url': '/uploads/a.jpg'},
            {'id': 'p2', 'url': '/uploads/b.jpg'},
          ],
          'signatureUrl': '/uploads/sig.png',
          'recordedAt': '2026-08-30T10:00:00.000Z',
          'recordedBy': null,
        }),
      ).intake!;
      expect(intake.notes, 'Зураас');
      expect(intake.photos.map((p) => p.id), ['p1', 'p2']);
      expect(intake.signatureUrl, '/uploads/sig.png');
      expect(intake.recordedAt, DateTime.utc(2026, 8, 30, 10).toLocal());
    });

    test('skips malformed photo entries', () {
      final intake = serviceOrderDetailFromJson(
        _order({
          'notes': null,
          'photos': [
            {'id': 'p1', 'url': '/uploads/a.jpg'},
            {'id': 'p2'},
            {'url': '/uploads/c.jpg'},
            'junk',
            {'id': 5, 'url': '/uploads/d.jpg'},
          ],
          'signatureUrl': null,
          'recordedAt': '2026-08-30T10:00:00.000Z',
        }),
      ).intake!;
      expect(intake.photos.map((p) => p.id), ['p1']);
      expect(intake.notes, isNull);
      expect(intake.signatureUrl, isNull);
    });
  });

  group('intake mileage', () {
    OrderIntake? parse(Object? km) => serviceOrderDetailFromJson(
      _order({'recordedAt': '2026-08-30T10:00:00.000Z', 'mileageKm': km}),
    ).intake;

    test('parses num to int, else null', () {
      expect(parse(152300)!.mileageKm, 152300);
      expect(parse(152300.0)!.mileageKm, 152300);
      expect(parse(null)!.mileageKm, isNull);
      expect(parse('152300')!.mileageKm, isNull);
    });

    test('label groups thousands', () {
      expect(parse(152300)!.mileageLabel, '152,300 км');
      expect(parse(0)!.mileageLabel, '0 км');
      expect(parse(2000000)!.mileageLabel, '2,000,000 км');
      expect(parse(null)!.mileageLabel, isNull);
    });

    testWidgets('intake page shows the mileage row', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: OrderIntakeScreen(
            intake: OrderIntake(
              recordedAt: DateTime(2026, 8, 30, 10, 5),
              mileageKm: 152300,
            ),
          ),
        ),
      );
      expect(find.text('Гүйлт: 152,300 км'), findsOneWidget);
    });

    testWidgets('intake page omits the row when null', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: OrderIntakeScreen(
            intake: OrderIntake(recordedAt: DateTime(2026, 8, 30, 10, 5)),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('intake-mileage')), findsNothing);
    });
  });

  group('resolveUploadUrl', () {
    const base = 'https://api.carservice.mn:8443/api/v1/app';
    test('prefixes relative paths with the API origin', () {
      expect(
        resolveUploadUrl('/uploads/a.jpg', baseUrl: base),
        'https://api.carservice.mn:8443/uploads/a.jpg',
      );
      expect(
        resolveUploadUrl(
          'uploads/a.jpg',
          baseUrl: 'http://10.0.2.2:4000/api/v1/app',
        ),
        'http://10.0.2.2:4000/uploads/a.jpg',
      );
    });

    test('passes absolute URLs through', () {
      expect(
        resolveUploadUrl('https://cdn.x/y.png', baseUrl: base),
        'https://cdn.x/y.png',
      );
    });
  });

  group('detail screen intake tile', () {
    Future<void> pump(WidgetTester tester, OrderIntake? intake) async {
      final repo = FakeServiceHistoryRepository();
      final base = await repo.getServiceOrderDetail('seed-history-1');
      final detail = ServiceOrderDetail(
        order: base.order,
        items: base.items,
        intake: intake,
      );
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, _) => ServiceOrderDetailScreen(
              repository: _StubRepo(detail),
              orderId: 'seed-history-1',
              onBack: () {},
              historyController: HistoryController(repo),
            ),
            routes: [
              GoRoute(
                path: 'orders/:id/intake',
                builder: (context, state) =>
                    OrderIntakeScreen(intake: state.extra! as OrderIntake),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('hidden when intake is null', (tester) async {
      await pump(tester, null);
      expect(find.byKey(const ValueKey('intake-tile')), findsNothing);
    });

    testWidgets('shown and opens the intake page', (tester) async {
      await pump(
        tester,
        OrderIntake(
          recordedAt: DateTime(2026, 8, 30, 10, 5),
          notes: 'Урд бампер зураастай',
          photos: const [OrderIntakePhoto(id: 'p1', url: '/uploads/a.jpg')],
        ),
      );
      expect(find.text('Хүлээн авах'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('intake-tile')));
      await tester.pumpAndSettle();
      expect(find.text('Урд бампер зураастай'), findsOneWidget);
      expect(find.text('Бүртгэсэн: 2026.08.30 10:05'), findsOneWidget);
      expect(find.byKey(const ValueKey('intake-photo-0')), findsOneWidget);
    });
  });
}

class _StubRepo extends FakeServiceHistoryRepository {
  _StubRepo(this._detail);
  final ServiceOrderDetail _detail;

  @override
  Future<ServiceOrderDetail> getServiceOrderDetail(String id) async => _detail;
}
