import 'package:carservice_customer/features/legal/data/legal_consent_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const key = 'legal_consent_v1_u1';

  test('nobody has accepted on a fresh device', () async {
    SharedPreferences.setMockInitialValues({});
    final store = LegalConsentStore();
    await store.init();
    expect(store.hasAccepted('u1'), isFalse);
  });

  test('accept is saved and survives a restart', () async {
    SharedPreferences.setMockInitialValues({});
    final store = LegalConsentStore();
    await store.init();
    await store.accept('u1');
    expect(store.hasAccepted('u1'), isTrue);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(key), LegalConsentStore.currentVersion);

    final relaunched = LegalConsentStore();
    await relaunched.init();
    expect(relaunched.hasAccepted('u1'), isTrue);
  });

  test('an older accepted version asks again', () async {
    SharedPreferences.setMockInitialValues({key: '2026-01-01'});
    final store = LegalConsentStore();
    await store.init();
    expect(store.hasAccepted('u1'), isFalse);
  });

  test('acceptance is per user', () async {
    SharedPreferences.setMockInitialValues({});
    final store = LegalConsentStore();
    await store.init();
    await store.accept('u1');
    expect(store.hasAccepted('u1'), isTrue);
    expect(store.hasAccepted('u2'), isFalse);
  });

  test('accept notifies listeners', () async {
    SharedPreferences.setMockInitialValues({});
    final store = LegalConsentStore();
    var notified = 0;
    store.addListener(() => notified++);
    await store.accept('u1');
    expect(notified, 1);
  });

  test('a failing storage still holds the acceptance for this run', () async {
    final store = LegalConsentStore(
      loadPreferences: () async => throw Exception('disk full'),
    );
    await store.init();
    expect(store.hasAccepted('u1'), isFalse);

    await store.accept('u1');
    expect(store.hasAccepted('u1'), isTrue);
    expect(store.hasAccepted('u2'), isFalse);
  });
}
