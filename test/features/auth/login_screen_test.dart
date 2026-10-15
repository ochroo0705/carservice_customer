import 'package:carservice_customer/app/theme/app_theme.dart';
import 'package:carservice_customer/features/booking/auth/data/fake_auth_repository.dart';
import 'package:carservice_customer/features/booking/auth/presentation/auth_controller.dart';
import 'package:carservice_customer/features/booking/auth/presentation/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('a pasted number with the country code keeps the local 8 digits', (tester) async {
    final controller = AuthController(_CountingAuthRepository());
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: MaterialApp(
          theme: AppTheme.dark,
          home: LoginScreen(onBack: () {}, onOpenTerms: () {}, onOpenPrivacy: () {}),
        ),
      ),
    );
    await tester.enterText(find.byKey(const ValueKey('login-phone')), '+976 9911 2233');
    final field = tester.widget<TextField>(find.byKey(const ValueKey('login-phone')));
    expect(field.controller!.text, '99112233');
  });

  testWidgets('enables OTP resend after a 60 second cooldown', (tester) async {
    final repository = _CountingAuthRepository();
    final controller = AuthController(repository);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: MaterialApp(
          theme: AppTheme.dark,
          home: LoginScreen(onBack: () {}, onOpenTerms: () {}, onOpenPrivacy: () {}),
        ),
      ),
    );

    await tester.enterText(find.byKey(const ValueKey('login-phone')), '99112233');
    await tester.tap(find.text('Код авах →'));
    await tester.pump();

    expect(find.text('Код дахин авах (1:00)'), findsOneWidget);
    expect(
      tester.widget<TextButton>(find.widgetWithText(TextButton, 'Код дахин авах (1:00)')).onPressed,
      isNull,
    );

    await tester.pump(const Duration(seconds: 59));
    expect(find.text('Код дахин авах (0:01)'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Код дахин авах'), findsOneWidget);
    expect(
      tester.widget<TextButton>(find.widgetWithText(TextButton, 'Код дахин авах')).onPressed,
      isNotNull,
    );

    await tester.tap(find.text('Код дахин авах'));
    await tester.pump();
    expect(repository.requestCount, 2);
    expect(find.text('Код дахин авах (1:00)'), findsOneWidget);
  });

  testWidgets('signs in with phone + password from the password option', (tester) async {
    final repository = _CountingAuthRepository()..passwords['99112233'] = 'Shine2026';
    final controller = AuthController(repository);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: MaterialApp(
          theme: AppTheme.dark,
          home: LoginScreen(onBack: () {}, onOpenTerms: () {}, onOpenPrivacy: () {}),
        ),
      ),
    );

    await tester.enterText(find.byKey(const ValueKey('login-phone')), '99112233');
    await tester.tap(find.byKey(const ValueKey('login-use-password')));
    await tester.pump();

    // The typed phone carries over; no code is requested on the way.
    expect(find.text('Нэвтрэх'), findsOneWidget);
    final phone = tester.widget<TextField>(find.byKey(const ValueKey('login-phone')));
    expect(phone.controller!.text, '99112233');
    expect(find.byKey(const ValueKey('login-terms-notice')), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('login-password')), 'Buruu2026');
    await tester.tap(find.text('Нэвтрэх →'));
    await tester.pump();
    expect(find.text('Утасны дугаар эсвэл нууц үг буруу байна.'), findsOneWidget);
    expect(controller.isAuthenticated, isFalse);

    await tester.enterText(find.byKey(const ValueKey('login-password')), 'Shine2026');
    await tester.tap(find.text('Нэвтрэх →'));
    await tester.pump();
    expect(controller.isAuthenticated, isTrue);
    expect(repository.requestCount, 0);
  });

  testWidgets('the password field hides its text until toggled', (tester) async {
    final controller = AuthController(_CountingAuthRepository())..usePassword();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: MaterialApp(
          theme: AppTheme.dark,
          home: LoginScreen(onBack: () {}, onOpenTerms: () {}, onOpenPrivacy: () {}),
        ),
      ),
    );
    // initState resets the flow to the phone step; open the option again.
    await tester.tap(find.byKey(const ValueKey('login-use-password')));
    await tester.pump();

    TextField password() => tester.widget<TextField>(find.byKey(const ValueKey('login-password')));
    expect(password().obscureText, isTrue);
    await tester.tap(find.byTooltip('Нууц үг харуулах'));
    await tester.pump();
    expect(password().obscureText, isFalse);

    await tester.tap(find.byKey(const ValueKey('login-use-otp')));
    await tester.pump();
    expect(find.text('Код авах →'), findsOneWidget);
    expect(find.byKey(const ValueKey('login-password')), findsNothing);
  });
}

class _CountingAuthRepository extends FakeAuthRepository {
  int requestCount = 0;

  @override
  Future<void> requestOtp(String phone) async {
    requestCount++;
    await super.requestOtp(phone);
  }
}
