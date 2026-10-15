import 'package:carservice_customer/app/app_messages.dart';
import 'package:carservice_customer/app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows a message on the root messenger, red for errors', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        scaffoldMessengerKey: AppMessages.messengerKey,
        home: const Scaffold(body: SizedBox.shrink()),
      ),
    );

    AppMessages.show('Утасны дугаар хууллаа');
    await tester.pump();
    expect(find.text('Утасны дугаар хууллаа'), findsOneWidget);
    expect(tester.widget<SnackBar>(find.byType(SnackBar)).backgroundColor, isNull);

    AppMessages.messengerKey.currentState!.removeCurrentSnackBar();
    AppMessages.show('Банкны апп нээгдсэнгүй.', isError: true);
    await tester.pump();
    expect(find.text('Банкны апп нээгдсэнгүй.'), findsOneWidget);
    expect(tester.widget<SnackBar>(find.byType(SnackBar)).backgroundColor, AppColors.red);
  });

  testWidgets('a message with no app attached is dropped, not thrown', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));

    expect(() => AppMessages.show('hello'), returnsNormally);
    await tester.pump();
    expect(find.byType(SnackBar), findsNothing);
  });
}
