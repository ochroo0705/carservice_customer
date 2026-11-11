import 'package:carservice_customer/app/app_messages.dart';
import 'package:carservice_customer/app/theme/app_surfaces.dart';
import 'package:carservice_customer/app/theme/app_theme.dart';
import 'package:carservice_customer/core/widgets/animations.dart';
import 'package:carservice_customer/core/widgets/offline_banner.dart';
import 'package:carservice_customer/core/widgets/skeletons.dart';
import 'package:carservice_customer/features/booking/domain/appointment.dart';
import 'package:carservice_customer/features/booking/domain/appointment_payment.dart';
import 'package:carservice_customer/features/booking/domain/appointment_status.dart';
import 'package:carservice_customer/features/booking/domain/service_progress.dart';
import 'package:carservice_customer/features/booking/domain/walk_in_order.dart';
import 'package:carservice_customer/features/booking/auth/presentation/auth_controller.dart';
import 'package:carservice_customer/features/booking/presentation/controllers/appointments_controller.dart';
import 'package:carservice_customer/features/booking/presentation/controllers/appointments_state.dart';
import 'package:carservice_customer/features/history/presentation/format_amount.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:carservice_customer/core/widgets/state_views.dart';
import 'package:carservice_customer/core/widgets/cs_ui.dart';
import 'package:carservice_customer/features/booking/presentation/widgets/appointment_status_style.dart';

class AppointmentsScreen extends StatelessWidget {
  const AppointmentsScreen({
    required this.onLoginRequested,
    required this.onAppointmentSelected,
    required this.onPaymentRequested,
    required this.onWalkInOrderSelected,
    super.key,
  });

  final VoidCallback onLoginRequested;
  final ValueChanged<String> onAppointmentSelected;
  final ValueChanged<Appointment> onPaymentRequested;

  /// Захиалгагүй (walk-in) захиалгын дэлгэрэнгүй рүү шилжих — аргумент нь
  /// [WalkInOrder.progress.id] (Appointment.id-той адил нэр зайд, гэхдээ
  /// огт өөр entity).
  final ValueChanged<String> onWalkInOrderSelected;

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = context.select<AuthController, bool>((c) => c.isAuthenticated);
    final controller = context.watch<AppointmentsController>();
    return AppShellBackground(
      child: SafeArea(
        child: isAuthenticated
            ? _AppointmentsBody(
                controller: controller,
                onAppointmentSelected: onAppointmentSelected,
                onPaymentRequested: onPaymentRequested,
                onWalkInOrderSelected: onWalkInOrderSelected,
              )
            : _UnauthenticatedPrompt(onLoginRequested: onLoginRequested),
      ),
    );
  }
}

class _UnauthenticatedPrompt extends StatelessWidget {
  const _UnauthenticatedPrompt({required this.onLoginRequested});

  final VoidCallback onLoginRequested;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CsIconTile(icon: Icons.event_note_outlined, size: 64),
          const SizedBox(height: 18),
          Text(
            'Захиалгаа харахын тулд нэвтэрнэ үү',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.44,
              color: CarserviceTheme.of(context).ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Таны цагийн хүсэлтүүд энд харагдана.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: CarserviceTheme.of(context).mutedText),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            key: const ValueKey('appointments-login'),
            onPressed: onLoginRequested,
            icon: const Icon(Icons.login_rounded),
            label: const Text('Нэвтрэх'),
          ),
        ],
      ),
    ),
  );
}

class _AppointmentsBody extends StatefulWidget {
  const _AppointmentsBody({
    required this.controller,
    required this.onAppointmentSelected,
    required this.onPaymentRequested,
    required this.onWalkInOrderSelected,
  });

  final AppointmentsController controller;
  final ValueChanged<String> onAppointmentSelected;
  final ValueChanged<Appointment> onPaymentRequested;
  final ValueChanged<String> onWalkInOrderSelected;

  @override
  State<_AppointmentsBody> createState() => _AppointmentsBodyState();
}

