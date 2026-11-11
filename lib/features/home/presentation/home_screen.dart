import 'package:carservice_customer/app/theme/app_theme.dart';
import 'package:carservice_customer/core/widgets/animations.dart';
import 'package:carservice_customer/core/widgets/cs_ui.dart';
import 'package:carservice_customer/features/booking/auth/domain/account.dart';
import 'package:carservice_customer/features/booking/auth/presentation/auth_controller.dart';
import 'package:carservice_customer/features/booking/domain/appointment_status.dart';
import 'package:carservice_customer/features/booking/domain/appointment.dart';
import 'package:carservice_customer/features/booking/domain/service_progress.dart';
import 'package:carservice_customer/features/booking/presentation/controllers/appointments_controller.dart';
import 'package:carservice_customer/features/discovery/domain/branch.dart';
import 'package:carservice_customer/features/discovery/domain/organization.dart';
import 'package:carservice_customer/features/discovery/presentation/controllers/discovery_controller.dart';
import 'package:carservice_customer/features/notifications/presentation/controllers/notifications_controller.dart';
import 'package:carservice_customer/features/vehicles/domain/vehicle.dart';
import 'package:carservice_customer/features/vehicles/presentation/controllers/vehicles_controller.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Tab 0, "Нүүр": greeting, the customer's car with its live repair status,
/// quick actions and nearby services. Built only from data the app already
/// has (account, vehicles, appointments, discovery) — the design's reminders
/// and mileage have no backend yet, so they are left out rather than faked.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    required this.onLoginRequested,
    required this.onNotificationsRequested,
    required this.onProfileRequested,
    required this.onBookRequested,
    required this.onSearchRequested,
    required this.onAppointmentsRequested,
    required this.onHistoryRequested,
    required this.onAddVehicle,
    required this.onAppointmentSelected,
    required this.onBranchSelected,
    super.key,
  });

  final VoidCallback onLoginRequested;
  final VoidCallback onNotificationsRequested;
  final VoidCallback onProfileRequested;
  final VoidCallback onBookRequested;
  final VoidCallback onSearchRequested;
  final VoidCallback onAppointmentsRequested;
  final VoidCallback onHistoryRequested;
  final VoidCallback onAddVehicle;
  final ValueChanged<String> onAppointmentSelected;
  final void Function(Organization organization, Branch branch) onBranchSelected;

  @override
  Widget build(BuildContext context) {
    final account = context.select<AuthController, Account?>((c) => c.account);
    final unread = context.select<NotificationsController, int>((c) => c.unreadCount);
    final vehicles = context.select<VehiclesController, List<Vehicle>>((c) => c.state.vehicles);
    final appointments = context.select<AppointmentsController, List<Appointment>>(
      (c) => c.sortedAppointments,
    );
    final organizations = context.select<DiscoveryController, List<Organization>>(
      (c) => c.state.organizations,
    );
    final nearby = [
      for (final org in organizations)
        if (org.branches.isNotEmpty) (org, org.branches.first),
    ].take(3).toList();
    final active = account == null ? null : _pickActive(appointments, DateTime.now());
    final bottom = CsFloatingNav.reservedHeight + MediaQuery.paddingOf(context).bottom;

    return ListView(
      key: const PageStorageKey('home'),
      padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 16, 20, bottom),
      children: [
        _Header(
          account: account,
          unread: unread,
          onNotifications: account == null ? null : onNotificationsRequested,
          onProfile: account == null ? onLoginRequested : onProfileRequested,
          // Guests still reach settings (theme, legal pages) via Профайл,
          // which shows its signed-out view.
          onSettings: account == null ? onProfileRequested : null,
        ),
        const SizedBox(height: 18),
        RiseIn(
          child: account == null
              ? _GuestHero(onLogin: onLoginRequested)
              : _CarHero(
                  vehicle: vehicles.isEmpty ? null : vehicles.first,
                  active: active,
                  onAddVehicle: onAddVehicle,
                  onActiveTap: active == null ? null : () => onAppointmentSelected(active.id),
                ),
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _QuickAction(
              key: const ValueKey('home-book'),
              icon: Icons.event_available_outlined,
              label: 'Цаг захиалах',
              accent: true,
              onTap: onBookRequested,
            ),
            _QuickAction(
              icon: Icons.travel_explore_outlined,
              label: 'Сервис хайх',
              onTap: onSearchRequested,
            ),
            _QuickAction(
              icon: Icons.event_note_outlined,
              label: 'Захиалгууд',
              onTap: onAppointmentsRequested,
            ),
            _QuickAction(
              icon: Icons.receipt_long_outlined,
              label: 'Түүх',
              onTap: account == null ? onLoginRequested : onHistoryRequested,
            ),
          ],
        ),
        const SizedBox(height: 22),
        CsSectionHeader('Ойролцоох сервис', actionLabel: 'Бүгд', onAction: onSearchRequested),
        const SizedBox(height: 10),
        if (nearby.isEmpty)
          CsCard(
            onTap: onSearchRequested,
            child: Row(
              children: [
                const CsIconTile(icon: Icons.map_outlined, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Газрын зургаас ойролцоох сервисээ олоорой',
                    style: TextStyle(fontSize: 14, color: CarserviceTheme.of(context).mutedText),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          )
        else
          for (final (org, branch) in nearby) ...[
            _ServiceRow(
              organization: org,
              branch: branch,
              onTap: () => onBranchSelected(org, branch),
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

/// The appointment worth surfacing on the hero card: a repair in progress
/// first, otherwise the next upcoming active booking.
Appointment? _pickActive(List<Appointment> appointments, DateTime now) {
  for (final a in appointments) {
    final progress = a.serviceProgress;
    if (progress != null &&
        (progress.status == ServiceProgressStatus.inProgress ||
            progress.status == ServiceProgressStatus.scheduled ||
            progress.status == ServiceProgressStatus.pending ||
            progress.status == ServiceProgressStatus.postponed)) {
      return a;
    }
  }
  final upcoming = appointments
      .where((a) => a.status.isActive && a.requestedAt.isAfter(now.subtract(const Duration(hours: 3))))
      .toList()
    ..sort((a, b) => a.requestedAt.compareTo(b.requestedAt));
  return upcoming.isEmpty ? null : upcoming.first;
}

const _weekdays = ['Да', 'Мя', 'Лх', 'Пү', 'Ба', 'Бя', 'Ня'];

String _slotLabel(DateTime at) {
  final local = at.toLocal();
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return '${local.month}/${local.day} ${_weekdays[local.weekday - 1]} · $hh:$mm';
}

class _Header extends StatelessWidget {
  const _Header({
    required this.account,
    required this.unread,
    required this.onNotifications,
    required this.onProfile,
    this.onSettings,
  });

  final Account? account;
  final int unread;
  final VoidCallback? onNotifications;
  final VoidCallback onProfile;
  final VoidCallback? onSettings;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    final name = account?.name?.trim();
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Сайн уу,', style: TextStyle(fontSize: 13, color: theme.mutedText)),
              Text(
                (name != null && name.isNotEmpty) ? name : (account == null ? 'Зочин' : account!.phone),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.2),
              ),
            ],
          ),
        ),
        if (onNotifications != null) ...[
          CsCircleButton(
            key: const ValueKey('shell-notifications'),
            icon: Icons.notifications_none_rounded,
            tooltip: 'Мэдэгдэл',
            badge: unread > 0,
            onPressed: onNotifications,
          ),
          const SizedBox(width: 8),
        ],
        if (onSettings != null) ...[
          CsCircleButton(
            key: const ValueKey('shell-settings'),
            icon: Icons.settings_outlined,
            tooltip: 'Тохиргоо',
            onPressed: onSettings,
          ),
          const SizedBox(width: 8),
        ],
        CsCircleButton(
          key: ValueKey(account == null ? 'shell-login' : 'shell-avatar'),
          icon: account == null ? Icons.login_rounded : Icons.person_outline_rounded,
          tooltip: account == null ? 'Нэвтрэх' : 'Профайл',
          onPressed: onProfile,
        ),
      ],
    );
  }
}

