import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:carservice_customer/app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// The branded map pins: a cyan disc carrying the Carservice mark, ringed in
/// the map's own background tone so it stands off the tiles, with a small
/// diamond tail. The selected pin is larger, white-ringed with a soft halo,
/// and turns grey once its branch's loaded hours say it's closed — marker
/// data carries no hours, so unselected pins never claim open/closed.
typedef MapPinIcons = ({
  BitmapDescriptor pin,
  BitmapDescriptor selected,
  BitmapDescriptor selectedClosed,
});

const _closedFill = Color(0xFF5B6474);
const _selectedRing = Color(0xFFF2F4F8);
const _glyphInk = Color(0xFF0B0F1A);

Future<MapPinIcons> loadMapPinIcons({required Brightness brightness}) async {
  final data = await rootBundle.load('assets/brand/mark.png');
  final codec = await ui.instantiateImageCodec(
    data.buffer.asUint8List(),
    targetWidth: 192,
  );
  final logo = (await codec.getNextFrame()).image;
  final ring = brightness == Brightness.dark
      ? AppColors.darkBackground
      : Colors.white;
  final icons = await Future.wait([
    _createPinIcon(logo, fill: AppColors.accent, ring: ring, selected: false),
    _createPinIcon(
      logo,
      fill: AppColors.accent,
      ring: _selectedRing,
      selected: true,
    ),
    _createPinIcon(logo, fill: _closedFill, ring: _selectedRing, selected: true),
  ]);
  logo.dispose();
  codec.dispose();
  return (pin: icons[0], selected: icons[1], selectedClosed: icons[2]);
}

Future<BitmapDescriptor> _createPinIcon(
  ui.Image logo, {
  required Color fill,
  required Color ring,
  required bool selected,
}) async {
  const pixelRatio = 3.0;
  final fillRadius = selected ? 28.0 : 20.0;
  final ringWidth = selected ? 4.0 : 3.0;
  final halo = selected ? 8.0 : 0.0;
  final glyph = selected ? 28.0 : 20.0;
  final tailSide = selected ? 12.0 : 10.0;

  final outer = fillRadius + ringWidth;
  final width = 2 * (outer + halo);
  final center = Offset(width / 2, halo + outer);
  // The tail is a square turned 45°, its centre just inside the ring's
  // bottom edge so its lower corner points at the branch. The marker's
  // anchor is the canvas bottom, so the canvas ends at that corner.
  final tailCenter = center.translate(0, outer - 2);
  final tailReach = tailSide * math.sqrt2 / 2;
  final height = tailCenter.dy + tailReach;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(pixelRatio);

  final disc = Path()
    ..addOval(Rect.fromCircle(center: center, radius: outer));
  canvas.drawShadow(disc, Colors.black, 3, false);
  if (selected) {
    canvas.drawCircle(
      center,
      outer + halo,
      Paint()..color = _selectedRing.withValues(alpha: 0.14),
    );
  }
  canvas.drawCircle(center, outer, Paint()..color = ring);
  canvas.drawCircle(center, fillRadius, Paint()..color = fill);

  canvas
    ..save()
    ..translate(tailCenter.dx, tailCenter.dy)
    ..rotate(math.pi / 4)
    ..drawRect(
      Rect.fromCenter(center: Offset.zero, width: tailSide, height: tailSide),
      Paint()..color = selected ? ring : fill,
    )
    ..restore();

  canvas.drawImageRect(
    logo,
    Rect.fromLTWH(0, 0, logo.width.toDouble(), logo.height.toDouble()),
    Rect.fromCenter(center: center, width: glyph, height: glyph),
    Paint()
      ..filterQuality = FilterQuality.high
      ..colorFilter = const ColorFilter.mode(_glyphInk, BlendMode.srcIn),
  );

  final image = await recorder.endRecording().toImage(
    (width * pixelRatio).round(),
    (height * pixelRatio).ceil(),
  );
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  if (bytes == null) throw StateError('Could not render map pin');
  return BitmapDescriptor.bytes(
    bytes.buffer.asUint8List(),
    imagePixelRatio: pixelRatio,
  );
}
