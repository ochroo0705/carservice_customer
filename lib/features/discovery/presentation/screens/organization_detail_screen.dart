import 'package:carservice_customer/app/app_messages.dart';
import 'package:carservice_customer/app/theme/app_surfaces.dart';
import 'package:carservice_customer/app/theme/app_theme.dart';
import 'package:carservice_customer/core/widgets/skeletons.dart';
import 'package:carservice_customer/core/widgets/state_views.dart';
import 'package:carservice_customer/features/booking/domain/next_available_slot.dart';
import 'package:carservice_customer/features/discovery/domain/branch.dart';
import 'package:carservice_customer/features/discovery/domain/organization.dart';
import 'package:carservice_customer/features/discovery/presentation/branch_actions.dart';
import 'package:carservice_customer/features/discovery/presentation/controllers/organization_detail_controller.dart';
import 'package:carservice_customer/features/discovery/presentation/widgets/branch_location_map.dart';
import 'package:carservice_customer/features/discovery/presentation/widgets/branch_open_status_line.dart';
import 'package:carservice_customer/features/discovery/presentation/widgets/organization_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// The public web origin a shared branch link points at — its
/// `/org/[slug]/branch/[branchId]` page needs no sign-in.
const _webOrigin = 'https://carservice.mn';

/// Services listed before "Бүгд" (all) reveals the rest.
const _collapsedServiceCount = 4;

class OrganizationDetailScreen extends StatelessWidget {
  const OrganizationDetailScreen({
    required this.organization,
    this.distanceLocation,
    this.branchId,
    required this.status,
    required this.errorMessage,
    required this.onRetry,
    required this.onBack,
    required this.onBook,
    this.nextAvailableSlot,
    super.key,
  });

  final OrganizationDetail? organization;
  final ({double lat, double lng})? distanceLocation;
  final String? branchId;
  final OrganizationDetailStatus status;
  final String? errorMessage;
  final VoidCallback onRetry;
  final VoidCallback onBack;
  final VoidCallback onBook;

  /// Looks up the branch's earliest free slot for the booking bar. Without
  /// it, or when it fails, the bar shows the branch's open status instead.
  final Future<NextAvailableSlot?> Function(String branchId)? nextAvailableSlot;

  BranchDetail? _branchOf(OrganizationDetail organization) {
    if (organization.branches.isEmpty) return null;
    final id = branchId;
    if (id == null) return organization.branches.first;
    for (final branch in organization.branches) {
      if (branch.id == id) return branch;
    }
    return organization.branches.first;
  }

  /// Loading, error and empty states keep a plain AppBar; only a loaded
  /// branch gets the full-bleed map header.
  Widget _plainPage(Widget body) => Scaffold(
    appBar: AppBar(
      leading: BackButton(onPressed: onBack),
      title: const Text('Сервисийн мэдээлэл'),
    ),
    body: AppShellBackground(child: SafeArea(top: false, child: body)),
  );

  @override
  Widget build(BuildContext context) {
    final organization = this.organization;
    if (status == OrganizationDetailStatus.loading ||
        status == OrganizationDetailStatus.initial) {
      return _plainPage(const SkeletonDetail());
    }
    if (status == OrganizationDetailStatus.error) {
      return _plainPage(
        OrganizationLoadError(
          message: errorMessage ?? 'Мэдээлэл ачаалсангүй.',
          onRetry: onRetry,
        ),
      );
    }
    if (organization == null) return _plainPage(_NotFound(onBack: onBack));
    final branch = _branchOf(organization);
    if (branch == null) {
      return _plainPage(
        const Padding(padding: EdgeInsets.all(20), child: _NoBranches()),
      );
    }
    return _BranchDetailView(
      organization: organization,
      branch: branch,
      distanceLocation: distanceLocation,
      onBack: onBack,
      onBook: onBook,
      nextAvailableSlot: nextAvailableSlot,
    );
  }
}

