import 'package:carservice_customer/app/theme/app_theme.dart';
import 'package:carservice_customer/core/widgets/cs_ui.dart';
import 'package:carservice_customer/core/widgets/coming_soon_view.dart';
import 'package:carservice_customer/core/widgets/animations.dart';
import 'package:carservice_customer/core/widgets/filter_controls.dart';
import 'package:carservice_customer/core/widgets/offline_banner.dart';
import 'package:carservice_customer/core/widgets/skeletons.dart';
import 'package:carservice_customer/features/diagnostics/domain/diagnostics_repository.dart';
import 'package:carservice_customer/features/diagnostics/presentation/controllers/diagnostics_controller.dart';
import 'package:carservice_customer/features/diagnostics/presentation/screens/diagnostics_screen.dart';
import 'package:carservice_customer/features/history/domain/cancelled_appointment_summary.dart';
import 'package:carservice_customer/features/history/domain/service_order.dart';
import 'package:carservice_customer/features/booking/auth/presentation/auth_controller.dart';
import 'package:carservice_customer/features/history/presentation/controllers/history_controller.dart';
import 'package:carservice_customer/features/history/presentation/controllers/history_state.dart';
import 'package:carservice_customer/features/history/presentation/format_amount.dart';
import 'package:carservice_customer/features/history/domain/service_order_status.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:carservice_customer/core/widgets/state_views.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({
    required this.onLoginRequested,
    required this.onOrderSelected,
    required this.diagnosticsRepository,
    required this.onDiagnosticReportSelected,
    this.reconnects,
    super.key,
  });

  final VoidCallback onLoginRequested;
  final ValueChanged<String> onOrderSelected;

  /// "Оношилгооны жагсаалт" tab data source.
  final DiagnosticsRepository diagnosticsRepository;
  final ValueChanged<String> onDiagnosticReportSelected;

  /// Ticks on network reconnect; the diagnostics tab retries a failed load.
  final Listenable? reconnects;

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = context.select<AuthController, bool>((c) => c.isAuthenticated);
    final controller = context.watch<HistoryController>();
    return ColoredBox(
      color: CarserviceTheme.of(context).shellBackground,
      child: SafeArea(
        top: false,
        child: isAuthenticated
            ? _HistoryBody(
                controller: controller,
                onOrderSelected: onOrderSelected,
                diagnosticsRepository: diagnosticsRepository,
                onDiagnosticReportSelected: onDiagnosticReportSelected,
                reconnects: reconnects,
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
          const CsIconTile(icon: Icons.receipt_long_outlined, size: 64),
          const SizedBox(height: 18),
          Text(
            'Түүхээ харахын тулд нэвтэрнэ үү',
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
            'Таны хийлгэсэн засварын түүх энд харагдана.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: CarserviceTheme.of(context).mutedText),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            key: const ValueKey('history-login'),
            onPressed: onLoginRequested,
            icon: const Icon(Icons.login_rounded),
            label: const Text('Нэвтрэх'),
          ),
        ],
      ),
    ),
  );
}

/// Тавуур: "Засварын түүх" (order/cancelled appointment list) болон
/// "Оношилгоо" (diagnostics report list) хоёр tab-тай. Хоёр tab бие даасан
/// controller/state хэрэглэдэг тул алдаа/ачаалалт тус тусдаа харагдана.
class _HistoryBody extends StatefulWidget {
  const _HistoryBody({
    required this.controller,
    required this.onOrderSelected,
    required this.diagnosticsRepository,
    required this.onDiagnosticReportSelected,
    this.reconnects,
  });

  final HistoryController controller;
  final ValueChanged<String> onOrderSelected;
  final DiagnosticsRepository diagnosticsRepository;
  final ValueChanged<String> onDiagnosticReportSelected;
  final Listenable? reconnects;

  @override
  State<_HistoryBody> createState() => _HistoryBodyState();
}

