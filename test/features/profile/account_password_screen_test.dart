import 'package:carservice_customer/app/theme/app_theme.dart';
import 'package:carservice_customer/features/booking/auth/data/fake_auth_repository.dart';
import 'package:carservice_customer/features/profile/presentation/screens/account_password_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<List<bool>> _pumpScreen(WidgetTester tester, FakeAuthRepository repository) async {
  final changes = <bool>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: AccountPasswordScreen(repository: repository, onPasswordChanged: changes.add),
    ),
  );
  await tester.pump();
  return changes;
}

void main() {
  testWidgets('sets a first password with the code sent to the phone', (tester) async {
    final repository = FakeAuthRepository(signedIn: true);
    final changes = await _pumpScreen(tester, repository);

    expect(find.textContaining('Нууц үг тохируулаагүй'), findsOneWidget);
    expect(find.byKey(const ValueKey('password-action-remove')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('password-action-save')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('password-request-otp')));
    await tester.pump();
    expect(find.text('******33 руу код илгээлээ'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('password-code')), '123456');
    await tester.enterText(find.byKey(const ValueKey('password-new')), 'Shine2026');
    await tester.enterText(find.byKey(const ValueKey('password-confirmation')), 'Shine2027');
    await tester.tap(find.byKey(const ValueKey('password-submit')));
    await tester.pump();
    expect(find.text('Нууц үг таарахгүй байна.'), findsOneWidget);
    expect(changes, isEmpty);

    await tester.enterText(find.byKey(const ValueKey('password-confirmation')), 'Shine2026');
    await tester.tap(find.byKey(const ValueKey('password-submit')));
    await tester.pump();

    expect(repository.passwords['99112233'], 'Shine2026');
    // The confirmation goes out through the callback (the router turns it
    // into the app's global message), not a snackbar from this page.
    expect(changes, [true]);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.textContaining('Нууц үг тохируулсан.'), findsOneWidget);
    expect(find.byKey(const ValueKey('password-action-remove')), findsOneWidget);
  });

  testWidgets('removes the password without asking for a new one', (tester) async {
    final repository = FakeAuthRepository(signedIn: true)
      ..passwords['99112233'] = 'Shine2026';
    final changes = await _pumpScreen(tester, repository);

    await tester.tap(find.byKey(const ValueKey('password-action-remove')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('password-request-otp')));
    await tester.pump();
    expect(find.byKey(const ValueKey('password-new')), findsNothing);

    await tester.enterText(find.byKey(const ValueKey('password-code')), '123456');
    await tester.tap(find.byKey(const ValueKey('password-submit')));
    await tester.pump();

    expect(repository.passwords, isEmpty);
    expect(changes, [false]);
    expect(find.textContaining('Нууц үг тохируулаагүй'), findsOneWidget);
  });

  testWidgets('back from a step returns to the overview', (tester) async {
    await _pumpScreen(tester, FakeAuthRepository(signedIn: true));

    await tester.tap(find.byKey(const ValueKey('password-action-save')));
    await tester.pump();
    expect(find.byKey(const ValueKey('password-request-otp')), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pump();
    expect(find.byKey(const ValueKey('password-status')), findsOneWidget);
  });
}
