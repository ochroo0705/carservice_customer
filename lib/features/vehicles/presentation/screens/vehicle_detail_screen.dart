import 'package:carservice_customer/app/theme/app_theme.dart';
import 'package:carservice_customer/core/widgets/cs_ui.dart';
import 'package:carservice_customer/features/booking/domain/appointment.dart';
import 'package:carservice_customer/features/booking/domain/appointment_status.dart';
import 'package:carservice_customer/features/history/domain/service_order.dart';
import 'package:carservice_customer/features/history/domain/service_order_status.dart';
import 'package:carservice_customer/features/history/presentation/format_amount.dart';
import 'package:carservice_customer/features/booking/presentation/controllers/appointments_controller.dart';
import 'package:carservice_customer/features/history/presentation/controllers/history_controller.dart';
import 'package:carservice_customer/features/vehicles/domain/vehicle.dart';
import 'package:carservice_customer/features/vehicles/presentation/controllers/vehicles_controller.dart';
import 'package:carservice_customer/core/widgets/skeletons.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Resolves everything this page shows from the controllers themselves, given
/// only the vehicle's id.
///
/// It used to take the vehicle, its appointments, its orders and two loading
/// flags as constructor arguments, which meant the old router delegate had to
/// listen to three controllers and rebuild the **entire** page stack whenever
/// any of them changed — every tab, on every appointment reload. Reading them
/// here confines that rebuild to this page. Same pattern as
/// `AppointmentDetailScreen` (D-027).
class VehicleDetailScreen extends StatelessWidget {
  const VehicleDetailScreen({
    required this.vehicleId,
    required this.fallbackVehicle,
    required this.onBack,
    this.onAppointmentSelected,
    this.onOrderSelected,
    this.onRefreshHur,
    super.key,
  });

  final String vehicleId;

  /// Shown if the id is no longer in the list — a delete completing while this
  /// page is open must not throw, it just leaves the last known values up
  /// until the page is popped.
  final Vehicle fallbackVehicle;

  final VoidCallback onBack;
  final ValueChanged<String>? onAppointmentSelected;
  final ValueChanged<String>? onOrderSelected;
  final VoidCallback? onRefreshHur;

  @override
  Widget build(BuildContext context) {
    final vehicles = context.watch<VehiclesController>();
    final appointments = context.watch<AppointmentsController>();
    final history = context.watch<HistoryController>();
    final vehicle = vehicles.state.vehicles.firstWhere(
      (v) => v.id == vehicleId,
      orElse: () => fallbackVehicle,
    );
    final plate = vehicle.plate.trim().toUpperCase();

    return _VehicleDetailView(
      vehicle: vehicle,
      onBack: onBack,
      appointments: appointments.state.appointments
          .where((a) => a.vehiclePlate?.trim().toUpperCase() == plate)
          .toList(growable: false),
      appointmentsLoading: appointments.state.isLoading,
      onAppointmentSelected: onAppointmentSelected,
      orders: history.state.orders
          .where((o) => o.vehiclePlate?.trim().toUpperCase() == plate)
          .toList(growable: false),
      ordersLoading: history.state.isLoading,
      onOrderSelected: onOrderSelected,
      onRefreshHur: onRefreshHur,
      refreshingHur: vehicles.isRefreshing(vehicleId),
    );
  }
}

class _VehicleDetailView extends StatelessWidget {
  const _VehicleDetailView({
    required this.vehicle,
    required this.onBack,
    this.appointments = const [],
    this.appointmentsLoading = false,
    this.onAppointmentSelected,
    this.orders = const [],
    this.ordersLoading = false,
    this.onOrderSelected,
    this.onRefreshHur,
    this.refreshingHur = false,
  });

  final Vehicle vehicle;
  final VoidCallback onBack;
  final List<Appointment> appointments;
  final bool appointmentsLoading;
  final ValueChanged<String>? onAppointmentSelected;
  final List<ServiceOrder> orders;
  final bool ordersLoading;
  final ValueChanged<String>? onOrderSelected;
  final VoidCallback? onRefreshHur;
  final bool refreshingHur;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    final facts = <({String label, String value, bool mono})>[
      (label: 'Үйлдвэрлэсэн он', value: _value(vehicle.year?.toString()), mono: true),
      (label: 'VIN', value: _value(vehicle.vin), mono: true),
      (label: 'Өнгө', value: _value(vehicle.colorName), mono: false),
      (label: 'Моторын багтаамж', value: _capacity(vehicle.capacity), mono: true),
      (label: 'Шатахуун', value: _value(vehicle.fuelType), mono: false),
      (label: 'Жолооны хүрд', value: _value(vehicle.wheelPosition), mono: false),
      (label: 'Зориулалт', value: _value(vehicle.purpose), mono: false),
    ];
    final subtitle = [
      if (vehicle.year != null) '${vehicle.year}',
      if (vehicle.fuelType?.trim().isNotEmpty ?? false) vehicle.fuelType!.trim(),
    ].join(' · ');
    final lastOrder = orders.isEmpty
        ? null
        : orders.map((o) => o.completedAt).reduce((a, b) => a.isAfter(b) ? a : b);

