import 'package:carservice_customer/app/theme/app_surfaces.dart';
import 'package:carservice_customer/app/theme/app_theme.dart';
import 'package:carservice_customer/core/widgets/animations.dart';
import 'package:carservice_customer/core/widgets/measure_size.dart';
import 'package:carservice_customer/core/widgets/offline_banner.dart';
import 'package:carservice_customer/core/widgets/skeletons.dart';
import 'package:carservice_customer/features/discovery/domain/branch.dart';
import 'package:carservice_customer/features/discovery/domain/organization.dart';
import 'package:carservice_customer/features/discovery/domain/organization_repository.dart';
import 'package:carservice_customer/features/discovery/presentation/controllers/discovery_controller.dart';
import 'package:carservice_customer/features/discovery/presentation/controllers/discovery_state.dart';
import 'package:carservice_customer/features/discovery/presentation/controllers/organization_detail_controller.dart';
import 'package:carservice_customer/features/discovery/presentation/widgets/branch_card.dart';
import 'package:carservice_customer/features/discovery/presentation/widgets/discovery_header.dart';
import 'package:carservice_customer/features/discovery/presentation/widgets/discovery_list_parts.dart';
import 'package:carservice_customer/features/discovery/presentation/widgets/discovery_map_controls.dart';
import 'package:carservice_customer/features/discovery/presentation/widgets/discovery_map.dart';
import 'package:carservice_customer/features/discovery/presentation/widgets/location_permission_banner.dart';
import 'package:carservice_customer/features/discovery/services/location_permission_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({
    required this.onBranchSelected,
    required this.onNotificationsRequested,
    this.onBookRequested,
    super.key,
  });
  final void Function(Organization organization, Branch branch)
  onBranchSelected;
  final VoidCallback onNotificationsRequested;

  /// The map sheet's "Цаг захиалах" — straight into booking at that branch.
  /// Without it the sheet opens the detail page instead.
  final void Function(Organization organization, Branch branch)?
  onBookRequested;

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final _mapKey = GlobalKey<DiscoveryMapState>();
  // Mirrors the map's location access so its banner can sit under the
  // floating search bar instead of behind it.
  LocationAccessState? _mapLocationAccess;
  MapViewport? _lastMapViewport;
  // How much of the map the floating header covers, status bar included —
  // handed to the map as top padding.
  double _mapHeaderHeight = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<DiscoveryController>().loadTagOptions(),
    );
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter < 500) {
      context.read<DiscoveryController>().loadMore();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DiscoveryController>();
    // Map mode wants the whole screen, status bar included (the shell hides
    // its AppBar for this same reason) — SafeArea is applied per-overlay
    // inside _buildMapBody instead of around the whole body.
    return AppShellBackground(
      child: controller.mapView
          ? _buildMapBody(controller)
          : SafeArea(child: _buildListBody(controller)),
    );
  }

  /// List mode keeps the map's header — the same search pill and quick
  /// filters, fixed above the scrolling cards — with the high-contrast
  /// toggle pill floating back to the map.
  Widget _buildListBody(DiscoveryController controller) => Stack(
    children: [
      Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: DiscoverySearchBar(
              controller: controller,
              searchController: _searchController,
              onOpenFilters: () => _openFiltersSheet(controller),
            ),
          ),
          const SizedBox(height: 10),
          DiscoveryQuickFilters(controller: controller),
          const SizedBox(height: 6),
          Expanded(
            child: RefreshIndicator(
              onRefresh: controller.load,
              child: CustomScrollView(
                controller: _scrollController,
                key: const PageStorageKey('discovery-scroll'),
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: _content(controller),
              ),
            ),
          ),
        ],
      ),
      Positioned(
        left: 0,
        right: 0,
        bottom: 16,
        child: Center(
          child: MapViewToggleButton(
            key: const ValueKey('discovery-toggle-view'),
            icon: Icons.map_outlined,
            label: 'Газрын зураг',
            onPressed: () => controller.setMapView(true),
          ),
        ),
      ),
    ],
  );

  // The map's organizations are re-derived only when the source list
  // instance (or which source is in use) changes — not on every controller
  // notification — so the map keeps receiving the same list and skips its
  // own marker work.
  List<Organization>? _mapOrganizations;
  Object? _mapOrganizationsSource;
  bool? _mapOrganizationsLoaded;

  List<Organization> _mapOrganizationsFor(DiscoveryController controller) {
    final loaded = controller.mapLoaded;
    final Object source = loaded
        ? controller.mapMarkers
        : controller.mapFallbackOrganizations;
    if (_mapOrganizations != null &&
        _mapOrganizationsLoaded == loaded &&
        identical(_mapOrganizationsSource, source)) {
      return _mapOrganizations!;
    }
    _mapOrganizationsLoaded = loaded;
    _mapOrganizationsSource = source;
    return _mapOrganizations = loaded
        ? controller.mapMarkers
              .map((marker) => marker.toOrganization())
              .toList()
        : controller.mapFallbackOrganizations;
  }

  /// Map-first Хайх: the map fills the whole screen (the shell hides its
  /// AppBar for this tab in this mode — see CustomerShell), with the search
  /// pill, notifications bell and quick-filter chips floating along the top
  /// and the list toggle and locate-me along the bottom — lifted above the
  /// branch sheet while a pin is selected.
  Widget _buildMapBody(DiscoveryController controller) {
    final detailController = context.read<OrganizationDetailController>();
    final mapOrganizations = _mapOrganizationsFor(controller);
    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        children: [
          Positioned.fill(
            child: DiscoveryMap(
              key: _mapKey,
              organizations: mapOrganizations,
              hasActiveFilters: controller.hasActiveFilters,
              height: constraints.maxHeight,
              topPadding: _mapHeaderHeight,
              showLocationBanner: false,
              onLocationAccessChanged: (state) {
                if (state != _mapLocationAccess) {
                  setState(() => _mapLocationAccess = state);
                }
              },
              organizationDetailController: detailController,
              refitSignal: controller.mapRefitSignal,
              onViewportChanged: (bounds) {
                final viewport = MapViewport(
                  north: bounds.northeast.latitude,
                  south: bounds.southwest.latitude,
                  east: bounds.northeast.longitude,
                  west: bounds.southwest.longitude,
                );
                _lastMapViewport = viewport;
                controller.requestMapMarkers(viewport);
              },
              onBranchSelected: widget.onBranchSelected,
              onBookRequested: widget.onBookRequested,
              onShowList: () => controller.setMapView(false),
              bottomControlsBuilder: _buildMapBottomControls,
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: MeasureSize(
              onChange: (size) {
                if ((size.height - _mapHeaderHeight).abs() >= 1) {
                  setState(() => _mapHeaderHeight = size.height);
                }
              },
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 8),
                  child: _buildMapHeader(controller),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapHeader(DiscoveryController controller) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: DiscoverySearchBar(
                controller: controller,
                searchController: _searchController,
                onOpenFilters: () => _openFiltersSheet(controller),
              ),
            ),
            MapNotificationsButton(onPressed: widget.onNotificationsRequested),
          ],
        ),
      ),
      const SizedBox(height: 10),
      DiscoveryQuickFilters(controller: controller),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_mapLocationAccess != null &&
                _mapLocationAccess != LocationAccessState.granted)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: LocationPermissionBanner(
                  state: _mapLocationAccess!,
                  onRequest: () =>
                      _mapKey.currentState?.requestLocationPermission(),
                  onOpenSettings: () =>
                      _mapKey.currentState?.openLocationSettings(),
                ),
              ),
            // A search/filter change re-fetches markers for the current
            // viewport in the background (see
            // DiscoveryController._invalidateMapForFilterChange) without
            // hiding the map — this is the only sign that fetch is
            // happening, so dropping it (as the map-default rewrite
            // originally did) made a working refresh look like a stall.
            if (controller.mapLoading && controller.mapError == null)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: MapRefreshSpinner(),
                ),
              ),
            if (controller.mapError != null &&
                (!controller.mapLoaded || controller.mapMarkers.isEmpty))
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
                  decoration: BoxDecoration(
                    color: CarserviceTheme.of(context).card,
                    border: Border.all(
                      color: CarserviceTheme.of(context).cardBorder,
                    ),
                    borderRadius: BorderRadius.circular(AppRadii.card),
                    boxShadow: floatingControlShadow(context),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          controller.mapError!,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      if (_lastMapViewport != null)
                        TextButton(
                          onPressed: () => controller.requestMapMarkers(
                            _lastMapViewport!,
                            force: true,
                          ),
                          child: const Text('Дахин оролдох'),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    ],
  );

  /// The map's bottom row: the list toggle centred (hidden behind a selected
  /// branch's sheet, which takes over the bottom of the screen) and
  /// locate-me on the right (only once the map can act on it). Google's
  /// logo keeps the left corner.
  Widget _buildMapBottomControls(
    BuildContext context, {
    required bool sheetVisible,
    required bool mapReady,
  }) {
    final controller = context.read<DiscoveryController>();
    final bottomInset = sheetVisible
        ? 0.0
        : MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (controller.mapTruncated && !sheetVisible)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: CarserviceTheme.of(context).card,
                  border: Border.all(
                    color: CarserviceTheme.of(context).cardBorder,
                  ),
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  boxShadow: floatingControlShadow(context),
                ),
                child: const Text(
                  'Зарим цэгийг нуусан. Газрын зургийг томруулна уу.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          SizedBox(
            height: 48,
            child: Stack(
              children: [
                if (!sheetVisible)
                  Align(
                    child: MapViewToggleButton(
                      key: const ValueKey('discovery-map-list-toggle'),
                      icon: Icons.format_list_bulleted_rounded,
                      label: 'Жагсаалт',
                      onPressed: () => controller.setMapView(false),
                    ),
                  ),
                if (mapReady)
                  Align(
                    alignment: Alignment.centerRight,
                    child: MapRoundButton(
                      key: const ValueKey('discovery-map-locate-me'),
                      icon: Icons.my_location_rounded,
                      tooltip: 'Миний байршил',
                      iconColor: CarserviceTheme.of(context).link,
                      onPressed: () => _mapKey.currentState?.locateMe(),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openFiltersSheet(DiscoveryController controller) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 12,
            bottom: 20 + MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: CarserviceTheme.of(context).mutedText
                          .withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                  ),
                ),
                ListenableBuilder(
                  listenable: controller,
                  builder: (context, _) => Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Шүүлтүүрүүд',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                        ),
                      ),
                      if (controller.hasActiveFilters)
                        TextButton(
                          onPressed: () {
                            _searchController.clear();
                            controller.clearFilters();
                          },
                          child: const Text('Бүгдийг арилгах'),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ListenableBuilder(
                  listenable: controller,
                  builder: (context, _) =>
                      DiscoveryFiltersPanel(controller: controller),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _content(DiscoveryController controller) {
    final state = controller.state;
    final organizations = controller.visibleOrganizations;
    final banner = state.isFromCache
        ? [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
              sliver: SliverToBoxAdapter(
                child: OfflineBanner(
                  message: 'Сүлжээгүй байна — сүүлд ачаалсан жагсаалтыг харуулж байна',
                  semanticsLabel: 'Сүлжээгүй байна. Сүүлд ачаалсан авто сервисийн жагсаалтыг харуулж байна.',
                  retryKey: const ValueKey('discovery-offline-retry'),
                  onRetry: controller.load,
                ),
              ),
            ),
          ]
        : const <Widget>[];
    return [...banner, ..._statusContent(state, organizations, controller)];
  }

  List<Widget> _statusContent(
    DiscoveryState state,
    List<Organization> organizations,
    DiscoveryController controller,
  ) {
    // Жагсаалт одоо байгууллагын биш салбарын түвшинд харагддаг тул
    // байгууллага бүрийг өөрийн салбаруудаар нь тэгшлэв — эзэн байгууллагын
    // нэрийг картын гарчиг болгон ашиглахын тулд хосолсон хэвээр үлдээв.
    final branchEntries = [
      for (final organization in organizations)
        for (final branch in organization.branches)
          (organization: organization, branch: branch),
    ];
    // Шүүлт солиход (reload) өмнөх жагсаалт хэвээр байвал skeleton руу
    // "гялсхийхгүй" — өмнөх өгөгдлийг үзүүлсээр байна (зөвхөн анхны ачаалалд
    // skeleton). Ингэснээр filter section болон жагсаалт тогтвортой харагдана.
    final effectiveStatus =
        state.status == DiscoveryStatus.loading &&
            state.organizations.isNotEmpty
        ? DiscoveryStatus.data
        : state.status;
    return switch (effectiveStatus) {
      DiscoveryStatus.initial || DiscoveryStatus.loading => const [
        SliverFillRemaining(
          hasScrollBody: true,
          child: SkeletonAvatarCardList(),
        ),
      ],
      DiscoveryStatus.empty => const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: DiscoveryMessageState(
            icon: Icons.storefront_outlined,
            title: 'Авто сервис олдсонгүй',
            message: 'Одоогоор цаг захиалга авч буй байгууллага алга байна.',
          ),
        ),
      ],
      DiscoveryStatus.error => [
        SliverFillRemaining(
          hasScrollBody: false,
          child: DiscoveryMessageState(
            icon: Icons.cloud_off_outlined,
            title: 'Мэдээлэл ачаалсангүй',
            message: state.message ?? 'Дахин оролдоно уу.',
            actionLabel: 'Дахин оролдох',
            onAction: controller.load,
          ),
        ),
      ],
      DiscoveryStatus.data when branchEntries.isEmpty => [
        SliverFillRemaining(
          hasScrollBody: false,
          child: DiscoveryMessageState(
            icon: Icons.search_off_rounded,
            title: 'Илэрц олдсонгүй',
            message: 'Хайлт эсвэл байршлын шүүлтүүрээ өөрчилж үзээрэй.',
            actionLabel: 'Шүүлтүүр цэвэрлэх',
            onAction: () {
              _searchController.clear();
              controller.clearFilters();
            },
          ),
        ),
      ],
      DiscoveryStatus.data => [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          sliver: SliverList.separated(
            itemCount: branchEntries.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final entry = branchEntries[index];
              return RiseIn(
                index: index,
                child: BranchCard(
                  organization: entry.organization,
                  branch: entry.branch,
                  onTap: () =>
                      widget.onBranchSelected(entry.organization, entry.branch),
                ),
              );
            },
          ),
        ),
        if (state.isLoadingMore ||
            state.loadMoreMessage != null ||
            state.pagination.hasNext)
          SliverToBoxAdapter(
            child: LoadMoreFooter(state: state, onRetry: controller.loadMore),
          ),
        // Room to scroll the last card out from under the map toggle pill.
        const SliverToBoxAdapter(child: SizedBox(height: 84)),
      ],
    };
  }
}
