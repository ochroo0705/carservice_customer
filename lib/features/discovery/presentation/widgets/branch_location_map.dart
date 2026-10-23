import 'package:carservice_customer/app/theme/app_theme.dart';
import 'package:carservice_customer/features/discovery/presentation/widgets/map_pin_icons.dart';
import 'package:carservice_customer/features/discovery/services/map_configuration_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// The detail page's header strip: a still map centred on the branch with
/// its pin, its bottom corners rounded off. Deliberately inert — no
/// gestures, lite mode on Android — since the page scrolls past it and the
/// directions action hands off to a real map app. Falls back to a plain
/// tinted band when the branch has no coordinates or Maps isn't configured.
///
/// Nothing is drawn over the map's lower part: Flutter content layered on a
/// native map inside a scroll view doesn't composite reliably on iOS, and
/// the Google logo down there must stay visible.
class BranchLocationMap extends StatefulWidget {
  const BranchLocationMap({
    required this.latitude,
    required this.longitude,
    required this.closed,
    required this.height,
    this.mapConfigurationService = const NativeMapConfigurationService(),
    super.key,
  });

  final double? latitude;
  final double? longitude;

  /// The branch is closed right now — its pin turns grey, as on the map.
  final bool closed;
  final double height;
  final MapConfigurationService mapConfigurationService;

  @override
  State<BranchLocationMap> createState() => _BranchLocationMapState();
}

class _BranchLocationMapState extends State<BranchLocationMap> {
  bool _configured = false;
  MapPinIcons? _pins;
  Brightness? _brightness;
  String? _lightStyle;
  String? _darkStyle;

  LatLng? get _position {
    final latitude = widget.latitude;
    final longitude = widget.longitude;
    return latitude == null || longitude == null
        ? null
        : LatLng(latitude, longitude);
  }

  @override
  void initState() {
    super.initState();
    if (_position != null) _initialize();
  }

  Future<void> _initialize() async {
    final configured = await widget.mapConfigurationService.isConfigured();
    if (!mounted || !configured) return;
    final styles = await Future.wait([
      rootBundle.loadString('assets/maps/light.json'),
      rootBundle.loadString('assets/maps/dark.json'),
    ]);
    if (!mounted) return;
    setState(() {
      _configured = true;
      _lightStyle = styles[0];
      _darkStyle = styles[1];
    });
    _loadPins();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final brightness = Theme.of(context).brightness;
    if (brightness == _brightness) return;
    _brightness = brightness;
    if (_configured) _loadPins();
  }

  Future<void> _loadPins() async {
    final brightness = _brightness ?? Brightness.light;
    final pins = await loadMapPinIcons(brightness: brightness);
    if (!mounted || brightness != _brightness) return;
    setState(() => _pins = pins);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final position = _position;
    final pins = _pins;
    return SizedBox(
      height: widget.height,
      child: position != null && _configured
          ? ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(24),
              ),
              child: IgnorePointer(
                child: Semantics(
                  image: true,
                  label: 'Салбарын байршлын газрын зураг',
                  child: ExcludeSemantics(
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: position,
                        zoom: 15,
                      ),
                      style: dark ? _darkStyle : _lightStyle,
                      // Centres the pin below the status bar and back button.
                      padding: EdgeInsets.only(
                        top: MediaQuery.paddingOf(context).top + 24,
                      ),
                      markers: {
                        Marker(
                          markerId: const MarkerId('branch'),
                          position: position,
                          anchor: const Offset(0.5, 1),
                          icon:
                              (widget.closed
                                  ? pins?.selectedClosed
                                  : pins?.selected) ??
                              BitmapDescriptor.defaultMarker,
                          visible: pins != null,
                        ),
                      },
                      liteModeEnabled: true,
                      zoomGesturesEnabled: false,
                      scrollGesturesEnabled: false,
                      rotateGesturesEnabled: false,
                      tiltGesturesEnabled: false,
                      zoomControlsEnabled: false,
                      myLocationButtonEnabled: false,
                      mapToolbarEnabled: false,
                      compassEnabled: false,
                      buildingsEnabled: false,
                    ),
                  ),
                ),
              ),
            )
          : DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.accent.withValues(alpha: dark ? 0.18 : 0.14),
                    AppColors.accent.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
    );
  }
}
