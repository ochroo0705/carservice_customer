import 'package:carservice_customer/app/theme/app_theme.dart';
import 'package:carservice_customer/features/legal/presentation/screens/terms_consent_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Finder accept() => find.byKey(const ValueKey('terms-consent-accept'));

  testWidgets('accept stays disabled until the box is checked', (tester) async {
    var accepted = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: TermsConsentScreen(
          onAccept: () async => accepted++,
          onDecline: () async {},
        ),
      ),
    );

    expect(tester.widget<FilledButton>(accept()).onPressed, isNull);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(tester.widget<FilledButton>(accept()).onPressed, isNotNull);

    await tester.tap(accept());
    await tester.pump();
    expect(accepted, 1);

    // Unchecking disables it again.
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(tester.widget<FilledButton>(accept()).onPressed, isNull);
  });
}
