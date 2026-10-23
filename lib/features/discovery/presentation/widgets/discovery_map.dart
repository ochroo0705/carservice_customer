import 'dart:async';
import 'dart:math' as math;

import 'package:carservice_customer/core/widgets/measure_size.dart';
import 'package:carservice_customer/features/discovery/domain/branch.dart';
import 'package:carservice_customer/features/discovery/domain/organization.dart';
import 'package:carservice_customer/features/discovery/presentation/controllers/organization_detail_controller.dart';
import 'package:carservice_customer/features/discovery/presentation/widgets/discovery_map_overlays.dart';
import 'package:carservice_customer/features/discovery/presentation/widgets/location_permission_banner.dart';
import 'package:carservice_customer/features/discovery/presentation/widgets/map_pin_icons.dart';
import 'package:carservice_customer/features/discovery/presentation/widgets/map_snapshot.dart';
import 'package:carservice_customer/features/discovery/presentation/widgets/selected_branch_sheet.dart';
import 'package:carservice_customer/features/discovery/services/device_location_service.dart';
import 'package:carservice_customer/features/discovery/services/location_permission_service.dart';
import 'package:carservice_customer/features/discovery/services/map_configuration_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class DiscoveryMap extends StatefulWidget {
  const DiscoveryMap({
    required this.organizations,
    this.hasActiveFilters = false,
    required this.onBranchSelected,
    this.onBookRequested,
    required this.onShowList,
    required this.organizationDetailController,
    this.onViewportChanged,
    this.refitSignal,
    this.height = 430,
    this.topPadding = 0,
    this.bottomControlsBuilder,
    this.showLocationBanner = true,
    this.onLocationAccessChanged,
    this.locationPermissionService =
        const PermissionHandlerLocationPermissionService(),
    this.mapConfigurationService = const NativeMapConfigurationService(),
    this.deviceLocationService = const GeolocatorDeviceLocationService(),
    super.key,
  });

  final List<Organization> organizations;
  final bool hasActiveFilters;
  final void Function(Organization organization, Branch branch)
  onBranchSelected;
  // The selected-branch sheet's "Цаг захиалах". Falls back to
  // [onBranchSelected] (the detail page, which has its own booking button).
  final void Function(Organization organization, Branch branch)?
  onBookRequested;
  final VoidCallback onShowList;
  // Пин дарахад дэлгэрэнгүй (цаг/хаяг/утас/ангилал) картыг web-тэй ижил
  // түвшинд харуулахын тулд тухайн байгууллагын дэлгэрэнгүйг цөөнгүй
  // ачаална — жагсаалтын `Organization`/`Branch`-д эдгээр талбар алга.
  final OrganizationDetailController organizationDetailController;
  final ValueChanged<LatLngBounds>? onViewportChanged;
  // Bumping this (e.g. DiscoveryController.mapRefitSignal) tells the map a
  // search/filter change just produced new results, so it should recenter
  // on them even though [onViewportChanged] otherwise disables auto-fit to
  // avoid fighting the user's own panning/zooming.
  final int? refitSignal;
  final double height;
  // How much of the map's top a parent's floating overlay covers (the
  // discovery screen's search header) — passed to Google Maps as padding so
  // fit-to-results, centering and the platform's own UI avoid it.
  final double topPadding;
  // Controls the parent floats along the map's bottom edge (list toggle,
  // locate-me). Built here rather than by the parent so they ride on top of
  // the selected-branch sheet, and can hide what the sheet replaces.
  final Widget Function(
    BuildContext context, {
    required bool sheetVisible,
    required bool mapReady,
  })?
  bottomControlsBuilder;
  // A parent with its own top overlay (the discovery screen's floating
  // search bar) sets this false and renders [LocationPermissionBanner]
  // itself, below that overlay, driven by [onLocationAccessChanged] and
  // [DiscoveryMapState.requestLocationPermission] / [openLocationSettings].
  final bool showLocationBanner;
  final ValueChanged<LocationAccessState>? onLocationAccessChanged;
  final LocationPermissionService locationPermissionService;
  final MapConfigurationService mapConfigurationService;
  final DeviceLocationService deviceLocationService;

  @override
  State<DiscoveryMap> createState() => DiscoveryMapState();
}