    return Scaffold(
      backgroundColor: theme.shellBackground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                children: [
                  CsCircleButton.back(context, onPressed: onBack),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Машины дэлгэрэнгүй',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: theme.ink),
                    ),
                  ),
                  if (onRefreshHur != null)
                    refreshingHur
                        ? SizedBox(
                            key: const ValueKey('vehicle-refresh-hur'),
                            width: 44,
                            height: 44,
                            child: Center(
                              child: SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: theme.ink),
                              ),
                            ),
                          )
                        : CsCircleButton(
                            key: const ValueKey('vehicle-refresh-hur'),
                            icon: Icons.refresh_rounded,
                            tooltip: 'HUR-аас шинэчлэх',
                            onPressed: onRefreshHur,
                          ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                children: [
                  CsHeroCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${vehicle.make} ${vehicle.model}',
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w600,
                                  color: theme.onHero,
                                ),
                              ),
                              if (subtitle.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  subtitle,
                                  style: TextStyle(fontSize: 13, color: theme.onHeroMuted),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        CsPlate(vehicle.plate, onHero: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _StatTile(
                          label: 'Үйлчилгээ',
                          value: '${vehicle.serviceCount}',
                          mono: true,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatTile(
                          label: 'Оношилгоо',
                          value: '${vehicle.diagnosisCount}',
                          mono: true,
                        ),
                      ),
                      if (lastOrder != null) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: _StatTile(
                            label: 'Сүүлийн засвар',
                            value: _formatDate(lastOrder),
                            mono: true,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 22),
                  const CsSectionLabel('ХУР-ийн техникийн мэдээлэл'),
                  const SizedBox(height: 8),
                  CsCard(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Column(
                      children: [
                        for (var i = 0; i < facts.length; i++) ...[
                          if (i > 0) Divider(height: 1, thickness: 1, color: theme.shellBackground),
                          _FactRow(
                            label: facts[i].label,
                            value: facts[i].value,
                            mono: facts[i].mono,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  _AppointmentsSection(
                    appointments: appointments,
                    isLoading: appointmentsLoading,
                    onAppointmentSelected: onAppointmentSelected,
                  ),
                  const SizedBox(height: 22),
                  _ServiceOrdersSection(
                    orders: orders,
                    isLoading: ordersLoading,
                    onOrderSelected: onOrderSelected,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Энд харагдах мэдээлэл нь бүртгэлд хадгалагдсан HUR-ийн утгууд дээр үндэслэнэ.',
                    style: TextStyle(fontSize: 12, color: theme.mutedText),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _value(String? value) => value == null || value.trim().isEmpty ? '—' : value;

  static String _capacity(int? value) => value == null ? '—' : '$value см³';
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, this.mono = false});

  final String label;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    return CsCard(
      radius: AppRadii.control,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: theme.mutedText)),
          const SizedBox(height: 2),
          Text(
            value,
            style: mono
                ? csMono(fontSize: 15, color: theme.ink)
                : TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: theme.ink),
          ),
        ],
      ),
    );
  }
}

/// A mono label + one divided card: the shared shape of both history lists.
class _HistorySection extends StatelessWidget {
  const _HistorySection({
    required this.label,
    required this.count,
    required this.isLoading,
    required this.emptyText,
    required this.rows,
  });

  final String label;
  final int count;
  final bool isLoading;
  final String emptyText;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CsSectionLabel(
          label,
          trailing: Text('$count', style: csMono(fontSize: 11, color: theme.mutedText)),
        ),
        const SizedBox(height: 8),
        if (isLoading)
          const SkeletonCardColumn(itemCount: 2, showTrailing: true)
        else
          CsCard(
            padding: EdgeInsets.zero,
            child: rows.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(emptyText, style: TextStyle(fontSize: 13, color: theme.mutedText)),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < rows.length; i++) ...[
                        if (i > 0) Divider(height: 1, thickness: 1, color: theme.shellBackground),
                        rows[i],
                      ],
                    ],
                  ),
          ),
      ],
    );
  }
}

