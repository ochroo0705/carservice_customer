import 'dart:async';

import 'package:carservice_customer/app/app.dart';
import 'package:carservice_customer/app/app_dependencies.dart';
import 'package:carservice_customer/core/analytics/analytics_service.dart';
import 'package:carservice_customer/core/notifications/local_push_service.dart';
import 'package:carservice_customer/core/notifications/remote_push_service.dart';
import 'package:carservice_customer/data/cache/cache_database.dart';
import 'package:carservice_customer/data/cache/drift_cache_store.dart';
import 'package:carservice_customer/features/legal/data/legal_consent_store.dart';
import 'package:carservice_customer/features/onboarding/data/onboarding_store.dart';
import 'package:carservice_customer/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Must be top-level (not a method/closure) — the plugin may run this in a
/// background isolate that never ran `main()`, so Firebase needs its own
/// initialization here too. Background/terminated `notification`-block
/// messages are otherwise displayed by the OS automatically; this handler
/// only needs to exist so the plugin doesn't warn about a missing one and so
/// data-only messages don't get silently dropped in the background.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Bundled `.env` asset, read by `AppEnvironment`. Optional so an empty file
  // still boots on the defaults instead of crashing at launch.
  await dotenv.load(isOptional: true);
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Route uncaught errors to Crashlytics. Collection is disabled in debug so
  // local runs don't pollute production crash data; release/profile builds
  // report. `recordFlutterFatalError` handles framework build/layout errors;
  // the platformDispatcher hook catches uncaught async errors outside Flutter.
  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  // One composition root: USE_FAKE_API picks fake or remote for every feature
  // at once, and all authenticated repositories share one ApiClient.
  final dependencies = AppDependencies.build(
    cacheStore: DriftCacheStore(CacheDatabase()),
    remotePushService: FirebaseRemotePushService(),
    analytics: FirebaseAnalyticsService(),
  );
  // Who accepted the terms, checked by the router after sign-in.
  await LegalConsentStore.instance.init();
  runApp(CarserviceApp.fromDependencies(dependencies));

  // Deferred until after the first frame so launch is never gated on them.
  // `requestPermission()` in particular blocks on the OS permission dialog
  // on first run; the local-notification channel setup is a plugin round-trip.
  // Neither needs to complete before the UI is visible — a foreground push in
  // the brief window before this finishes is the only edge, and it's rare.
  unawaited(_initPushNotifications());
}

Future<void> _initPushNotifications() async {
  // On first run, onboarding's permission page owns the notification prompt, so
  // don't ask here (it would fire before onboarding is even shown). On later
  // runs, request as before — harmless if already granted/denied.
  // Local banners are initialised first so a foreground push that arrives
  // while the OS permission dialog is up is not dropped.
  await LocalPushService.instance.initialize();
  // iOS only (no-op on Android): show foreground pushes as system banners.
  // Without this firebase_messaging answers iOS's foreground-presentation
  // query with "none" for every notification, the app's own banners included.
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );
  if (await const OnboardingStore().hasCompleted()) {
    await FirebaseMessaging.instance.requestPermission();
  }
  if (kDebugMode) {
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    debugPrint('Notification permission: ${settings.authorizationStatus.name}');
  }
}
