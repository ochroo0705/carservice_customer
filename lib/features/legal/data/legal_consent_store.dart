import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether each signed-in customer on this device accepted the current
/// Үйлчилгээний нөхцөл and Нууцлалын бодлого. Device-only (no API): one
/// shared_preferences entry per user id, kept across logout so the same user
/// is asked once per [currentVersion].
///
/// The router listens to this and holds a signed-in user on the consent page
/// until [accept]. Storage is best-effort: if a read or write fails the
/// acceptance still holds for this run, so nobody gets stuck.
class LegalConsentStore extends ChangeNotifier {
  LegalConsentStore({Future<SharedPreferences> Function()? loadPreferences})
    : _loadPreferences = loadPreferences ?? SharedPreferences.getInstance;

  static final instance = LegalConsentStore();

  /// The terms' effective date. Bump it together with the two screens'
  /// `effectiveDate` to ask every user again.
  static const currentVersion = '2026-09-30';

  static const _keyPrefix = 'legal_consent_v1_';

  final Future<SharedPreferences> Function() _loadPreferences;
  SharedPreferences? _prefs;

  /// Accepted this run, whatever the storage managed to keep.
  final _acceptedThisRun = <String>{};

  /// Loads the saved acceptances so [hasAccepted] can answer synchronously
  /// (the router asks during redirect). A failure just means "nobody has
  /// accepted yet".
  Future<void> init() async {
    try {
      _prefs = await _loadPreferences();
    } catch (_) {
      _prefs = null;
    }
  }

  bool hasAccepted(String userId) {
    if (_acceptedThisRun.contains(userId)) return true;
    try {
      return _prefs?.getString('$_keyPrefix$userId') == currentVersion;
    } catch (_) {
      return false;
    }
  }

  Future<void> accept(String userId) async {
    _acceptedThisRun.add(userId);
    notifyListeners();
    try {
      final prefs = _prefs ??= await _loadPreferences();
      await prefs.setString('$_keyPrefix$userId', currentVersion);
    } catch (_) {
      // Non-fatal: the user is asked again next launch.
    }
  }
}
