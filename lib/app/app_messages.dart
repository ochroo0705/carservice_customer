import 'package:carservice_customer/app/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// The app's one channel for short transient messages ("Машин нэмэгдлээ.",
/// a failed action, "Утасны дугаар хууллаа"). Call [show] from anywhere —
/// no `BuildContext`, no `ScaffoldMessenger.of(context)` in screens.
///
/// Messages go to the single root messenger ([messengerKey], attached to
/// `MaterialApp.scaffoldMessengerKey` in `app.dart`), so they all look the
/// same and outlive the page that raised them. Until the key is attached
/// (e.g. a widget test that pumps a screen in a bare `MaterialApp`),
/// messages are dropped.
abstract final class AppMessages {
  static final messengerKey = GlobalKey<ScaffoldMessengerState>();

  /// Queues [message] after any message already showing. [isError] tints it
  /// red for a failure the user should notice.
  static void show(String message, {bool isError = false}) {
    messengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.red : null,
      ),
    );
  }
}
