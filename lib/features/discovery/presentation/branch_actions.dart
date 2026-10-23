import 'package:carservice_customer/app/app_messages.dart';
import 'package:carservice_customer/features/discovery/services/location_permission_service.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Starts a phone call to a branch from the dialer.
Future<void> callBranchPhone(String phone) async {
  try {
    final ok = await launchUrl(Uri(scheme: 'tel', path: phone));
    if (!ok) throw Exception('launch returned false');
  } catch (_) {
    AppMessages.show('Залгах боломжгүй байна');
  }
}

/// Opens a branch's coordinates in the platform's own map app.
///
/// With location permission, opens turn-by-turn directions (the map app
/// routes from the user's position). Without it, just drops a pin — a plain
/// "show me where" tap shouldn't force a permission prompt.
Future<void> openBranchDirections({
  required double latitude,
  required double longitude,
}) async {
  final destination = '$latitude,$longitude';
  LocationAccessState access;
  try {
    access = await const PermissionHandlerLocationPermissionService().check();
  } catch (_) {
    access = LocationAccessState.denied;
  }
  final directions = access == LocationAccessState.granted;
  // Prefer each platform's native map app: Apple Maps on iOS, Google Maps
  // on Android. Both are https universal links, so if the native app is
  // absent they still open in the browser.
  final Uri uri;
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    uri = directions
        ? Uri.parse('https://maps.apple.com/?daddr=$destination&dirflg=d')
        : Uri.parse('https://maps.apple.com/?q=$destination');
  } else {
    uri = directions
        ? Uri.parse(
            'https://www.google.com/maps/dir/?api=1&destination=$destination',
          )
        : Uri.parse(
            'https://www.google.com/maps/search/?api=1&query=$destination',
          );
  }
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) throw Exception('launch returned false');
  } catch (_) {
    AppMessages.show('Газрын зураг нээх боломжгүй байна');
  }
}