/// Нэг салбарын танилцах хуудас — байгууллагын танилцуулга (лого, утас)
/// дээр дарж орсон яг тэр салбарынхаа хаяг/цаг/үйлчилгээг харуулна. Цаг
/// захиалах эндээс шууд эхэлдэг (`onBook`) — өмнө нь энэ боломж Booking таб
/// руу зөвхөн шилжсэн байсан нь backend-ийн global service-key системийг
/// хүлээж байсан учиртай; тэр саад одоо арилсан тул (D-093-ийг үзнэ үү,
/// `../../../../COWORK.md`) энд буцаан холбов.
class _BranchDetailView extends StatelessWidget {
  const _BranchDetailView({
    required this.organization,
    required this.branch,
    required this.distanceLocation,
    required this.onBack,
    required this.onBook,
    required this.nextAvailableSlot,
  });

  final OrganizationDetail organization;
  final BranchDetail branch;
  final ({double lat, double lng})? distanceLocation;
  final VoidCallback onBack;
  final VoidCallback onBook;
  final Future<NextAvailableSlot?> Function(String branchId)? nextAvailableSlot;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final topInset = MediaQuery.paddingOf(context).top;
    final located = branch.latitude != null && branch.longitude != null;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: AppShellBackground(
          child: Stack(
            children: [
              CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: BranchLocationMap(
                      latitude: branch.latitude,
                      longitude: branch.longitude,
                      closed:
                          branch.openStatusAt(DateTime.now()) ==
                          BranchOpenStatus.closed,
                      height: topInset + (located ? 156 : 60),
                    ),
                  ),
                  SliverPadding(
                    // No overlap into the map: an earlier sliver paints over
                    // a later one, and nothing should cover the native map.
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _IdentityRow(
                            organization: organization,
                            branch: branch,
                            distanceLocation: distanceLocation,
                          ),
                          const SizedBox(height: 20),
                          _ActionTiles(
                            organization: organization,
                            branch: branch,
                          ),
                          const SizedBox(height: 20),
                          _InfoGroup(
                            organization: organization,
                            branch: branch,
                          ),
                          if (branch.categories.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            _ServicesSection(categories: branch.categories),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              // Dims whatever scrolls up under the status bar.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: topInset + 12,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          theme.shellBackground.withValues(alpha: 0.85),
                          theme.shellBackground.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: topInset + 8,
                left: 16,
                child: _FloatingBackButton(onPressed: onBack),
              ),
            ],
          ),
        ),
        bottomNavigationBar: _BookingBar(
          branch: branch,
          nextAvailableSlot: nextAvailableSlot,
          onBook: onBook,
        ),
      ),
    );
  }
}

class _FloatingBackButton extends StatelessWidget {
  const _FloatingBackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.shellSurface.withValues(alpha: 0.92),
        shape: BoxShape.circle,
        border: Border.all(color: theme.glassBorder),
      ),
      child: SizedBox.square(
        dimension: 44,
        child: BackButton(
          onPressed: onPressed,
          style: IconButton.styleFrom(
            minimumSize: const Size.square(44),
            padding: EdgeInsets.zero,
            foregroundColor: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

/// Logo, name, "branch · distance" and the live open-status line.
class _IdentityRow extends StatelessWidget {
  const _IdentityRow({
    required this.organization,
    required this.branch,
    required this.distanceLocation,
  });

  final OrganizationDetail organization;
  final BranchDetail branch;
  final ({double lat, double lng})? distanceLocation;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    final location = distanceLocation;
    final distance = location == null
        ? null
        : branch.distanceKmFrom(
            userLatitude: location.lat,
            userLongitude: location.lng,
          );
    final subtitle = [
      branch.name,
      if (distance != null) '${distance.toStringAsFixed(1)} км',
    ].where((part) => part.trim().isNotEmpty).join(' · ');
    return Row(
      children: [
        Container(
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.large),
            border: Border.all(color: theme.glassBorder),
          ),
          child: OrganizationLogoTile(
            name: organization.name,
            logoUrl: organization.logoUrl,
            size: 64,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                organization.name,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  height: 1.2,
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 13, color: theme.mutedText),
                ),
              ],
              const SizedBox(height: 4),
              BranchOpenStatusLine(branch: branch),
            ],
          ),
        ),
      ],
    );
  }
}