/// One `.hist` row: mono date column, title + muted branch, trailing status.
class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.dateTop,
    required this.dateBottom,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.extra,
    this.onTap,
  });

  final String dateTop;
  final String dateBottom;
  final String title;
  final String subtitle;
  final String? extra;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              child: Column(
                children: [
                  Text(dateTop, style: csMono(fontSize: 12, color: theme.ink)),
                  Text(dateBottom, style: csMono(fontSize: 10, color: theme.mutedText)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.ink),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: theme.mutedText),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (extra != null) ...[
                    const SizedBox(height: 2),
                    Text(extra!, style: TextStyle(fontSize: 12, color: theme.mutedText)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _ServiceOrdersSection extends StatelessWidget {
  const _ServiceOrdersSection({
    required this.orders,
    required this.isLoading,
    required this.onOrderSelected,
  });

  final List<ServiceOrder> orders;
  final bool isLoading;
  final ValueChanged<String>? onOrderSelected;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    final sorted = [...orders]..sort((a, b) => b.completedAt.compareTo(a.completedAt));
    return _HistorySection(
      label: 'Засварын түүх',
      count: sorted.length,
      isLoading: isLoading,
      emptyText: 'Энэ машинтай холбоотой үйлчилгээний түүх байхгүй байна.',
      rows: [
        for (final order in sorted)
          _HistoryRow(
            dateTop: _monthDay(order.completedAt),
            dateBottom: '${order.completedAt.year}',
            title: order.tenantName,
            subtitle: order.branchName,
            onTap: onOrderSelected == null ? null : () => onOrderSelected!(order.id),
            trailing: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _paymentBadge(order),
                const SizedBox(height: 4),
                Text(
                  '${formatAmount(order.totalAmount)}₮',
                  style: csMono(fontSize: 13, color: theme.ink),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

Widget _paymentBadge(ServiceOrder order) {
  if (order.isCancelled) return const CsBadge('Цуцлагдсан', tone: CsTone.accent);
  return CsBadge(
    order.status.localizedLabel,
    tone: switch (order.status) {
      ServiceOrderStatus.paid => CsTone.success,
      ServiceOrderStatus.partiallyPaid => CsTone.info,
      ServiceOrderStatus.unpaid => CsTone.accent,
    },
  );
}

class _AppointmentsSection extends StatelessWidget {
  const _AppointmentsSection({
    required this.appointments,
    required this.isLoading,
    required this.onAppointmentSelected,
  });

  final List<Appointment> appointments;
  final bool isLoading;
  final ValueChanged<String>? onAppointmentSelected;

  @override
  Widget build(BuildContext context) {
    final sorted = [...appointments]..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
    return _HistorySection(
      label: 'Цагийн захиалгын түүх',
      count: sorted.length,
      isLoading: isLoading,
      emptyText: 'Энэ машинтай холбоотой цагийн захиалга байхгүй байна.',
      rows: [
        for (final appointment in sorted)
          _HistoryRow(
            dateTop: _monthDay(appointment.requestedAt),
            dateBottom: _time(appointment.requestedAt),
            title: appointment.tenantName,
            subtitle: appointment.branchName,
            extra: appointment.categoryNames.isEmpty ? null : appointment.categoryNames.join(' · '),
            onTap: onAppointmentSelected == null
                ? null
                : () => onAppointmentSelected!(appointment.id),
            trailing: CsBadge(
              appointment.status.localizedLabel,
              tone: switch (appointment.status) {
                AppointmentStatus.confirmed => CsTone.success,
                AppointmentStatus.pending => CsTone.warning,
                AppointmentStatus.rejected ||
                AppointmentStatus.cancelled ||
                AppointmentStatus.noShow => CsTone.accent,
                AppointmentStatus.unknown => CsTone.neutral,
              },
            ),
          ),
      ],
    );
  }
}

String _two(int value) => value.toString().padLeft(2, '0');

String _monthDay(DateTime value) => '${_two(value.month)}/${_two(value.day)}';

String _time(DateTime value) => '${_two(value.hour)}:${_two(value.minute)}';

String _formatDate(DateTime value) => '${value.year}.${_two(value.month)}.${_two(value.day)}';

class _FactRow extends StatelessWidget {
  const _FactRow({required this.label, required this.value, this.mono = false});

  final String label;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label, style: TextStyle(fontSize: 14, color: theme.mutedText)),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: mono && value != '—'
                  ? csMono(fontSize: 13, color: theme.ink)
                  : TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.ink),
            ),
          ),
        ],
      ),
    );
  }
}
