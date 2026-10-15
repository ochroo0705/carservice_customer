import 'dart:async';

import 'package:carservice_customer/features/legal/data/legal_consent_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _mapChannel = MethodChannel(
  'mn.infosystems.carservice/map_configuration',
);

/// Discover opens on the map by default (2026-09-17), so every widget test
/// that mounts the app lands on it. Left unmocked, the map-configuration
/// channel throws `MissingPluginException`, which
/// `NativeMapConfigurationService.isConfigured()` treats as "configured" —
/// the map then sits on its looping loading spinner forever, hanging any
/// `pumpAndSettle()` call in tests that have nothing to do with the map.
///
/// Default every test to "unconfigured" instead, which renders a static,
/// one-shot overlay. Tests that actually exercise map behavior install their
/// own handler and restore it in `tearDown`.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        _mapChannel,
        (call) async => call.method == 'isConfigured' ? false : null,
      );
  // Signing in now lands on the terms page until the user accepts. Tests that
  // are about something else sign in as one of these accounts (see
  // `signedInAuthRepository`, `FakeAuthRepository`), so they start accepted;
  // consent tests use their own `LegalConsentStore`, not this one.
  for (final userId in const ['1', 'fake-account', 'a']) {
    LegalConsentStore.instance.accept(userId).ignore();
  }
  await testMain();
}