class _AppointmentsBodyState extends State<_AppointmentsBody> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController = TextEditingController(text: widget.controller.searchQuery);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.state;
    // Only blank the page when there is nothing to show. `load()` carries the
    // previous appointments through `loading` (see AppointmentsController),
    // so a refresh — cancelling an appointment, a push arriving — can keep
    // the list on screen. Swapping in the skeleton instead would unmount the
    // search field and the tab bar below with it, which reads as the whole
    // page flashing. In-flight cancels already show their own row spinner.
    if (state.status == AppointmentsStatus.initial ||
        (state.status == AppointmentsStatus.loading &&
            state.appointments.isEmpty &&
            state.walkInOrders.isEmpty)) {
      return Semantics(
        container: true,
        liveRegion: true,
        label: 'Захиалгуудыг ачаалж байна',
        child: const SkeletonCardList(),
      );
    }
    if (state.status == AppointmentsStatus.error) {
      return ErrorView(
        message: state.message ?? 'Тодорхойгүй алдаа гарлаа.',
        onRetry: widget.controller.load,
        retryKey: const ValueKey('appointments-retry'),
      );
    }
    if (state.status == AppointmentsStatus.empty) {
      return const EmptyView(
        icon: Icons.event_available_outlined,
        title: 'Цагийн хүсэлт алга',
        message: 'Байгууллага сонгож цаг захиалахад энд харагдана.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.isFromCache)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: OfflineBanner(
              message: 'Сүлжээгүй байна — сүүлд ачаалсан захиалгуудыг харуулж байна',
              semanticsLabel:
                  'Сүлжээгүй байна. Сүүлд ачаалсан захиалгуудын жагсаалтыг харуулж байна.',
              retryKey: const ValueKey('appointments-offline-retry'),
              onRetry: widget.controller.load,
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: TextField(
            key: const ValueKey('appointments-search'),
            controller: _searchController,
            onChanged: widget.controller.setSearchQuery,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Хайх (байгууллага, салбар, улсын дугаар)',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: widget.controller.searchQuery.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Цэвэрлэх',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _searchController.clear();
                        widget.controller.setSearchQuery('');
                      },
                    ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: _SegmentedTabs(controller: _tabController),
        ),
        // Төлвийн шүүлтүүр — идэвхтэй табын жагсаалтад байгаа төлвүүдээс.
        AnimatedBuilder(
          animation: Listenable.merge([widget.controller, _tabController]),
          builder: (context, _) {
            final isAppointmentsTab = _tabController.index == 0;
            return _StatusPills(
              available: isAppointmentsTab
                  ? widget.controller.availableAppointmentStatuses
                  : widget.controller.availableWalkInStatuses,
              selected: isAppointmentsTab
                  ? widget.controller.selectedAppointmentStatus
                  : widget.controller.selectedWalkInStatus,
              onSelect: (label) {
                if (isAppointmentsTab) {
                  widget.controller.selectAppointmentStatus(label);
                } else {
                  widget.controller.selectWalkInStatus(label);
                }
              },
            );
          },
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _AppointmentsOnlyList(
                controller: widget.controller,
                onAppointmentSelected: widget.onAppointmentSelected,
                onPaymentRequested: widget.onPaymentRequested,
              ),
              _WalkInOrdersOnlyList(
                controller: widget.controller,
                onWalkInOrderSelected: widget.onWalkInOrderSelected,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// "Цагийн захиалгууд | Засварын захиалгууд" as a pill segmented control:
/// the selected tab is a navy pill inside an outlined card track.
class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs({required this.controller});

  final TabController controller;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: theme.cardBorder),
      ),
      child: TabBar(
        key: const ValueKey('appointments-tab-bar'),
        controller: controller,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerHeight: 0,
        indicator: BoxDecoration(
          color: theme.inverse,
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        labelColor: theme.onInverse,
        unselectedLabelColor: theme.mutedText,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        splashBorderRadius: BorderRadius.circular(AppRadii.pill),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        tabs: const [
          Tab(text: 'Цагийн захиалгууд', height: 38),
          Tab(text: 'Засварын захиалгууд', height: 38),
        ],
      ),
    );
  }
}

