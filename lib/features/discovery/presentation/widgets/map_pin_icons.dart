import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:carservice_customer/app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// The map pins of the 2026-11 design: every branch is a small white circle
/// carrying the Carservice mark in navy, and the selected one turns into an
/// accent pill with the organization's name (see [loadLabeledPinIcon]).
/// [selected] / [selectedClosed] are unlabeled fallbacks shown until the
/// named pill is drawn; the selected pin turns grey once its branch's loaded
/// hours say it's closed — marker data carries no hours, so unselected pins
/// never claim open/closed.
typedef MapPinIcons = ({
  BitmapDescriptor pin,
  BitmapDescriptor selected,
  BitmapDescriptor selectedClosed,
});

const _pixelRatio = 3.0;
const _closedFill = Color(0xFF5D6D7E); // --oc-muted4 (dark)
const _navy = Color(0xFF2C3E50);
const _accentPin = AppColors.accentLightText; // the design's pin red

Future<MapPinIcons> loadMapPinIcons({required Brightness brightness}) async {
  final data = await rootBundle.load('assets/brand/mark.png');
  final codec = await ui.instantiateImageCodec(
    data.buffer.asUint8List(),
    targetWidth: 192,
  );
  final logo = (await codec.getNextFrame()).image;
  final dark = brightness == Brightness.dark;
  final icons = await Future.wait([
    _createCirclePin(
      logo,
      fill: dark ? AppColors.darkSurface : Colors.white,
      glyph: dark ? AppColors.darkText : _navy,
      border: dark ? AppColors.darkBorder : null,
      radius: 17,
    ),
    _createCirclePin(
      logo,
      fill: _accentPin,
      glyph: Colors.white,
      ring: Colors.white,
      radius: 20,
    ),
    _createCirclePin(
      logo,
      fill: _closedFill,
      glyph: Colors.white,
      ring: Colors.white,
      radius: 20,
    ),
  ]);
  logo.dispose();
  codec.dispose();
  return (pin: icons[0], selected: icons[1], selectedClosed: icons[2]);
}

Future<BitmapDescriptor> _createCirclePin(
  ui.Image logo, {
  required Color fill,
  required Color glyph,
  required double radius,
  Color? ring,
  Color? border,
}) async {
  const shadowPad = 4.0;
  final ringWidth = ring == null ? 0.0 : 3.0;
  final outer = radius + ringWidth;
  final size = 2 * (outer + shadowPad);
  final center = Offset(size / 2, size / 2);

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(_pixelRatio);
  final disc = Path()..addOval(Rect.fromCircle(center: center, radius: outer));
  canvas.drawShadow(disc, _navy, 3, false);
  if (ring != null) canvas.drawCircle(center, outer, Paint()..color = ring);
  canvas.drawCircle(center, radius, Paint()..color = fill);
  if (border != null) {
    canvas.drawCircle(
      center,
      radius - 0.5,
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }
  final glyphSize = radius * 1.05;
  canvas.drawImageRect(
    logo,
    Rect.fromLTWH(0, 0, logo.width.toDouble(), logo.height.toDouble()),
    Rect.fromCenter(center: center, width: glyphSize, height: glyphSize),
    Paint()
      ..filterQuality = FilterQuality.high
      ..colorFilter = ColorFilter.mode(glyph, BlendMode.srcIn),
  );
  return _encode(recorder, size, size);
}

/// The selected pin: an accent pill (grey while the branch is closed)
/// carrying [label], with a small tail pointing at the branch. Anchor it at
/// (0.5, 1).
Future<BitmapDescriptor> loadLabeledPinIcon({
  required String label,
  bool closed = false,
}) async {
  const maxTextWidth = 180.0;
  const horizontalPadding = 12.0;
  const pillHeight = 30.0;
  const tail = 6.0;
  const shadowPad = 6.0;

  final text = label.trim();
  final painter = TextPainter(
    text: TextSpan(
      text: text.isEmpty ? '•' : text,
      style: const TextStyle(
        fontFamily: AppFonts.sans,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Colors.white,
        letterSpacing: 0.2,
      ),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
    ellipsis: '…',
  )..layout(maxWidth: maxTextWidth);

  final pillWidth = painter.width + 2 * horizontalPadding;
  final width = pillWidth + 2 * shadowPad;
  final height = shadowPad + pillHeight + tail;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(_pixelRatio);
  final pill = RRect.fromRectAndRadius(
    Rect.fromLTWH(shadowPad, shadowPad, pillWidth, pillHeight),
    const Radius.circular(pillHeight / 2),
  );
  final tailPath = Path()
    ..moveTo(width / 2 - tail, shadowPad + pillHeight - 1)
    ..lineTo(width / 2, shadowPad + pillHeight + tail)
    ..lineTo(width / 2 + tail, shadowPad + pillHeight - 1)
    ..close();
  final shape = Path()
    ..addRRect(pill)
    ..addPath(tailPath, Offset.zero);
  canvas.drawShadow(shape, _navy, 4, false);
  canvas.drawPath(shape, Paint()..color = closed ? _closedFill : _accentPin);
  painter.paint(
    canvas,
    Offset(
      shadowPad + horizontalPadding,
      shadowPad + (pillHeight - painter.height) / 2,
    ),
  );
  painter.dispose();
  return _encode(recorder, width, height);
}

Future<BitmapDescriptor> _encode(
  ui.PictureRecorder recorder,
  double width,
  double height,
) async {
  final image = await recorder.endRecording().toImage(
    math.max(1, (width * _pixelRatio).ceil()),
    math.max(1, (height * _pixelRatio).ceil()),
  );
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  if (bytes == null) throw StateError('Could not render map pin');
  return BitmapDescriptor.bytes(
    bytes.buffer.asUint8List(),
    imagePixelRatio: _pixelRatio,
  );
}