/// Call / directions / share — equal tiles, each only when it can work.
class _ActionTiles extends StatelessWidget {
  const _ActionTiles({required this.organization, required this.branch});

  final OrganizationDetail organization;
  final BranchDetail branch;

  Future<void> _share(Rect? origin) async {
    final link =
        '$_webOrigin/org/${Uri.encodeComponent(organization.slug)}'
        '/branch/${Uri.encodeComponent(branch.id)}';
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: '${organization.name} · ${branch.name}\n$link',
          subject: organization.name,
          // iPad presents the share sheet as a popover anchored here.
          sharePositionOrigin: origin,
        ),
      );
    } catch (_) {
      AppMessages.show('Хуваалцах боломжгүй байна');
    }
  }

  @override
  Widget build(BuildContext context) {
    final phone = organization.phone?.trim();
    final latitude = branch.latitude;
    final longitude = branch.longitude;
    final tiles = [
      if (phone != null && phone.isNotEmpty)
        _ActionTile(
          key: const ValueKey('detail-action-call'),
          icon: Icons.call_outlined,
          label: 'Залгах',
          onPressed: (_) => callBranchPhone(phone),
        ),
      if (latitude != null && longitude != null)
        _ActionTile(
          key: const ValueKey('detail-action-directions'),
          icon: Icons.near_me_outlined,
          label: 'Чиглэл',
          onPressed: (_) =>
              openBranchDirections(latitude: latitude, longitude: longitude),
        ),
      _ActionTile(
        key: const ValueKey('detail-action-share'),
        icon: Icons.share_outlined,
        label: 'Хуваалцах',
        onPressed: _share,
      ),
    ];
    return Row(
      children: [
        for (final (index, tile) in tiles.indexed) ...[
          if (index > 0) const SizedBox(width: 10),
          Expanded(child: tile),
        ],
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String label;

  /// Called with the tile's on-screen rect (the share sheet's iPad anchor).
  final ValueChanged<Rect?> onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: theme.glass,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.large),
        side: BorderSide(color: theme.glassBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          final box = context.findRenderObject() as RenderBox?;
          onPressed(
            box == null || !box.hasSize
                ? null
                : box.localToGlobal(Offset.zero) & box.size,
          );
        },
        child: SizedBox(
          height: 68,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: scheme.primary),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Address, hours and phone as one grouped card, rows split by hairlines.
class _InfoGroup extends StatelessWidget {
  const _InfoGroup({required this.organization, required this.branch});

  final OrganizationDetail organization;
  final BranchDetail branch;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    final scheme = Theme.of(context).colorScheme;
    final street = [
      branch.district,
      branch.fullAddress,
    ].where((part) => part.trim().isNotEmpty).join(', ');
    final city = branch.city.trim();
    final fullAddress = [
      city,
      street,
    ].where((part) => part.isNotEmpty).join(', ');
    final phone = organization.phone?.trim();
    final rows = <Widget>[
      if (fullAddress.isNotEmpty)
        _InfoRow(
          icon: Icons.place_outlined,
          title: street.isEmpty ? city : street,
          subtitle: street.isEmpty || city.isEmpty ? null : city,
          trailing: IconButton(
            key: const ValueKey('detail-copy-address'),
            tooltip: 'Хаяг хуулах',
            icon: Icon(Icons.copy_rounded, size: 18, color: theme.mutedText),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: fullAddress));
              AppMessages.show('Хаяг хууллаа');
            },
          ),
        ),
      _HoursRow(branch: branch),
      if (phone != null && phone.isNotEmpty)
        _InfoRow(
          key: const ValueKey('detail-phone-row'),
          icon: Icons.call_outlined,
          title: phone,
          titleColor: scheme.primary,
          semanticsHint: 'Залгах. Удаан дарж хуулна.',
          trailing: Icon(Icons.chevron_right_rounded, color: theme.mutedText),
          onTap: () => callBranchPhone(phone),
          onLongPress: () async {
            await Clipboard.setData(ClipboardData(text: phone));
            AppMessages.show('Утасны дугаар хууллаа');
          },
        ),
    ];
    return _GroupCard(children: rows);
  }
}