/// A horizontally scrolling row of [CsChoicePill]s: "Бүгд" + each status
/// present in the active tab's list.
class _StatusPills extends StatelessWidget {
  const _StatusPills({
    required this.available,
    required this.selected,
    required this.onSelect,
  });

  final List<String> available;
  final String? selected;

  /// Passing `null` clears the filter ("Бүгд").
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    // Ганцхан төлөв байхад шүүх утгагүй.
    if (available.length < 2 && selected == null) {
      return const SizedBox(height: 4);
    }
    return SingleChildScrollView(
      key: const ValueKey('appointments-status-filters'),
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          CsChoicePill(
            key: const ValueKey('status-filter-option-all'),
            label: 'Бүгд',
            selected: selected == null,
            onTap: () => onSelect(null),
          ),
          for (final label in available) ...[
            const SizedBox(width: 8),
            CsChoicePill(
              key: ValueKey('status-filter-option-$label'),
              label: label,
              selected: selected == label,
              onTap: () => onSelect(selected == label ? null : label),
            ),
          ],
        ],
      ),
    );
  }
}

class _NoFilterResults extends StatelessWidget {
  const _NoFilterResults();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CsIconTile(
            icon: Icons.search_off_rounded,
            size: 56,
            color: CarserviceTheme.of(context).mutedText,
            background: CarserviceTheme.of(context).card,
          ),
          const SizedBox(height: 12),
          Text(
            'Илэрц олдсонгүй',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: CarserviceTheme.of(context).ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Хайлт эсвэл төлвийн шүүлтүүрээ өөрчилж үзээрэй.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: CarserviceTheme.of(context).mutedText),
          ),
        ],
      ),
    ),
  );
}

class _AppointmentsOnlyList extends StatelessWidget {
  const _AppointmentsOnlyList({
    required this.controller,
    required this.onAppointmentSelected,
    required this.onPaymentRequested,
  });

  final AppointmentsController controller;
  final ValueChanged<String> onAppointmentSelected;
  final ValueChanged<Appointment> onPaymentRequested;

  @override
  Widget build(BuildContext context) {
    final appointments = controller.sortedAppointments;
    if (appointments.isEmpty) return const _NoFilterResults();
    return RefreshIndicator(
      onRefresh: controller.load,
      child: ListView.separated(
        key: const PageStorageKey('appointments-only-list'),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        itemCount: appointments.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final appointment = appointments[index];
          return RiseIn(
            index: index,
            child: _AppointmentCard(
              appointment: appointment,
              isCancelling: controller.isCancelling(appointment.id),
              onTap: () => onAppointmentSelected(appointment.id),
              onCancel: appointment.canCancel
                  ? () => _confirmCancel(context, controller, appointment)
                  : null,
              onPaymentTap: appointment.canPayFee ? () => onPaymentRequested(appointment) : null,
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmCancel(
    BuildContext context,
    AppointmentsController controller,
    Appointment appointment,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Захиалга цуцлах уу?'),
        content: Text('${appointment.tenantName} — ${appointment.branchName}'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Үгүй')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Тийм, цуцлах'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final error = await controller.cancel(appointment.id);
    if (error != null && context.mounted) {
      AppMessages.show(error);
    }
  }
}

class _WalkInOrdersOnlyList extends StatelessWidget {
  const _WalkInOrdersOnlyList({required this.controller, required this.onWalkInOrderSelected});

  final AppointmentsController controller;
  final ValueChanged<String> onWalkInOrderSelected;

  @override
  Widget build(BuildContext context) {
    final walkInOrders = controller.visibleWalkInOrders;
    if (walkInOrders.isEmpty) return const _NoFilterResults();
    return RefreshIndicator(
      onRefresh: controller.load,
      child: ListView.separated(
        key: const PageStorageKey('walk-in-orders-only-list'),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        itemCount: walkInOrders.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final order = walkInOrders[index];
          return RiseIn(
            index: index,
            child: _WalkInOrderCard(
              order: order,
              onTap: () => onWalkInOrderSelected(order.progress.id),
            ),
          );
        },
      ),
    );
  }
}

/// Appointment-гүй (ажилтан шууд үүсгэсэн) захиалгын карт — цуцлах/хураамж
/// гэсэн ойлголт байхгүй, зөвхөн дэлгэрэнгүй рүү шилжинэ (харах:
/// `WalkInOrderDetailScreen`).
class _WalkInOrderCard extends StatelessWidget {
  const _WalkInOrderCard({required this.order, this.onTap});

  final WalkInOrder order;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    final progress = order.progress;
    return CsCard(
      key: ValueKey('walk-in-order-card-${progress.id}'),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeading(
            title: order.tenantName,
            subtitle: order.branchName,
            badge: CsBadge(
              progress.status.localizedLabel,
              tone: serviceProgressStatusTone(progress.status),
              dot: progress.status == ServiceProgressStatus.inProgress,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '№${progress.number}',
                style: csMono(fontSize: 12, color: theme.mutedText),
              ),
              if (progress.vehiclePlate != null)
                CsPlate(progress.vehiclePlate!, fontSize: 12),
            ],
          ),
          if (progress.hasOutstandingBalance) ...[
            const SizedBox(height: 10),
            _outstandingBalanceChip(progress),
          ],
        ],
      ),
    );
  }
}

/// Monogram + service name + branch, with the status badge on the right.
class _CardHeading extends StatelessWidget {
  const _CardHeading({
    required this.title,
    required this.subtitle,
    required this.badge,
  });

