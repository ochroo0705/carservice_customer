import 'package:carcare_customer_mobile/app/app.dart';
import 'package:carcare_customer_mobile/app/bootstrap_flags.dart';
import 'package:carcare_customer_mobile/app/customer_routes.dart';
import 'package:carcare_customer_mobile/features/auth/data/fake_auth_repository.dart';
import 'package:carcare_customer_mobile/features/auth/presentation/auth_controller.dart';
import 'package:carcare_customer_mobile/features/auth/presentation/login_screen.dart';
import 'package:carcare_customer_mobile/features/discovery/data/fake_organization_repository.dart';
import 'package:carcare_customer_mobile/features/legal/data/legal_consent_store.dart';
import 'package:carcare_customer_mobile/features/legal/presentation/screens/terms_consent_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Signing in must close the login page whichever way it was opened. Every
/// failure here looks the same on a phone: the phone-number step again.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget app() => CarCareCustomerApp(
    organizationRepository: FakeOrganizationRepository(delay: Duration.zero),
    authRepository: FakeAuthRepository(),
    legalConsentStore: LegalConsentStore(),
  );

  GoRouter routerOf(WidgetTester tester) =>
      GoRouter.of(tester.element(find.byType(Scaffold).first));

  List<String> stack(GoRouter router) => [
    for (final m in router.routerDelegate.currentConfiguration.matches)
      m.matchedLocation,
  ];

  Future<void> signIn(WidgetTester tester) async {
    await tester.enterText(
      find.byKey(const ValueKey('login-phone')),
      '99112233',
    );
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('login-otp')), '123456');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
  }

  testWidgets('onboarding "sign in" → OTP closes login onto home', (
    tester,
  ) async {
    debugDisableAppBootstrap = false;
    addTearDown(() => debugDisableAppBootstrap = true);

    await tester.pumpWidget(app());
    // Splash floor + settle + fade; its animations loop, so pump by time.
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    await tester.tap(find.byKey(const ValueKey('onboarding-welcome-login')));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    // Login sits on top of home, not alone with an empty location.
    expect(stack(routerOf(tester)), ['/', '/login']);

    await signIn(tester);

    expect(find.byType(LoginScreen), findsNothing);
    expect(find.byType(TermsConsentScreen), findsNothing);
    expect(stack(routerOf(tester)), ['/']);
  });

  group('with bootstrap off', () {
    setUpAll(() => debugDisableAppBootstrap = true);

    testWidgets('plain login (no from) pops back to where it opened', (
      tester,
    ) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      final router = routerOf(tester);
      router.push(CustomerRoutes.organization('auto-doctor'));
      await tester.pumpAndSettle();
      router.push(CustomerRoutes.login());
      await tester.pumpAndSettle();

      await signIn(tester);

      expect(find.byType(LoginScreen), findsNothing);
      expect(stack(router), ['/', '/organizations/auto-doctor']);
    });

    testWidgets('login with from replaces itself with from', (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      final router = routerOf(tester);
      router.push(CustomerRoutes.login(from: CustomerRoutes.notifications));
      await tester.pumpAndSettle();

      await signIn(tester);

      expect(stack(router), ['/', '/notifications']);
    });

    testWidgets('login as the whole stack goes home after sign-in', (
      tester,
    ) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      final router = routerOf(tester);
      router.go(CustomerRoutes.login());
      await tester.pumpAndSettle();
      expect(stack(router), ['/login']);

      await signIn(tester);

      expect(find.byType(LoginScreen), findsNothing);
      expect(stack(router), ['/']);
    });

    testWidgets('a push tap while signed out resumes on the target', (
      tester,
    ) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      final router = routerOf(tester);
      // What `CustomerNavigation.openFromPush` does for a signed-out tap.
      router.go(CustomerRoutes.shell);
      router.push(CustomerRoutes.login(from: CustomerRoutes.notifications));
      await tester.pumpAndSettle();

      await signIn(tester);

      expect(stack(router), ['/', '/notifications']);
    });

    testWidgets('reopening login after sign-out starts on the phone step', (
      tester,
    ) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      final router = routerOf(tester);
      router.push(CustomerRoutes.login());
      await tester.pumpAndSettle();
      await signIn(tester);

      await tester
          .element(find.byType(Scaffold).first)
          .read<AuthController>()
          .signOut();
      await tester.pumpAndSettle();
      router.push(CustomerRoutes.login());
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('login-phone')), findsOneWidget);
      expect(find.byKey(const ValueKey('login-otp')), findsNothing);
    });
  });
}
