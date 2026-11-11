import 'package:carservice_customer/app/app_messages.dart';
import 'package:carservice_customer/app/theme/app_theme.dart';
import 'package:carservice_customer/features/discovery/presentation/controllers/discovery_controller.dart';
import 'package:carservice_customer/features/discovery/presentation/widgets/branch_filter_panel.dart';
import 'package:carservice_customer/features/discovery/presentation/widgets/discovery_map_controls.dart';
import 'package:carservice_customer/features/discovery/services/device_location_service.dart';
import 'package:flutter/material.dart';

/// Хайх's search pill — shared by the map (floating over the tiles) and the
/// list (above the cards), so switching views keeps the same header. The
/// round button inside opens the full filter sheet; its dot flags filters
/// that only live in that sheet (the chip row below shows the rest).
class DiscoverySearchBar extends StatelessWidget {
  const DiscoverySearchBar({
    required this.controller,
    required this.searchController,
    required this.onOpenFilters,
    super.key,
  });

  final DiscoveryController controller;
  final TextEditingController searchController;
  final VoidCallback onOpenFilters;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    final sheetOnlyFilters =
        controller.city.isNotEmpty ||
        controller.district.isNotEmpty ||
        controller.nearMe ||
        controller.weekend;
    // The design's floating search field: a white 52px card with a 16px
    // radius, search icon, the field, then a hairline divider before the
    // filter button.
    return Container(
      height: 52,
      padding: const EdgeInsets.only(left: 16, right: 4),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: theme.cardBorder.withValues(alpha: 0.6)),
        boxShadow: floatingControlShadow(context),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 20, color: theme.mutedText),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: searchController,
              onChanged: controller.setQuery,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => FocusScope.of(context).unfocus(),
              style: TextStyle(
                color: theme.ink,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                isDense: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: 'Сервис, дүүрэг хайх',
                hintStyle: TextStyle(color: theme.mutedText, fontSize: 15),
              ),
            ),
          ),
          ValueListenableBuilder(
            valueListenable: searchController,
            builder: (context, value, _) => value.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    key: const ValueKey('discovery-search-clear'),
                    onPressed: () {
                      searchController.clear();
                      controller.setQuery('');
                    },
                    tooltip: 'Арилгах',
                    icon: Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: theme.mutedText,
                    ),
                  ),
          ),
          Container(width: 1, height: 22, color: theme.cardBorder),
          Tooltip(
            message: 'Шүүлтүүрүүд',
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: const ValueKey('discovery-filters-button'),
                onTap: onOpenFilters,
                child: SizedBox.square(
                  dimension: 44,
                  child: Center(
                    child: Badge(
                      isLabelVisible: sheetOnlyFilters,
                      smallSize: 8,
                      backgroundColor: AppColors.accent,
                      child: Icon(
                        Icons.tune_rounded,
                        size: 20,
                        color: theme.ink,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The one-tap filters under the search bar: "Нээлттэй" (open now) and the
/// platform's business-type tags, plus the Booking tab's hand-off service
/// key while one is active. Scrolls sideways edge to edge; everything else
/// (city/district, near me, weekend) lives in the filter sheet.
class DiscoveryQuickFilters extends StatelessWidget {
  const DiscoveryQuickFilters({
    required this.controller,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    super.key,
  });

  final DiscoveryController controller;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final chips = [
      if (controller.serviceKey.isNotEmpty)
        QuickFilterChip(
          key: const ValueKey('discovery-service-key-chip'),
          label: controller.serviceKeyName.isEmpty
              ? 'Сонгосон ажил'
              : controller.serviceKeyName,
          selected: true,
          trailingIcon: Icons.close_rounded,
          semanticsHint: 'Хасах',
          onTap: () => controller.setServiceKey(''),
        ),
      QuickFilterChip(
        key: const ValueKey('discovery-chip-open-now'),
        label: 'Нээлттэй',
        selected: controller.openNow,
        pending: controller.openNowPending,
        onTap: () => controller.setOpenNow(!controller.openNow),
      ),
      for (final option in controller.tagOptions)
        QuickFilterChip(
          key: ValueKey('discovery-chip-tag-${option.id}'),
          label: option.name,
          selected: controller.tag == option.id,
          // Single-select, like the sheet's dropdown: tapping the active tag
          // clears it, tapping another switches to it.
          onTap: () => controller.tag == option.id
              ? controller.setTag('')
              : controller.setTag(option.id, name: option.name),
        ),
    ];
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (_, index) => chips[index],
      ),
    );
  }
}

/// A pill-shaped toggle in [DiscoveryQuickFilters]: the design's navy
/// (inverse) fill when on, a bordered card pill when off.
class QuickFilterChip extends StatelessWidget {
  const QuickFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.pending = false,
    this.trailingIcon,
    this.semanticsHint,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool pending;
  final IconData? trailingIcon;
  final String? semanticsHint;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    final foreground = selected ? theme.onInverse : theme.ink;
    return Semantics(
      button: true,
      selected: selected,
      hint: semanticsHint,
      child: Material(
        color: selected ? theme.inverse : theme.card,
        shape: StadiumBorder(
          side: BorderSide(color: selected ? theme.inverse : theme.cardBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (pending) ...[
                  SizedBox.square(
                    dimension: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: foreground,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (trailingIcon != null) ...[
                  const SizedBox(width: 4),
                  Icon(trailingIcon, size: 16, color: foreground),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The filter controls (city/district, business-type tag, server chips)
/// in the filter sheet both Хайх views open — kept as one widget so a
/// filter added for one view is never forgotten in the other.
class DiscoveryFiltersPanel extends StatelessWidget {
  const DiscoveryFiltersPanel({required this.controller, super.key});

  final DiscoveryController controller;

  Future<void> _toggleNearMe(BuildContext context, bool selected) async {
    // Optimistic: chip тэр даруй сонгогдоно; байршил авч чадаагүй бол буцна.
    final ok = await controller.setNearMe(
      selected,
      locate: selected
          ? () async {
              final location = await const GeolocatorDeviceLocationService()
                  .current();
              return location == null
                  ? null
                  : (lat: location.lat, lng: location.lng);
            }
          : null,
    );
    if (!ok && context.mounted) {
      AppMessages.show(
        'Байршлыг авч чадсангүй. Байршлын зөвшөөрөл, тохиргоогоо шалгана уу.',
      );
    }
  }

  // controller.cities/districts одоо сүүлийн ШҮҮЛТГҮЙ каталогоос тооцогддог
  // тул идэвхтэй сервер шүүлт 0 илэрцтэй болсон ч хоосрохгүй. Chip мөрийг
  // `hasCatalog`-оор харуулдаг нь шүүлтийг унтраах үед reload дуустал мөр
  // алга болохоос сэргийлнэ (дэлгэрэнгүйг DiscoveryController.hasCatalog).
  @override
  Widget build(BuildContext context) => BranchFilterPanel(
    city: controller.city,
    district: controller.district,
    cities: controller.cities,
    districts: controller.districts,
    onCityChanged: controller.setCity,
    onDistrictChanged: controller.setDistrict,
    tag: controller.tag,
    tagOptions: controller.tagOptions,
    onTagChanged: (id, name) => controller.setTag(id, name: name),
    nearMe: controller.nearMe,
    openNow: controller.openNow,
    weekend: controller.weekend,
    nearMePending: controller.nearMePending,
    openNowPending: controller.openNowPending,
    weekendPending: controller.weekendPending,
    onNearMeChanged: (selected) => _toggleNearMe(context, selected),
    onOpenNowChanged: controller.setOpenNow,
    onWeekendChanged: controller.setWeekend,
    showChips: controller.hasCatalog || controller.hasActiveFilters,
  );
}