  final String title;
  final String subtitle;
  final Widget badge;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(child: CsMonogram(name: title, size: 44)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.16,
                  color: theme.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(fontSize: 13, color: theme.mutedText),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        badge,
      ],
    );
  }
}

/// Дууссан ч бүрэн төлөгдөөгүй захиалгын "Төлбөр дутуу · X₮" badge — яагаад
/// түүхэнд шилжээгүйг ойлгуулна.
Widget _outstandingBalanceChip(AppointmentServiceProgress progress) {
  final due = progress.outstandingAmount;
  return CsBadge(
    key: ValueKey('outstanding-balance-${progress.id}'),
    due == null ? 'Төлбөр дутуу' : 'Төлбөр дутуу · ${formatAmount(due.round())}₮',
    tone: CsTone.warning,
  );
}

/// A tinted strip inside a card (fee notices).
class _CardNotice extends StatelessWidget {
  const _CardNotice({
    required this.tint,
    required this.background,
    required this.child,
    super.key,
  });

  final Color tint;
  final Color background;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: background,
      border: Border.all(color: tint.withValues(alpha: 0.35)),
      borderRadius: BorderRadius.circular(AppRadii.large),
    ),
    child: child,
  );
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({
    required this.appointment,
    required this.isCancelling,
    this.onTap,
    this.onCancel,
    this.onPaymentTap,
  });

  final Appointment appointment;
  final bool isCancelling;
  final VoidCallback? onTap;
  final VoidCallback? onCancel;

  /// Non-null only when this appointment has an unpaid/underpaid/failed fee
  /// (`CUSTOMER_API_CONTRACT.md` §4.1) — tapping opens the payment screen.
  final VoidCallback? onPaymentTap;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    final brightness = Theme.of(context).brightness;
    final progress = appointment.serviceProgress;
    final red = AppColors.readable(AppColors.red, brightness);
    final green = AppColors.readable(AppColors.green, brightness);
    return CsCard(
      key: ValueKey('appointment-card-${appointment.id}'),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeading(
            title: appointment.tenantName,
            subtitle: appointment.branchName,
            badge: progress != null
                ? CsBadge(
                    progress.status.localizedLabel,
                    tone: serviceProgressStatusTone(progress.status),
                    dot: progress.status == ServiceProgressStatus.inProgress,
                  )
                : CsBadge(
                    appointment.status.localizedLabel,
                    tone: appointmentStatusTone(appointment.status),
                  ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.event_outlined, size: 15, color: theme.mutedText),
                  const SizedBox(width: 6),
                  Text(
                    _formatDateTime(appointment.requestedAt),
                    style: csMono(fontSize: 13, color: theme.ink),
                  ),
                ],
              ),
              if (appointment.vehiclePlate != null)
                Semantics(
                  label: 'Тээврийн хэрэгсэл',
                  child: CsPlate(appointment.vehiclePlate!, fontSize: 12),
                ),
            ],
          ),
          if (progress?.hasOutstandingBalance ?? false) ...[
            const SizedBox(height: 10),
            _outstandingBalanceChip(progress!),
          ],
          // Захиалга (ServiceOrder) үүсмэгц доорх явцын хэсэг бодит
          // үйлчилгээ бүрийг статус/үнэтэй нь жагсаадаг тул ангиллын мөр
          // илүүц болно — түүнээс ч илүү, захиалга анхны ангиллаас хальж
          // өссөн байж болох тул төөрөгдүүлнэ. Захиалга үүсээгүй байхад л
          // үйлчлүүлэгчид юу захиалснаа сануулах цорын ганц мөр хэвээр.
          if (progress == null && appointment.categoryNames.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final name in appointment.categoryNames) CsTag(name),
              ],
            ),
          ],
          if (appointment.note != null &&
              appointment.note!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              appointment.note!,
              style: TextStyle(fontSize: 13, color: theme.mutedText),
            ),
          ],
          if (onPaymentTap != null) ...[
            const SizedBox(height: 12),
            _CardNotice(
              tint: AppColors.red,
              background: theme.accentSoft,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      appointment.payment!.status == AppointmentFeeStatus.failed
                          ? 'Хураамжийн QR үүсгэхэд алдаа гарсан'
                          : 'Цаг захиалгын хураамж төлөгдөөгүй',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: red,
                      ),
                    ),
                  ),
                  TextButton(
                    key: ValueKey('pay-${appointment.id}'),
                    onPressed: onPaymentTap,
                    child: const Text('Төлөх'),
                  ),
                ],
              ),
            ),
          ],
          // Хураамж төлөгдсөнийг тусад нь харуулна — цаг захиалгын status
          // (Хүлээгдэж буй) төлбөрөөр өөрчлөгддөггүй (ажилтан баталгаажуулна).
          if (appointment.payment?.status == AppointmentFeeStatus.paid) ...[
            const SizedBox(height: 12),
            _CardNotice(
              key: ValueKey('fee-paid-${appointment.id}'),
              tint: AppColors.green,
              background: theme.successSoft,
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded, size: 16, color: green),
                  const SizedBox(width: 8),
                  Text(
                    'Хураамж төлөгдсөн',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: green,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (appointment.payment?.status ==
              AppointmentFeeStatus.refunded) ...[
            const SizedBox(height: 12),
            _CardNotice(
              key: ValueKey('fee-refunded-${appointment.id}'),
              tint: AppColors.accent,
              background: theme.shellBackground,
              child: Text(
                'Хураамж буцаагдсан',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: theme.ink,
                ),
              ),
            ),
          ],
          if (onCancel != null) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              // Дэлгэрэнгүй хуудасны цуцлах товчтой ижил аюулын өнгө — нэг
              // үйлдэл хоёр газар өөр өөр харагдах нь эрэмбийн дохиог
              // сулруулна. Хэлбэрийг нь тэнцүүлээгүй (тэнд
              // OutlinedButton.icon, энд компакт TextButton): картын доторх
              // хоёрдогч үйлдэл нь хуудсын төгсгөлийн үйлдэлтэй ижил жин
              // үүрэх ёсгүй.
              child: TextButton(
                key: ValueKey('cancel-${appointment.id}'),
                onPressed: isCancelling ? null : onCancel,
                style: TextButton.styleFrom(foregroundColor: red),
                child: isCancelling
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Цуцлах'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _formatDateTime(DateTime value) =>
    '${value.year}.${value.month.toString().padLeft(2, '0')}.${value.day.toString().padLeft(2, '0')} '
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