class _GuestHero extends StatelessWidget {
  const _GuestHero({required this.onLogin});
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    return CsHeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CsSectionLabel('Carservice', color: theme.onHeroMuted),
          const SizedBox(height: 8),
          const Text(
            'Машиныхаа засварыг утаснаасаа хянаарай',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, height: 1.25),
          ),
          const SizedBox(height: 6),
          Text(
            'Нэвтэрч машинаа нэмбэл захиалга, засварын явцаа нэг дороос харна.',
            style: TextStyle(fontSize: 13, color: theme.onHeroMuted, height: 1.4),
          ),
          const SizedBox(height: 14),
          FilledButton(onPressed: onLogin, child: const Text('Нэвтрэх')),
        ],
      ),
    );
  }
}

class _CarHero extends StatelessWidget {
  const _CarHero({
    required this.vehicle,
    required this.active,
    required this.onAddVehicle,
    required this.onActiveTap,
  });

  final Vehicle? vehicle;
  final Appointment? active;
  final VoidCallback onAddVehicle;
  final VoidCallback? onActiveTap;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    final vehicle = this.vehicle;
    return CsHeroCard(
      child: Stack(
        children: [
          Positioned(
            right: -14,
            top: 0,
            child: Icon(Icons.directions_car_filled_rounded, size: 96, color: theme.onHero.withValues(alpha: 0.1)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CsSectionLabel('Миний машин', color: theme.onHeroMuted),
              const SizedBox(height: 10),
              if (vehicle == null) ...[
                const Text('Машинаа нэмээрэй', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  'Захиалга хийхэд мэдээлэл автоматаар бөглөгдөнө.',
                  style: TextStyle(fontSize: 13, color: theme.onHeroMuted),
                ),
                const SizedBox(height: 14),
                _HeroAction(
                  icon: Icons.add_rounded,
                  title: 'Машин нэмэх',
                  subtitle: 'Улсын дугаараар хайж бөглөнө',
                  onTap: onAddVehicle,
                ),
              ] else ...[
                Text(
                  [vehicle.make, vehicle.model].where((s) => s.trim().isNotEmpty).join(' '),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                CsPlate(vehicle.plate, onHero: true),
                const SizedBox(height: 14),
                if (active != null)
                  _ActiveStatus(appointment: active!, onTap: onActiveTap)
                else
                  Text(
                    vehicle.serviceCount > 0
                        ? '${vehicle.serviceCount} удаа засвар хийлгэсэн'
                        : 'Идэвхтэй засвар алга',
                    style: TextStyle(fontSize: 13, color: theme.onHeroMuted),
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ActiveStatus extends StatelessWidget {
  const _ActiveStatus({required this.appointment, required this.onTap});

  final Appointment appointment;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final progress = appointment.serviceProgress;
    final String title;
    if (progress != null) {
      final total = progress.items.length;
      final done = progress.items.where((i) => i.status.isCompleted).length;
      title = total == 0
          ? progress.status.localizedLabel
          : '${progress.status.localizedLabel} · $done/$total';
    } else {
      title = '${appointment.status.localizedLabel} · ${_slotLabel(appointment.requestedAt)}';
    }
    final subtitle = [
      appointment.tenantName.toUpperCase(),
      if (appointment.categoryNames.isNotEmpty) appointment.categoryNames.join(', '),
    ].join(' · ');
    return _HeroAction(
      key: const ValueKey('home-active'),
      live: true,
      title: title,
      subtitle: subtitle,
      onTap: onTap,
    );
  }
}

/// The light inset row on the hero card (status / add-car).
class _HeroAction extends StatelessWidget {
  const _HeroAction({
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.icon,
    this.live = false,
    super.key,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool live;

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF2C3E50);
    return Material(
      color: const Color(0xFFECF0F1),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              if (live)
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: const Color(0xFFFBEAE8), spreadRadius: 4)],
                  ),
                )
              else if (icon != null)
                Icon(icon, size: 20, color: AppColors.accentLightText),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ink)),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF5F6B6D)),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 20, color: ink),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.accent = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: theme.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.cardBorder),
                ),
                child: Icon(icon, size: 22, color: accent ? theme.link : theme.ink),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: theme.ink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({required this.organization, required this.branch, required this.onTap});

  final Organization organization;
  final Branch branch;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    final subtitle = [
      ?branch.distanceLabel,
      if (branch.locationLabel.trim().isNotEmpty) branch.locationLabel,
    ].join(' · ');
    return CsCard(
      key: ValueKey('home-branch-${organization.slug}-${branch.id}'),
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Row(
        children: [
          CsMonogram(name: organization.name, imageUrl: organization.logoUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  organization.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle.isEmpty ? branch.name : subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: theme.mutedText),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: theme.mutedText),
        ],
      ),
    );
  }
}