class _HistoryBodyState extends State<_HistoryBody> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final DiagnosticsController _diagnosticsController = DiagnosticsController(
    widget.diagnosticsRepository,
  )..load();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    widget.reconnects?.addListener(_onReconnect);
  }

  @override
  void didUpdateWidget(covariant _HistoryBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reconnects != widget.reconnects) {
      oldWidget.reconnects?.removeListener(_onReconnect);
      widget.reconnects?.addListener(_onReconnect);
    }
  }

  void _onReconnect() {
    if (_diagnosticsController.status == DiagnosticsStatus.error) {
      _diagnosticsController.load();
    }
  }

  @override
  void dispose() {
    widget.reconnects?.removeListener(_onReconnect);
    _tabController.dispose();
    _diagnosticsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          // Segmented pill control: navy fill on the active tab.
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: theme.card,
              borderRadius: BorderRadius.circular(AppRadii.pill),
              border: Border.all(color: theme.cardBorder),
            ),
            child: TabBar(
              key: const ValueKey('history-tab-bar'),
              controller: _tabController,
              dividerHeight: 0,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: theme.inverse,
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
              labelColor: theme.onInverse,
              unselectedLabelColor: theme.mutedText,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              splashBorderRadius: BorderRadius.circular(AppRadii.pill),
              tabs: const [
                Tab(height: 38, text: 'Засварын түүх'),
                Tab(height: 38, text: 'Оношилгооны жагсаалт'),
              ],
            ),
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _AppointmentHistoryTab(
                controller: widget.controller,
                onOrderSelected: widget.onOrderSelected,
              ),
              DiagnosticsListView(
                controller: _diagnosticsController,
                onReportSelected: widget.onDiagnosticReportSelected,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Хайлт/шүүлтийн мөр (`SearchWithYearFilterBar`) энд, switch-ийн ГАДНА
/// байрлана — доорх төлөв (skeleton/error/empty) хэзээ ч энэ мөрийг unmount
/// хийхгүй. Өмнө нь хайлтын мөр `HistoryStatus.data`-гийн доторх
/// `_HistoryList`-д байсан бөгөөд query/year өөрчлөгдөх бүрт статус
/// `loading`/`empty` рүү шилжиж, `TextField`-ийг unmount хийснээр гар
/// товчлуур (keyboard) үсэг бүр дээр хаагдах алдаа гаргаж байсан.
class _AppointmentHistoryTab extends StatelessWidget {
  const _AppointmentHistoryTab({required this.controller, required this.onOrderSelected});

  final HistoryController controller;
  final ValueChanged<String> onOrderSelected;

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    // A refresh that already has rows keeps them on screen rather than
    // dropping back to the skeleton: `load()` carries the previous orders
    // through `loading` (see HistoryController), and History reloads on
    // events the customer did not trigger here — an appointment cancelled on
    // another tab, a terminal push. The skeleton is for a first load only.
    final status =
        state.status == HistoryStatus.loading &&
            (state.orders.isNotEmpty || state.cancelledAppointments.isNotEmpty)
        ? HistoryStatus.data
        : state.status;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: SearchWithYearFilterBar(
            searchFieldKey: const ValueKey('history-search'),
            filterButtonKey: const ValueKey('history-filter-button'),
            hintText: 'Байгууллага, салбар, дугаараар хайх',
            initialQuery: controller.query,
            onQueryChanged: controller.setQuery,
            years: controller.availableYears,
            selectedYear: controller.year,
            onYearSelected: controller.setYear,
          ),
        ),
        Expanded(
          child: switch (status) {
            HistoryStatus.initial || HistoryStatus.loading => Semantics(
              container: true,
              liveRegion: true,
              label: 'Түүхийг ачаалж байна',
              child: const SkeletonCardList(showTrailing: true),
            ),
            HistoryStatus.error => ErrorView(
              message: state.message ?? 'Тодорхойгүй алдаа гарлаа.',
              onRetry: controller.load,
              retryKey: const ValueKey('history-retry'),
            ),
            HistoryStatus.empty => const EmptyView(
              icon: Icons.receipt_long_outlined,
              title: 'Засварын түүх алга',
              message: 'Үйлчилгээ авсны дараа энд харагдана.',
            ),
            HistoryStatus.unavailable => const ComingSoonView(
              icon: Icons.receipt_long_outlined,
              title: 'Тун удахгүй',
              message: 'Засварын түүх удахгүй энд харагдана.',
            ),
            HistoryStatus.data => _HistoryList(
              controller: controller,
              onOrderSelected: onOrderSelected,
            ),
          },
        ),
      ],
    );
  }
}

class _HistoryList extends StatefulWidget {
  const _HistoryList({required this.controller, required this.onOrderSelected});

  final HistoryController controller;
  final ValueChanged<String> onOrderSelected;

  @override
  State<_HistoryList> createState() => _HistoryListState();
}