/// Public so a parent screen can drive zoom/locate-me from its own custom
/// buttons (e.g. a combined bottom-right control stack) via a `GlobalKey`,
/// instead of Google Maps' own platform controls, which can't be
/// repositioned or restyled.
class DiscoveryMapState extends State<DiscoveryMap>
    with WidgetsBindingObserver {
  LocationAccessState? _locationAccessState;
  ({Organization organization, Branch branch})? _selected;
  MapPinIcons? _pins;
  // The theme the pins were drawn for — their ring matches the map's
  // background, so a theme switch redraws them.
  Brightness? _pinBrightness;
  bool _configured = false;
  // Height of the docked selected-branch sheet, reported after layout; the
  // map is padded by it so the Google logo and the selection stay visible.
  double _sheetHeight = 0;
  String? _lightMapStyle;
  String? _darkMapStyle;
  Timer? _initializationTimer;
  _MapLoadState _mapLoadState = _MapLoadState.loading;
  int _mapInstance = 0;
  GoogleMapController? _mapController;
  LatLngBounds? _visibleBounds;

  static const _ulaanbaatar = LatLng(47.918, 106.917);

  static List<LatLng> _mapPositions(List<Organization> organizations) => [
    for (final organization in organizations)
      for (final branch in organization.branches)
        if (branch.latitude != null && branch.longitude != null)
          LatLng(branch.latitude!, branch.longitude!),
  ];

  static String _locationSignature(List<Organization> organizations) {
    final entries = [
      for (final organization in organizations)
        for (final branch in organization.branches)
          if (branch.latitude != null && branch.longitude != null)
            '${organization.slug}:${branch.id}:${branch.latitude}:${branch.longitude}',
    ];
    entries.sort();
    return entries.join('|');
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.organizationDetailController.addListener(_handleDetailChanged);
    _initializeMap();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final brightness = Theme.of(context).brightness;
    if (brightness == _pinBrightness) return;
    _pinBrightness = brightness;
    if (_configured) _loadPinIcons();
  }

  void _handleDetailChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant DiscoveryMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refitSignal != null &&
        widget.refitSignal != oldWidget.refitSignal) {
      _visibleBounds = null;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _fitCameraToLocations(),
      );
      return;
    }
    // Viewport-backed marker responses are otherwise incremental data
    // updates (plain panning/zooming). Fitting here would recenter the
    // camera after every response and trigger another camera-idle request
    // indefinitely.
    if (widget.onViewportChanged != null) return;
    if (oldWidget.hasActiveFilters == widget.hasActiveFilters &&
        _locationSignature(oldWidget.organizations) ==
            _locationSignature(widget.organizations)) {
      return;
    }
    _visibleBounds = null;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _fitCameraToLocations(),
    );
  }

  Future<void> _initializeMap() async {
    final configured = await widget.mapConfigurationService.isConfigured();
    if (!mounted) return;
    if (!configured) {
      setState(() => _mapLoadState = _MapLoadState.unavailable);
      return;
    }
    _configured = true;
    // Check only — onboarding already offered the prompt. Asking again here
    // would spend iOS's single prompt (and one of Android's two) on a user
    // who just skipped it; the banner and locate-me ask on an explicit tap.
    _checkLocationPermission();
    _loadPinIcons();
    _loadMapStyles();
    _startInitializationTimer();
  }

  void _startInitializationTimer() {
    _initializationTimer?.cancel();
    _initializationTimer = Timer(const Duration(seconds: 12), () {
      if (!mounted || _mapLoadState == _MapLoadState.ready) return;
      setState(() => _mapLoadState = _MapLoadState.failed);
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _initializationTimer?.cancel();
    if (!mounted) return;
    setState(() => _mapLoadState = _MapLoadState.ready);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _fitCameraToLocations(),
    );
  }

  void _retryMap() {
    if (_mapLoadState == _MapLoadState.unavailable) return;
    _mapController?.dispose();
    _mapController = null;
    setState(() {
      _mapLoadState = _MapLoadState.loading;
      _mapInstance++;
      _visibleBounds = null;
    });
    _startInitializationTimer();
  }

  Future<void> _loadMapStyles() async {
    final styles = await Future.wait([
      rootBundle.loadString('assets/maps/light.json'),
      rootBundle.loadString('assets/maps/dark.json'),
    ]);
    if (!mounted) return;
    setState(() {
      _lightMapStyle = styles[0];
      _darkMapStyle = styles[1];
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.organizationDetailController.removeListener(_handleDetailChanged);
    _initializationTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _locationAccessState != LocationAccessState.granted) {
      _checkLocationPermission();
    }
  }

  Future<void> requestLocationPermission() async {
    _setLocationAccess(await widget.locationPermissionService.request());
  }

  Future<void> _checkLocationPermission() async {
    _setLocationAccess(await widget.locationPermissionService.check());
  }

  void _setLocationAccess(LocationAccessState status) {
    if (!mounted) return;
    setState(() => _locationAccessState = status);
    widget.onLocationAccessChanged?.call(status);
  }

  Future<void> openLocationSettings() async {
    await widget.locationPermissionService.openSettings();
  }

  /// Stand-in for Google Maps' own locate-me button, which (like the zoom
  /// control) is pinned by the platform and can't be moved or restyled.
  Future<void> locateMe() async {
    final controller = _mapController;
    if (controller == null) return;
    // current() prompts if still undecided; re-read the result so the
    // banner and blue dot follow whatever the user just chose.
    final location = await widget.deviceLocationService.current();
    if (!mounted) return;
    await _checkLocationPermission();
    if (location == null || !mounted) return;
    await controller.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(location.lat, location.lng), 15),
    );
  }

  Future<void> _updateVisibleRegion() async {
    final controller = _mapController;
    if (controller == null || _mapLoadState != _MapLoadState.ready) return;
    try {
      final bounds = await controller.getVisibleRegion();
      if (!mounted) return;
      setState(() => _visibleBounds = bounds);
      widget.onViewportChanged?.call(bounds);
    } catch (_) {
      // The dependable list remains available if the native view disappears.
    }
  }

  /// Сонгосон салбарын картыг хаана. Газрын зураг дээрх хоосон хэсэгт
  /// хүрэхэд (`GoogleMap.onTap`) болон картын өөрийн хаах товчинд хоёуланд
  /// хэрэглэгдэнэ. `onTap` нь пин эсвэл кластер дээрх хүрэлтэнд ажиллахгүй
  /// тул өөр пин дарахад карт хаагдалгүй тэр салбар руу шилжинэ.
  void _dismissSelection() {
    if (_selected == null) return;
    setState(() => _selected = null);
  }

  void _handleSheetSize(Size size) {
    if (!mounted || (size.height - _sheetHeight).abs() < 1) return;
    setState(() => _sheetHeight = size.height);
  }

  Future<void> _handleClusterTap(Cluster cluster) async {
    final controller = _mapController;
    if (controller == null || _mapLoadState != _MapLoadState.ready) return;
    final bounds = cluster.bounds;
    final latitudeSpan = (bounds.northeast.latitude - bounds.southwest.latitude)
        .abs();
    final longitudeDelta =
        bounds.northeast.longitude - bounds.southwest.longitude;
    final longitudeSpan = longitudeDelta >= 0
        ? longitudeDelta
        : longitudeDelta + 360;
    try {
      // Native bounds can collapse to a point when several branches share
      // coordinates. In that case, zoom in by a bounded increment instead of
      // asking the map to fit a zero-area LatLngBounds forever.
      if (latitudeSpan < 0.0001 && longitudeSpan < 0.0001) {
        final zoom = await controller.getZoomLevel();
        if (zoom >= 19) return;
        await controller.animateCamera(
          CameraUpdate.newLatLngZoom(
            cluster.position,
            (zoom + 2).clamp(0, 19).toDouble(),
          ),
        );
        return;
      }
      await controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 72));
    } catch (_) {
      // Keep the current map usable if a native camera update races map teardown.
    }
  }

  Future<void> _fitCameraToLocations() async {
    final controller = _mapController;
    if (controller == null || _mapLoadState != _MapLoadState.ready) return;
    if (!widget.hasActiveFilters) {
      try {
        await controller.animateCamera(
          CameraUpdate.newLatLngZoom(_ulaanbaatar, 11.5),
        );
        await _updateVisibleRegion();
      } catch (_) {
        // The map remains usable at its existing viewport if fitting fails.
      }
      return;
    }
    final positions = _mapPositions(widget.organizations);
    if (positions.isEmpty) return;
    try {
      if (positions.length == 1) {
        await controller.animateCamera(
          CameraUpdate.newLatLngZoom(positions.single, 14),
        );
      } else {
        var south = positions.first.latitude;
        var north = south;
        var west = positions.first.longitude;
        var east = west;
        for (final position in positions.skip(1)) {
          south = math.min(south, position.latitude);
          north = math.max(north, position.latitude);
          west = math.min(west, position.longitude);
          east = math.max(east, position.longitude);
        }
        if (north - south < 0.01) {
          south -= 0.01;
          north += 0.01;
        }
        if (east - west < 0.01) {
          west -= 0.01;
          east += 0.01;
        }
        await controller.animateCamera(
          CameraUpdate.newLatLngBounds(
            LatLngBounds(
              southwest: LatLng(south, west),
              northeast: LatLng(north, east),
            ),
            52,
          ),
        );
      }
      await _updateVisibleRegion();
    } catch (_) {
      // The map remains usable at its existing viewport if fitting fails.
    }
  }

  Future<void> _loadPinIcons() async {
    final brightness = _pinBrightness ?? Brightness.light;
    final pins = await loadMapPinIcons(brightness: brightness);
    // A theme switch mid-load already started the right set.
    if (!mounted || brightness != _pinBrightness) return;
    setState(() => _pins = pins);
  }

  /// Whether the selected branch's loaded hours say it's closed right now.
  bool get _selectedClosed {
    final selected = _selected;
    final detail = widget.organizationDetailController.organization;
    if (selected == null ||
        detail == null ||
        detail.slug != selected.organization.slug) {
      return false;
    }
    for (final branch in detail.branches) {
      if (branch.id == selected.branch.id) {
        return branch.openStatusAt(DateTime.now()) == BranchOpenStatus.closed;
      }
    }
    return false;
  }

  // Everything derived from (organizations, selection, visible bounds, pins)
  // — the branch list, the pin positions, and the whole Marker set — is
  // rebuilt only when one of those inputs changes, not on every build (a
  // parent rebuild, detail-controller tick or load-state change repaints
  // the tree without re-deriving markers).
  MapSnapshot? _snapshot;
  List<Organization>? _snapshotOrganizations;
  ({Organization organization, Branch branch})? _snapshotSelected;
  LatLngBounds? _snapshotBounds;
  MapPinIcons? _snapshotPins;
  bool? _snapshotSelectedClosed;

  MapSnapshot _currentSnapshot() {
    final pins = _pins;
    final cached = _snapshot;
    final selectedClosed = _selectedClosed;
    if (cached != null &&
        identical(_snapshotOrganizations, widget.organizations) &&
        _snapshotSelected == _selected &&
        _snapshotBounds == _visibleBounds &&
        identical(_snapshotPins, pins) &&
        _snapshotSelectedClosed == selectedClosed) {
      return cached;
    }
    final snapshot = buildMapSnapshot(
      organizations: widget.organizations,
      selected: _selected,
      visibleBounds: _visibleBounds,
      pins: pins,
      selectedClosed: selectedClosed,
      onMarkerTap: (organization, branch) {
        setState(
          () => _selected = (organization: organization, branch: branch),
        );
        widget.organizationDetailController.load(organization.slug);
      },
    );
    _snapshot = snapshot;
    _snapshotOrganizations = widget.organizations;
    _snapshotSelected = _selected;
    _snapshotBounds = _visibleBounds;
    _snapshotPins = pins;
    _snapshotSelectedClosed = selectedClosed;
    return snapshot;
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _currentSnapshot();
    final positions = snapshot.positions;
    final visibleSelection = snapshot.visibleSelection;
    final markers = snapshot.markers;
    final mapUnavailable = _mapLoadState == _MapLoadState.unavailable;
    final mapReady = _mapLoadState == _MapLoadState.ready;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final sheetPadding = visibleSelection == null ? 0.0 : _sheetHeight;
    final initialTarget = positions.length == 1
        ? positions.first
        : _ulaanbaatar;
    return SizedBox(
      height: widget.height,
      child: Stack(
        children: [
          if (!mapUnavailable)
            Positioned.fill(
              child: Semantics(
                container: true,
                label: 'Сервисийн байршлын интерактив газрын зураг',
                child: GoogleMap(
                  key: ValueKey('discovery-map-$_mapInstance'),
                  onMapCreated: _onMapCreated,
                  onCameraIdle: _updateVisibleRegion,
                  onTap: (_) => _dismissSelection(),
                  style: Theme.of(context).brightness == Brightness.dark
                      ? _darkMapStyle
                      : _lightMapStyle,
                  initialCameraPosition: CameraPosition(
                    target: initialTarget,
                    zoom: positions.length == 1 ? 14 : 11.5,
                  ),
                  markers: markers,
                  clusterManagers: <ClusterManager>{
                    ClusterManager(
                      clusterManagerId: ClusterManagerId('discovery'),
                      onClusterTap: _handleClusterTap,
                    ),
                  },
                  // Keeps fit-to-results, marker centering and the Google
                  // logo clear of the floating header and the docked sheet.
                  padding: EdgeInsets.only(
                    top:
                        widget.topPadding +
                        (widget.showLocationBanner &&
                                _locationAccessState !=
                                    LocationAccessState.granted
                            ? 68
                            : 0),
                    bottom: sheetPadding,
                  ),
                  gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                    Factory<EagerGestureRecognizer>(EagerGestureRecognizer.new),
                  },
                  mapToolbarEnabled: false,
                  myLocationEnabled:
                      _locationAccessState == LocationAccessState.granted,
                  // Same story as zoomControlsEnabled — pinned bottom-right
                  // by the platform, replaced by a custom button.
                  myLocationButtonEnabled: false,
                  compassEnabled: false,
                  scrollGesturesEnabled: true,
                  // The platform's own zoom control is pinned to the
                  // bottom-right by the SDK — no padding/position knob
                  // moves it, and that corner is where the locate-me
                  // button sits. Pinch, double-tap and cluster taps zoom.
                  zoomControlsEnabled: false,
                  buildingsEnabled: false,
                  rotateGesturesEnabled: false,
                  tiltGesturesEnabled: false,
                  minMaxZoomPreference: const MinMaxZoomPreference(5, 19),
                ),
              ),
            ),
          // Nothing to pin in this viewport (or under these filters): say so
          // without unmounting the map, so the user can pan or zoom out.
          if (mapReady && !snapshot.hasLocations)
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.only(
                  top: widget.topPadding,
                  bottom: sheetPadding + 80,
                ),
                child: const Center(child: NoMapLocations()),
              ),
            ),
          if (widget.showLocationBanner &&
              mapReady &&
              _locationAccessState != null &&
              _locationAccessState != LocationAccessState.granted)
            Positioned(
              top: widget.topPadding + 10,
              left: 10,
              right: 10,
              child: LocationPermissionBanner(
                state: _locationAccessState!,
                onRequest: requestLocationPermission,
                onOpenSettings: openLocationSettings,
              ),
            ),
          if (_mapLoadState == _MapLoadState.loading)
            const Positioned.fill(child: MapLoadingOverlay()),
          if (_mapLoadState == _MapLoadState.failed)
            Positioned.fill(
              child: MapFailureOverlay(
                onRetry: _retryMap,
                onShowList: widget.onShowList,
              ),
            ),
          if (mapUnavailable)
            Positioned.fill(
              child: MapUnavailableOverlay(onShowList: widget.onShowList),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.bottomControlsBuilder case final builder?)
                  builder(
                    context,
                    sheetVisible: visibleSelection != null,
                    mapReady: mapReady,
                  ),
                MeasureSize(
                  onChange: _handleSheetSize,
                  child: AnimatedSwitcher(
                    duration: reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 240),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) => SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.2),
                        end: Offset.zero,
                      ).animate(animation),
                      child: FadeTransition(opacity: animation, child: child),
                    ),
                    layoutBuilder: (current, previous) => Stack(
                      alignment: Alignment.bottomCenter,
                      fit: StackFit.passthrough,
                      children: [...previous, ?current],
                    ),
                    child: visibleSelection == null
                        ? const SizedBox(width: double.infinity)
                        : SelectedBranchSheet(
                            key: ValueKey(
                              '${visibleSelection.organization.slug}:'
                              '${visibleSelection.branch.id}',
                            ),
                            organization: visibleSelection.organization,
                            branch: visibleSelection.branch,
                            detailController:
                                widget.organizationDetailController,
                            onClose: _dismissSelection,
                            onDetails: () => widget.onBranchSelected(
                              visibleSelection.organization,
                              visibleSelection.branch,
                            ),
                            onBook: () =>
                                (widget.onBookRequested ??
                                widget.onBranchSelected)(
                                  visibleSelection.organization,
                                  visibleSelection.branch,
                                ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _MapLoadState { loading, ready, failed, unavailable }
