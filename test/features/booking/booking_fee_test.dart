import 'package:carservice_customer/app/app_messages.dart';
import 'package:carservice_customer/app/theme/app_theme.dart';
import 'package:carservice_customer/core/errors/app_failure.dart';
import 'package:carservice_customer/core/network/api_client.dart';
import 'package:carservice_customer/features/booking/data/remote_appointment_repository.dart';
import 'package:carservice_customer/features/booking/domain/appointment_payment.dart';
import 'package:carservice_customer/features/booking/domain/appointment_repository.dart';
import 'package:carservice_customer/features/booking/domain/booking_fee_notice.dart';
import 'package:carservice_customer/features/booking/presentation/screens/appointment_payment_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockApiClient extends Mock implements ApiClient {}

class _NoopRepository extends Fake implements AppointmentRepository {}

void main() {
  group('bookingFeeNoticeFromJson', () {
    test('parses amount and ttl', () {
      final fee = bookingFeeNoticeFromJson({'amount': 2000, 'ttlMinutes': 15});
      expect(fee?.amount, 2000);
      expect(fee?.ttlMinutes, 15);
    });

    test('null, malformed or zero amount means free', () {
      expect(bookingFeeNoticeFromJson(null), isNull);
      expect(bookingFeeNoticeFromJson('x'), isNull);
      expect(bookingFeeNoticeFromJson({'amount': 0, 'ttlMinutes': 15}), isNull);
    });

    test('a missing ttl falls back to 15 minutes', () {
      expect(bookingFeeNoticeFromJson({'amount': 500})?.ttlMinutes, 15);
    });
  });

  group('RemoteAppointmentRepository.getBookingFee', () {
    test('reads the fee', () async {
      final client = _MockApiClient();
      when(() => client.getJson('/booking-fee')).thenAnswer(
        (_) async => {
          'fee': {'amount': 2000, 'ttlMinutes': 15},
        },
      );
      final fee = await RemoteAppointmentRepository(client).getBookingFee();
      expect(fee?.amount, 2000);
    });

    test('an older server without the endpoint (404) means no notice', () async {
      final client = _MockApiClient();
      when(
        () => client.getJson('/booking-fee'),
      ).thenThrow(const NotFoundFailure('Мэдээлэл олдсонгүй.'));
      expect(await RemoteAppointmentRepository(client).getBookingFee(), isNull);
    });
  });

  test('ulaanbaatarClock shows UTC+8 regardless of device timezone', () {
    expect(ulaanbaatarClock(DateTime.utc(2026, 11, 17, 2, 5)), '10:05');
    const fee = BookingFeeNotice(amount: 1000, ttlMinutes: 15);
    expect(
      ulaanbaatarClock(fee.payByFrom(DateTime.utc(2026, 11, 17, 15, 50))),
      '00:05',
    );
  });

  testWidgets('payment screen shows the pay-by deadline while pending', (
    tester,
  ) async {
    final payBy = DateTime.now().add(const Duration(minutes: 14));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        scaffoldMessengerKey: AppMessages.messengerKey,
        home: AppointmentPaymentScreen(
          appointmentId: 'apt-1',
          repository: _NoopRepository(),
          initialPayment: const AppointmentPayment(
            status: AppointmentFeeStatus.pending,
            amount: 1000,
            currency: 'MNT',
          ),
          payBy: payBy,
          onBack: () {},
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('payment-pay-by')), findsOneWidget);
    expect(
      find.textContaining('${ulaanbaatarClock(payBy)}-аас өмнө төлнө үү'),
      findsOneWidget,
    );
    // Dispose before the polling/hold timers fire.
    await tester.pumpWidget(const SizedBox());
  });
}