class _HistoryListState extends State<_HistoryList> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.extentAfter < 400 &&
          widget.controller.hasNextPage &&
          widget.controller.state.loadMoreMessage == null) {
        widget.controller.loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allOrders = widget.controller.state.orders;
    final allCancelled = widget.controller.state.cancelledAppointments;
    final orders = allOrders;
    final cancelledAppointments = allCancelled;
    final isFromCache = widget.controller.state.isFromCache;
    final hasFilter = widget.controller.query.isNotEmpty;
    final noResults = hasFilter && orders.isEmpty && cancelledAppointments.isEmpty;
    final offset = isFromCache ? 1 : 0;
    // D-085: cancelled/no-show/rejected appointments render after the order
    // cards, behind their own section header (only when there are any).
    final hasCancelledSection = cancelledAppointments.isNotEmpty;
    final itemCount =
        orders.length +
        offset +
        (hasCancelledSection ? 1 : 0) +
        cancelledAppointments.length +
        (widget.controller.hasNextPage ? 1 : 0);
    return noResults
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'Илэрц олдсонгүй',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: CarserviceTheme.of(context).mutedText),
              ),
            ),
          )
        : RefreshIndicator(
            onRefresh: widget.controller.load,
            child: ListView.separated(
              controller: _scrollController,
              key: const PageStorageKey('history-list'),
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              itemCount: itemCount,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final contentCount =
                    orders.length +
                    offset +
                    (hasCancelledSection ? 1 : 0) +
                    cancelledAppointments.length;
                if (index >= contentCount) {
                  return Padding(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: widget.controller.state.loadMoreMessage == null
                          ? const CircularProgressIndicator()
                          : OutlinedButton(
                              onPressed: widget.controller.loadMore,
                              child: const Text('Дахин ачаалах'),
                            ),
                    ),
                  );
                }
                if (isFromCache && index == 0) {
                  return OfflineBanner(
                    message: 'Сүлжээгүй байна — сүүлд ачаалсан түүхийг харуулж байна',
                    semanticsLabel:
                        'Сүлжээгүй байна. Сүүлд ачаалсан засварын түүхийг харуулж байна.',
                    retryKey: const ValueKey('history-offline-retry'),
                    onRetry: widget.controller.load,
                  );
                }
                final ordersEnd = offset + orders.length;
                if (index < ordersEnd) {
                  final order = orders[index - offset];
                  return RiseIn(
                    index: index - offset,
                    child: _OrderCard(order: order, onTap: () => widget.onOrderSelected(order.id)),
                  );
                }
                if (hasCancelledSection && index == ordersEnd) {
                  return const _CancelledSectionHeader();
                }
                final appt = cancelledAppointments[index - ordersEnd - 1];
                return RiseIn(
                  index: index - offset,
                  child: _CancelledAppointmentCard(appointment: appt),
                );
              },
            ),
          );
  }
}

class _CancelledSectionHeader extends StatelessWidget {
  const _CancelledSectionHeader();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(top: 10),
    child: CsSectionLabel('Цуцлагдсан / ирээгүй цагууд'),
  );
}

class _CancelledAppointmentCard extends StatelessWidget {
  const _CancelledAppointmentCard({required this.appointment});

  final CancelledAppointmentSummary appointment;

  @override
  Widget build(BuildContext context) => CsCard(
    key: ValueKey('history-cancelled-${appointment.id}'),
    child: _HistoryCardBody(
      date: appointment.requestedAt,
      title: appointment.tenantName,
      lines: [appointment.branchName, ?appointment.categoryName],
      badge: CsBadge(appointment.status.localizedLabel, tone: CsTone.accent),
    ),
  );
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onTap});

  final ServiceOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => CsCard(
    key: ValueKey('history-order-${order.id}'),
    onTap: onTap,
    child: _HistoryCardBody(
      date: order.completedAt,
      title: order.tenantName,
      lines: [order.branchName],
      plate: order.vehiclePlate,
      badge: order.isCancelled
          ? const CsBadge('Цуцлагдсан', tone: CsTone.accent)
          : CsBadge(
              order.status.localizedLabel,
              tone: switch (order.status) {
                ServiceOrderStatus.paid => CsTone.success,
                ServiceOrderStatus.partiallyPaid => CsTone.info,
                ServiceOrderStatus.unpaid => CsTone.accent,
              },
            ),
      amount: '${formatAmount(order.totalAmount)}₮',
    ),
  );
}

/// Mono date column · title + muted lines (+ plate) · badge and amount.
class _HistoryCardBody extends StatelessWidget {
  const _HistoryCardBody({
    required this.date,
    required this.title,
    required this.lines,
    required this.badge,
    this.plate,
    this.amount,
  });

  final DateTime date;
  final String title;
  final List<String> lines;
  final Widget badge;
  final String? plate;
  final String? amount;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: _formatDate(date),
          excludeSemantics: true,
          child: SizedBox(
            width: 44,
            child: Column(
              children: [
                Text(
                  '${_two(date.month)}/${_two(date.day)}',
                  style: csMono(fontSize: 13, color: theme.ink),
                ),
                Text('${date.year}', style: csMono(fontSize: 10, color: theme.mutedText)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: theme.ink),
              ),
              for (final line in lines) ...[
                const SizedBox(height: 2),
                Text(line, style: TextStyle(fontSize: 12, color: theme.mutedText)),
              ],
              if (plate != null) ...[const SizedBox(height: 8), CsPlate(plate!, fontSize: 11)],
            ],
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            badge,
            if (amount != null) ...[
              const SizedBox(height: 8),
              Text(amount!, style: csMono(fontSize: 14, color: theme.ink)),
            ],
          ],
        ),
      ],
    );
  }
}

String _two(int value) => value.toString().padLeft(2, '0');

String _formatDate(DateTime value) => '${value.year}.${_two(value.month)}.${_two(value.day)}';