/// A rounded card of rows with hairline dividers between them.
class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    return Material(
      color: theme.glass,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: theme.glassBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final (index, child) in children.indexed) ...[
            if (index > 0) Divider(height: 1, color: theme.glassBorder),
            child,
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.titleColor,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.semanticsHint,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? titleColor;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String? semanticsHint;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    return Semantics(
      hint: semanticsHint,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 60),
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 10, trailing == null ? 16 : 6, 10),
            child: Row(
              children: [
                Icon(icon, size: 20, color: theme.mutedText),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: titleColor,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.mutedText,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null)
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: Center(child: trailing),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Today's hours; when the branch publishes a weekly schedule or upcoming
/// special days, tapping expands them in place.
class _HoursRow extends StatefulWidget {
  const _HoursRow({required this.branch});

  final BranchDetail branch;

  @override
  State<_HoursRow> createState() => _HoursRowState();
}

class _HoursRowState extends State<_HoursRow> {
  bool _expanded = false;

  /// "Өнөөдөр 09:00–18:00", "Өнөөдөр амарна", with the reason appended when
  /// it isn't the ordinary weekday rule ("… · Наадам").
  String get _todayText {
    final branch = widget.branch;
    final now = DateTime.now();
    final today = branch.effectiveScheduleDetailAt(now);
    final base = switch (branch.openStatusAt(now)) {
      BranchOpenStatus.unknown => 'Цагийн мэдээлэл тодорхойгүй',
      _ when !today.rule.isOpen => 'Өнөөдөр амарна',
      _ => 'Өнөөдөр ${branch.hoursLabel}',
    };
    return today.label == null ? base : '$base · ${today.label}';
  }

  @override
  Widget build(BuildContext context) {
    final branch = widget.branch;
    final theme = CarserviceTheme.of(context);
    final hasSchedule = branch.schedules.isNotEmpty;
    final hasNotices = _UpcomingScheduleNotices.hasAny(branch);
    final expandable = hasSchedule || hasNotices;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _InfoRow(
          key: const ValueKey('detail-hours-row'),
          icon: Icons.schedule_rounded,
          title: _todayText,
          subtitle: expandable ? '7 хоногийн хуваарь' : null,
          trailing: expandable
              ? AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: theme.mutedText,
                  ),
                )
              : null,
          onTap: expandable
              ? () => setState(() => _expanded = !_expanded)
              : null,
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: !_expanded
              ? const SizedBox(width: double.infinity)
              : Padding(
                  // Lines the table up with the row's text, past its icon.
                  padding: const EdgeInsets.fromLTRB(48, 0, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (hasSchedule) _WeeklyHoursTable(branch: branch),
                      if (hasNotices) ...[
                        if (hasSchedule) const SizedBox(height: 12),
                        _UpcomingScheduleNotices(branch: branch),
                      ],
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

/// Ангиллын жагсаалт (booking v2) — нэг салбарын санал болгож буй
/// үйлчилгээ, тус бүрийн хугацаатай. Эхний хэдийг харуулж, үлдсэнийг
/// "Бүгд"-ээр дэлгэнэ.
class _ServicesSection extends StatefulWidget {
  const _ServicesSection({required this.categories});

  final List<BranchServiceCategory> categories;

  @override
  State<_ServicesSection> createState() => _ServicesSectionState();
}

class _ServicesSectionState extends State<_ServicesSection> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    final scheme = Theme.of(context).colorScheme;
    final categories = widget.categories;
    final overflow = categories.length > _collapsedServiceCount;
    final visible = _showAll || !overflow
        ? categories
        : categories.take(_collapsedServiceCount);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Үйлчилгээ',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
            if (overflow)
              TextButton(
                key: const ValueKey('detail-services-all'),
                onPressed: () => setState(() => _showAll = !_showAll),
                child: Text(
                  _showAll ? 'Хураах' : 'Бүгд (${categories.length})',
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        _GroupCard(
          children: [
            for (final category in visible)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(AppRadii.medium),
                      ),
                      child: Icon(
                        Icons.build_outlined,
                        size: 20,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            category.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '~ ${category.durationMinutes} мин',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.mutedText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// The sticky bottom bar: the earliest free slot (or, failing that, the
/// open status) beside the booking button.
class _BookingBar extends StatefulWidget {
  const _BookingBar({
    required this.branch,
    required this.nextAvailableSlot,
    required this.onBook,
  });

  final BranchDetail branch;
  final Future<NextAvailableSlot?> Function(String branchId)? nextAvailableSlot;
  final VoidCallback onBook;

  @override
  State<_BookingBar> createState() => _BookingBarState();
}

class _BookingBarState extends State<_BookingBar> {
  Future<NextAvailableSlot?>? _slot;

  @override
  void initState() {
    super.initState();
    _slot = widget.nextAvailableSlot?.call(widget.branch.id);
  }

  @override
  void didUpdateWidget(covariant _BookingBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.branch.id != widget.branch.id) {
      _slot = widget.nextAvailableSlot?.call(widget.branch.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        14 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: theme.shellSurface,
        border: Border(top: BorderSide(color: theme.glassBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: FutureBuilder<NextAvailableSlot?>(
              future: _slot,
              builder: (context, snapshot) {
                final failed = _slot == null || snapshot.hasError;
                if (failed) return BranchOpenStatusLine(branch: widget.branch);
                final value = switch (snapshot.connectionState) {
                  ConnectionState.done =>
                    snapshot.data?.label ?? '3 хоногт сул цаг алга',
                  _ => '…',
                };
                return Semantics(
                  liveRegion: true,
                  child: Column(
                    key: const ValueKey('detail-next-slot'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Ойрын сул цаг',
                        style: TextStyle(fontSize: 12, color: theme.mutedText),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 14),
          FilledButton.icon(
            key: const ValueKey('detail-book-button'),
            onPressed: widget.onBook,
            icon: const Icon(Icons.event_available_outlined, size: 20),
            label: const Text('Цаг захиалах'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 52),
              padding: const EdgeInsets.symmetric(horizontal: 22),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.large),
              ),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _weekdayOrder = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
const _weekdayLabels = {
  'MON': 'Даваа',
  'TUE': 'Мягмар',
  'WED': 'Лхагва',
  'THU': 'Пүрэв',
  'FRI': 'Баасан',
  'SAT': 'Бямба',
  'SUN': 'Ням',
};

/// Долоо хоногийн бүтэн цагийн хуваарь — `branch.hoursLabel` зөвхөн өнөөдрийн
/// нэг мөрийг харуулдаг тул үүнийг долоо хоног бүрээр дэлгэв. Idэвхтэй
/// улирлын хуваарь болон тухайн өдрийн онцгой тохиолдол (амралт/өөрчлөгдсөн
/// цаг) байвал энгийн долоо хоногийн дүрмийн оронд тэдгээрийг харуулна —
/// сервер талын `resolveEffectiveSchedule`-тэй ижил дараалал.
class _WeeklyHoursTable extends StatelessWidget {
  const _WeeklyHoursTable({required this.branch});

  final BranchDetail branch;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    final now = DateTime.now();
    final today = branch.effectiveScheduleDetailAt(now).rule.weekday;
    final todayIndex = _weekdayOrder.indexOf(today);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final weekday in _weekdayOrder)
          Builder(
            builder: (context) {
              final offset = _weekdayOrder.indexOf(weekday) - todayIndex;
              final detail = branch.effectiveScheduleDetailAt(
                now.add(Duration(days: offset)),
              );
              final rule = detail.rule;
              final hours = !rule.isOpen
                  ? 'Хаалттай'
                  : (rule.openTime != null && rule.closeTime != null
                        ? '${rule.openTime}–${rule.closeTime}'
                        : 'Цагийн мэдээлэл тодорхойгүй');
              final style = weekday == today
                  ? TextStyle(fontWeight: FontWeight.w700)
                  : TextStyle(color: color);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 72,
                      child: Text(_weekdayLabels[weekday]!, style: style),
                    ),
                    Expanded(
                      child: Text(
                        detail.label == null
                            ? hours
                            : '$hours (${detail.label})',
                        style: style,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

/// Ойрын тусгай өдрүүд (амралт/өөрчлөгдсөн цаг) болон улирлын хуваарийн
/// мэдэгдэл — зөвхөн өнөөдрөөс хойшхи (одоо хүчинтэй/ирээдүйн) зүйлийг
/// харуулна, өнгөрсөн тусгай өдрүүдийг харуулах шаардлагагүй.
class _UpcomingScheduleNotices extends StatelessWidget {
  const _UpcomingScheduleNotices({required this.branch});

  final BranchDetail branch;

  static String get _today {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static List<BranchScheduleException> _upcomingExceptions(
    BranchDetail branch,
  ) => branch.scheduleExceptions
      .where((exception) => exception.date.compareTo(_today) >= 0)
      .toList(growable: false);

  static List<BranchScheduleSeason> _activeOrUpcomingSeasons(
    BranchDetail branch,
  ) => branch.scheduleSeasons
      .where((season) => season.endsOn.compareTo(_today) >= 0)
      .toList(growable: false);

  static bool hasAny(BranchDetail branch) =>
      _upcomingExceptions(branch).isNotEmpty ||
      _activeOrUpcomingSeasons(branch).isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final exceptions = _upcomingExceptions(branch);
    final seasons = _activeOrUpcomingSeasons(branch);
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Онцгой өдрүүд',
          style: Theme.of(context).textTheme.labelLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        for (final exception in exceptions)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '${exception.date}: ${exception.label ?? (exception.isOpen ? 'Өөрчлөгдсөн цагтай' : 'Амарна')}'
              '${exception.isOpen && exception.openTime != null && exception.closeTime != null ? ' (${exception.openTime}–${exception.closeTime})' : ''}',
              style: TextStyle(color: color),
            ),
          ),
        for (final season in seasons)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              'Удахгүй: ${season.name} (${season.startsOn} – ${season.endsOn})',
              style: TextStyle(color: color),
            ),
          ),
      ],
    );
  }
}

class _NoBranches extends StatelessWidget {
  const _NoBranches();

  @override
  Widget build(BuildContext context) => const GlassSurface(
    child: Row(
      children: [
        Icon(Icons.storefront_outlined),
        SizedBox(width: 12),
        Expanded(child: Text('Энэ байгууллага идэвхтэй салбаргүй байна.')),
      ],
    ),
  );
}

class _NotFound extends StatelessWidget {
  const _NotFound({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off, size: 48),
          const SizedBox(height: 12),
          const Text('Байгууллага олдсонгүй'),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onBack,
            child: const Text('Жагсаалт руу буцах'),
          ),
        ],
      ),
    ),
  );
}

/// Байгууллага ачаалж чадаагүй үед — дэлгэрэнгүй болон захиалгын хуудас хоёулаа ашиглана.
class OrganizationLoadError extends StatelessWidget {
  const OrganizationLoadError({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) =>
      ErrorView(message: message, onRetry: onRetry);
}
