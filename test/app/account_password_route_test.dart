import 'package:carservice_customer/app/app.dart';
import 'package:carservice_customer/app/bootstrap_flags.dart';
import 'package:carservice_customer/features/booking/auth/data/fake_auth_repository.dart';
import 'package:carservice_customer/features/discovery/data/fake_organization_repository.dart';
import 'package:carservice_customer/features/profile/presentation/screens/account_password_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Profile → Нууц үг opens the password page on the router's stack, and a
/// change is confirmed through the app's global message (the root
/// messenger behind `CustomerAppServices.showMessage`), not by the page.
void main() {
  setUpAll(() => debugDisableAppBootstrap = true);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('saving a password shows the global confirmation', (tester) async {
    final auth = FakeAuthRepository(signedIn: true);
    await tester.pumpWidget(
      CarserviceApp(
        organizationRepository: FakeOrganizationRepository(delay: Duration.zero),
        authRepository: auth,
      ),
    );
    await tester.pumpAndSettle();
    // Discover opens on the map, which hides the shell AppBar/avatar.
    await tester.tap(find.byKey(const ValueKey('discovery-map-list-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('shell-avatar')));
    await tester.pumpAndSettle();

    final tile = find.byKey(const ValueKey('profile-password-tile'));
    await tester.scrollUntilVisible(tile, 200, scrollable: find.byType(Scrollable).last);
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(find.byType(AccountPasswordScreen), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('password-action-save')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('password-request-otp')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('password-code')), '123456');
    await tester.enterText(find.byKey(const ValueKey('password-new')), 'Shine2026');
    await tester.enterText(find.byKey(const ValueKey('password-confirmation')), 'Shine2026');
    await tester.tap(find.byKey(const ValueKey('password-submit')));
    await tester.pump();

    expect(auth.passwords['99112233'], 'Shine2026');
    expect(find.text('Нууц үг хадгалагдлаа.'), findsOneWidget);
  });
}
