import 'package:carcare_customer_mobile/app/app.dart';
import 'package:carcare_customer_mobile/app/bootstrap_flags.dart';
import 'package:carcare_customer_mobile/features/auth/data/fake_auth_repository.dart';
import 'package:carcare_customer_mobile/features/discovery/data/fake_organization_repository.dart';
import 'package:carcare_customer_mobile/features/legal/presentation/screens/privacy_policy_screen.dart';
import 'package:carcare_customer_mobile/features/legal/presentation/screens/terms_of_service_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() => debugDisableAppBootstrap = true);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> openProfile(WidgetTester tester) async {
    await tester.pumpWidget(
      CarCareCustomerApp(
        organizationRepository: FakeOrganizationRepository(
          delay: Duration.zero,
        ),
        authRepository: FakeAuthRepository(signedIn: true),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('discovery-map-list-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('shell-avatar')));
    await tester.pumpAndSettle();
  }

  Future<void> tapTile(WidgetTester tester, String key) async {
    final tile = find.byKey(ValueKey(key));
    await tester.scrollUntilVisible(
      tile,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(tile);
    await tester.pumpAndSettle();
  }

  testWidgets('the terms tile opens the bundled terms and back returns', (
    tester,
  ) async {
    await openProfile(tester);
    await tapTile(tester, 'profile-terms-tile');
    expect(find.byType(TermsOfServiceScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('legal-open-on-web')), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(TermsOfServiceScreen), findsNothing);
  });

  testWidgets('the privacy tile opens the bundled policy', (tester) async {
    await openProfile(tester);
    await tapTile(tester, 'profile-privacy-tile');
    expect(find.byType(PrivacyPolicyScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('legal-open-on-web')), findsOneWidget);
  });

  testWidgets('guests can read both legal pages from the profile tab', (
    tester,
  ) async {
    await tester.pumpWidget(
      CarCareCustomerApp(
        organizationRepository: FakeOrganizationRepository(
          delay: Duration.zero,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Профайл'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('profile-login')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('profile-privacy-tile')));
    await tester.pumpAndSettle();
    expect(find.byType(PrivacyPolicyScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('profile-terms-tile')));
    await tester.pumpAndSettle();
    expect(find.byType(TermsOfServiceScreen), findsOneWidget);
  });
}
