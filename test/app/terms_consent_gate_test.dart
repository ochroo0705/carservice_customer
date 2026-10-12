import 'package:carcare_customer_mobile/app/app.dart';
import 'package:carcare_customer_mobile/app/bootstrap_flags.dart';
import 'package:carcare_customer_mobile/app/customer_router.dart';
import 'package:carcare_customer_mobile/app/customer_routes.dart';
import 'package:carcare_customer_mobile/features/auth/data/fake_auth_repository.dart';
import 'package:carcare_customer_mobile/features/auth/domain/account.dart';
import 'package:carcare_customer_mobile/features/auth/presentation/login_screen.dart';
import 'package:carcare_customer_mobile/features/discovery/data/fake_organization_repository.dart';
import 'package:carcare_customer_mobile/features/legal/data/legal_consent_store.dart';
import 'package:carcare_customer_mobile/features/legal/presentation/screens/privacy_policy_screen.dart';
import 'package:carcare_customer_mobile/features/legal/presentation/screens/terms_consent_screen.dart';
import 'package:carcare_customer_mobile/features/legal/presentation/screens/terms_of_service_screen.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/mocks.dart';

void main() {
  setUpAll(() => debugDisableAppBootstrap = true);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('customerRedirect consent gate', () {
    String? r(String loc, {bool authed = true, bool pending = true}) =>
        customerRedirect(
          isAuthenticated: authed,
          uri: Uri.parse(loc),
          consentPending: pending,
        );

    test('a signed-in user who has not accepted goes to the consent page', () {
      expect(r('/'), '/terms-consent');
      expect(r('/organizations/x'), '/terms-consent?from=%2Forganizations%2Fx');
    });

    test('the intended page rides along in from', () {
      final to = r('/organizations/x/book?branch=b1&keys=a,b');
      expect(Uri.parse(to!).path, '/terms-consent');
      expect(
        Uri.parse(to).queryParameters['from'],
        '/organizations/x/book?branch=b1&keys=a,b',
      );
    });

    test('a fresh sign-in from login keeps the login from', () {
      expect(
        r('/login?from=%2Forganizations%2Fx%2Fbook'),
        '/terms-consent?from=%2Forganizations%2Fx%2Fbook',
      );
      expect(r('/login'), '/terms-consent');
    });

    test('the consent page and the bundled legal pages are not redirected', () {
      for (final loc in ['/terms-consent', '/terms', '/privacy']) {
        expect(r(loc), isNull, reason: loc);
      }
    });

    test('once accepted the consent page forwards to from, else home', () {
      expect(
        r('/terms-consent?from=%2Fappointments%2Fa1', pending: false),
        '/appointments/a1',
      );
      expect(r('/terms-consent', pending: false), '/');
      // An off-app target is never followed.
      expect(
        r('/terms-consent?from=https%3A%2F%2Fevil.example', pending: false),
        '/',
      );
    });

    test('accepted users are unaffected', () {
      expect(r('/organizations/x/book', pending: false), isNull);
      expect(
        r('/login?from=%2Forganizations%2Fx%2Fbook', pending: false),
        '/organizations/x/book',
      );
    });

    test('safeReturnLocation never returns the consent page or login', () {
      expect(safeReturnLocation('/terms-consent'), isNull);
      expect(safeReturnLocation('/terms-consent?from=%2Fx'), isNull);
      expect(safeReturnLocation('/login'), isNull);
      expect(safeReturnLocation('/appointments/a1'), '/appointments/a1');
    });

    test('the bundled legal pages stay open to guests', () {
      expect(r('/terms', authed: false), isNull);
      expect(r('/privacy', authed: false), isNull);
    });

    test('guests are never asked', () {
      expect(r('/', authed: false), isNull);
      expect(r('/organizations/x', authed: false), isNull);
      expect(
        r('/organizations/x/book', authed: false),
        startsWith('/login?from='),
      );
      // The consent page needs a signed-in customer.
      expect(r('/terms-consent', authed: false), '/');
    });
  });

  group('consent flow in the app', () {
    Future<LegalConsentStore> pump(WidgetTester tester) async {
      final store = LegalConsentStore();
      await tester.pumpWidget(
        CarCareCustomerApp(
          organizationRepository: FakeOrganizationRepository(
            delay: Duration.zero,
          ),
          authRepository: FakeAuthRepository(signedIn: true),
          legalConsentStore: store,
        ),
      );
      await tester.pumpAndSettle();
      return store;
    }

    testWidgets('a signed-in user who has not accepted is held on the page', (
      tester,
    ) async {
      await pump(tester);
      expect(find.byType(TermsConsentScreen), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('terms-consent-accept')),
            )
            .onPressed,
        isNull,
      );
    });

    testWidgets('accepting saves it and opens the app', (tester) async {
      final store = await pump(tester);
      // The box itself: the sentence's centre now lands on a link.
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('terms-consent-accept')));
      await tester.pumpAndSettle();

      expect(store.hasAccepted('fake-account'), isTrue);
      expect(find.byType(TermsConsentScreen), findsNothing);
    });

    testWidgets('the links open the bundled pages and back returns', (
      tester,
    ) async {
      await pump(tester);

      await tester.tap(find.byKey(const ValueKey('terms-consent-terms-link')));
      await tester.pumpAndSettle();
      expect(find.byType(TermsOfServiceScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('legal-open-on-web')), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('terms-consent-privacy-link')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PrivacyPolicyScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('legal-open-on-web')), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(TermsConsentScreen), findsOneWidget);
    });

    testWidgets(
      'the underlined names in the checkbox sentence open their pages',
      (tester) async {
        await pump(tester);
        final sentence = tester.widget<RichText>(
          find.descendant(
            of: find.byKey(const ValueKey('terms-consent-checkbox')),
            matching: find.byType(RichText),
          ),
        );
        void tapSpan(String text) {
          TapGestureRecognizer? recognizer;
          sentence.text.visitChildren((span) {
            if (span is TextSpan && span.text == text) {
              recognizer = span.recognizer as TapGestureRecognizer?;
              return false;
            }
            return true;
          });
          expect(recognizer, isNotNull, reason: '«$text» is not tappable');
          recognizer!.onTap!();
        }

        tapSpan('Үйлчилгээний нөхцөл');
        await tester.pumpAndSettle();
        expect(find.byType(TermsOfServiceScreen), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();

        tapSpan('Нууцлалын бодлого');
        await tester.pumpAndSettle();
        expect(find.byType(PrivacyPolicyScreen), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();

        // Following a link must not tick the box.
        expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
      },
    );

    testWidgets('declining signs out and leaves browsing open', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const ValueKey('terms-consent-decline')));
      await tester.pumpAndSettle();
      expect(find.byType(TermsConsentScreen), findsNothing);
      expect(
        find.text('Нөхцөлийг зөвшөөрөөгүй тул системээс гарлаа.'),
        findsOneWidget,
      );
    });

    group('signing in is the acceptance', () {
      Future<GoRouter> pumpGuest(
        WidgetTester tester,
        LegalConsentStore store,
      ) async {
        await tester.pumpWidget(
          CarCareCustomerApp(
            organizationRepository: FakeOrganizationRepository(
              delay: Duration.zero,
            ),
            authRepository: FakeAuthRepository(),
            legalConsentStore: store,
          ),
        );
        await tester.pumpAndSettle();
        return GoRouter.of(tester.element(find.byType(Scaffold).first));
      }

      Future<void> signInThroughLoginPage(WidgetTester tester) async {
        await tester.enterText(
          find.byKey(const ValueKey('login-phone')),
          '99112233',
        );
        await tester.tap(find.byType(FilledButton));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('login-terms-notice')),
          findsOneWidget,
        );
        await tester.enterText(
          find.byKey(const ValueKey('login-otp')),
          '123456',
        );
        await tester.tap(find.byType(FilledButton));
        await tester.pumpAndSettle();
      }

      List<String> stack(GoRouter router) => [
        for (final m in router.routerDelegate.currentConfiguration.matches)
          m.matchedLocation,
      ];

      testWidgets('records acceptance and never shows the consent page', (
        tester,
      ) async {
        final store = LegalConsentStore();
        final router = await pumpGuest(tester, store);
        router.push('/login');
        await tester.pumpAndSettle();

        await signInThroughLoginPage(tester);

        expect(store.hasAccepted('fake-account'), isTrue);
        expect(find.byType(LoginScreen), findsNothing);
        expect(find.byType(TermsConsentScreen), findsNothing);
      });

      testWidgets(
        'a guest booking resumes on top of the page it came from; back returns there',
        (tester) async {
          final router = await pumpGuest(tester, LegalConsentStore());
          router.push(CustomerRoutes.organization('auto-doctor'));
          await tester.pumpAndSettle();
          // A guest opening booking is sent to login with `from` = booking.
          router.push(CustomerRoutes.booking('auto-doctor'));
          await tester.pumpAndSettle();
          expect(find.byType(LoginScreen), findsOneWidget);

          await signInThroughLoginPage(tester);

          expect(find.byType(TermsConsentScreen), findsNothing);
          expect(stack(router), [
            '/',
            '/organizations/auto-doctor',
            '/organizations/auto-doctor/book',
          ]);

          router.pop();
          await tester.pumpAndSettle();
          expect(stack(router), ['/', '/organizations/auto-doctor']);
        },
      );

      testWidgets('the terms line opens the bundled pages over login', (
        tester,
      ) async {
        final router = await pumpGuest(tester, LegalConsentStore());
        router.push('/login');
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('login-phone')),
          '99112233',
        );
        await tester.tap(find.byType(FilledButton));
        await tester.pumpAndSettle();

        final notice = tester.widget<RichText>(
          find.descendant(
            of: find.byKey(const ValueKey('login-terms-notice')),
            matching: find.byType(RichText),
          ),
        );
        void tapSpan(String text) {
          TapGestureRecognizer? recognizer;
          notice.text.visitChildren((span) {
            if (span is TextSpan && span.text == text) {
              recognizer = span.recognizer as TapGestureRecognizer?;
              return false;
            }
            return true;
          });
          recognizer!.onTap!();
        }

        tapSpan('Үйлчилгээний нөхцөл');
        await tester.pumpAndSettle();
        expect(find.byType(TermsOfServiceScreen), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();

        tapSpan('Нууцлалын бодлого');
        await tester.pumpAndSettle();
        expect(find.byType(PrivacyPolicyScreen), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();
        // Still mid sign-in, on the code step.
        expect(find.byKey(const ValueKey('login-otp')), findsOneWidget);
      });
    });

    testWidgets(
      'a restored session for an account that has not accepted is still asked',
      (tester) async {
        const a = Account(id: 'acc-a', phone: '99112233');
        const b = Account(id: 'acc-b', phone: '88112233');
        final store = LegalConsentStore();
        await store.accept(a.id);

        Future<void> launchAs(Account account) async {
          await tester.pumpWidget(
            CarCareCustomerApp(
              key: ValueKey(account.id),
              organizationRepository: FakeOrganizationRepository(
                delay: Duration.zero,
              ),
              authRepository: signedInAuthRepository(account: account),
              legalConsentStore: store,
            ),
          );
          await tester.pumpAndSettle();
        }

        await launchAs(a);
        expect(find.byType(TermsConsentScreen), findsNothing);
        await launchAs(b);
        expect(find.byType(TermsConsentScreen), findsOneWidget);
      },
    );
  });
}
