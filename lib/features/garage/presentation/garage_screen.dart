import 'package:carservice_customer/app/theme/app_theme.dart';
import 'package:carservice_customer/core/widgets/cs_ui.dart';
import 'package:carservice_customer/features/booking/auth/domain/account.dart';
import 'package:carservice_customer/features/booking/auth/presentation/auth_controller.dart';
import 'package:carservice_customer/features/history/domain/service_order.dart';
import 'package:carservice_customer/features/history/domain/service_order_status.dart';
import 'package:carservice_customer/features/history/presentation/controllers/history_controller.dart';
import 'package:carservice_customer/features/history/presentation/format_amount.dart';
import 'package:carservice_customer/features/vehicles/domain/vehicle.dart';
import 'package:carservice_customer/features/vehicles/presentation/controllers/vehicles_controller.dart';
import 'package:carservice_customer/features/vehicles/presentation/controllers/vehicles_state.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Tab 3, "Машин": the customer's cars as a swipeable card row, their real
/// counters (services, diagnostics) and the latest repair history. Mileage
/// and reminders from the design have no backend yet and are omitted.
class GarageScreen extends StatefulWidget {
  const GarageScreen({
    required this.onLoginRequested,
    required this.onAddVehicle,
    required this.onVehicleSelected,
    required this.onHistoryRequested,
    required this.onOrderSelected,
    required this.onProfileRequested,
    super.key,
  });

  final VoidCallback onLoginRequested;
  final VoidCallback onAddVehicle;
  final ValueChanged<Vehicle> onVehicleSelected;
  final VoidCallback onHistoryRequested;
  final ValueChanged<String> onOrderSelected;
  final VoidCallback onProfileRequested;

  @override
  State<GarageScreen> createState() => _GarageScreenState();
}

class _GarageScreenState extends State<GarageScreen> {
  final _pager = PageController(viewportFraction: 0.86);
  int _page = 0;

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    final account = context.select<AuthController, Account?>((c) => c.account);
    final vehiclesState = context.select<VehiclesController, VehiclesState>((c) => c.state);
    final orders = context.select<HistoryController, List<ServiceOrder>>((c) => c.state.orders);
    final top = MediaQuery.paddingOf(context).top + 16;
    final bottom = CsFloatingNav.reservedHeight + MediaQuery.paddingOf(context).bottom;

    final header = Row(
      children: [
        const Expanded(
          child: Text(
            'Миний машин',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.2),
          ),
        ),
        if (account != null) ...[
          OutlinedButton.icon(
            key: const ValueKey('garage-add'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: const StadiumBorder(),
              textStyle: const TextStyle(fontFamily: AppFonts.sans, fontSize: 13, fontWeight: FontWeight.w500),
            ),
            onPressed: widget.onAddVehicle,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Нэмэх'),
          ),
          const SizedBox(width: 8),
        ],
        CsCircleButton(
          key: ValueKey(account == null ? 'garage-login' : 'garage-profile'),
          icon: account == null ? Icons.login_rounded : Icons.person_outline_rounded,
          tooltip: account == null ? 'Нэвтрэх' : 'Профайл',
          onPressed: account == null ? widget.onLoginRequested : widget.onProfileRequested,
        ),
      ],
    );

    if (account == null) {
      return ListView(
        padding: EdgeInsets.fromLTRB(20, top, 20, bottom),
        children: [
          header,
          const SizedBox(height: 18),
          CsHeroCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Машин, засварын түүхээ нэг дор', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(
                  'Нэвтэрснээр машинаа нэмж, засварын түүхээ хадгална.',
                  style: TextStyle(fontSize: 13, color: theme.onHeroMuted),
                ),
                const SizedBox(height: 14),
                FilledButton(onPressed: widget.onLoginRequested, child: const Text('Нэвтрэх')),
              ],
            ),
          ),
        ],
      );
    }

    final vehicles = vehiclesState.vehicles;
    final current = vehicles.isEmpty ? null : vehicles[_page.clamp(0, vehicles.length - 1)];
    final plate = current?.plate.replaceAll(' ', '').toUpperCase();
    final carOrders = plate == null
        ? orders
        : orders.where((o) => o.vehiclePlate?.replaceAll(' ', '').toUpperCase() == plate).toList();

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          context.read<VehiclesController>().load(),
          context.read<HistoryController>().load(),
        ]);
      },
      child: ListView(
        padding: EdgeInsets.fromLTRB(0, top, 0, bottom),
        children: [
          Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: header),
          const SizedBox(height: 14),
          if (vehicles.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _EmptyCar(onAdd: widget.onAddVehicle),
            )
          else
            SizedBox(
              height: 168,
              child: PageView.builder(
                controller: _pager,
                padEnds: false,
                itemCount: vehicles.length + 1,
                onPageChanged: (i) => setState(() => _page = i.clamp(0, vehicles.length - 1)),
                itemBuilder: (context, i) => Padding(
                  padding: EdgeInsets.only(left: i == 0 ? 20 : 5, right: 5),
                  child: i == vehicles.length
                      ? _AddTile(onTap: widget.onAddVehicle)
                      : _CarCard(vehicle: vehicles[i], onTap: () => widget.onVehicleSelected(vehicles[i])),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (current != null) ...[
                  Row(
                    children: [
                      _Stat(label: 'Засвар', value: '${current.serviceCount}'),
                      const SizedBox(width: 8),
                      _Stat(label: 'Оношилгоо', value: '${current.diagnosisCount}'),
                    ],
                  ),
                  const SizedBox(height: 18),
                ],
                CsSectionLabel(
                  'Засварын түүх',
                  trailing: TextButton(
                    onPressed: widget.onHistoryRequested,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      textStyle: const TextStyle(fontFamily: AppFonts.sans, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    child: const Text('Бүгд'),
                  ),
                ),
                const SizedBox(height: 6),
                if (carOrders.isEmpty)
                  CsCard(
                    child: Text(
                      'Засварын түүх одоогоор алга.',
                      style: TextStyle(fontSize: 14, color: theme.mutedText),
                    ),
                  )
                else
                  CsCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (var i = 0; i < carOrders.length && i < 4; i++) ...[
                          if (i > 0) Divider(height: 1, color: theme.shellBackground),
                          _HistoryRow(order: carOrders[i], onTap: () => widget.onOrderSelected(carOrders[i].id)),
                        ],
                      ],
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

class _CarCard extends StatelessWidget {
  const _CarCard({required this.vehicle, required this.onTap});

  final Vehicle vehicle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    final meta = [
      if (vehicle.year != null) '${vehicle.year}',
      ?vehicle.fuelType,
      ?vehicle.colorName,
    ].where((s) => s.trim().isNotEmpty).join(' · ');
    return CsHeroCard(
      key: ValueKey('garage-vehicle-${vehicle.id}'),
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Stack(
        children: [
          Positioned(
            right: -10,
            bottom: -18,
            child: Icon(Icons.directions_car_filled_rounded, size: 110, color: theme.onHero.withValues(alpha: 0.12)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          [vehicle.make, vehicle.model].where((s) => s.trim().isNotEmpty).join(' '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
                        ),
                        if (meta.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(meta, style: TextStyle(fontSize: 13, color: theme.onHeroMuted)),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  CsPlate(vehicle.plate, onHero: true),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  Text('Дэлгэрэнгүй', style: TextStyle(fontSize: 13, color: theme.onHeroMuted)),
                  Icon(Icons.chevron_right_rounded, size: 18, color: theme.onHeroMuted),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        width: 64,
        child: Material(
          color: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.hero),
            side: BorderSide(color: theme.mutedText.withValues(alpha: 0.6), width: 1.5),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadii.hero),
            onTap: onTap,
            child: Center(child: Icon(Icons.add_rounded, color: theme.mutedText, semanticLabel: 'Машин нэмэх')),
          ),
        ),
      ),
    );
  }
}

class _EmptyCar extends StatelessWidget {
  const _EmptyCar({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    return CsCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CsIconTile(icon: Icons.directions_car_outlined),
              const SizedBox(width: 10),
              const Text('Машин бүртгэгдээгүй', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Машинаа нэмбэл захиалга хийхэд мэдээлэл автоматаар бөглөгдөнө.',
            style: TextStyle(fontSize: 14, color: theme.mutedText),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(onPressed: onAdd, icon: const Icon(Icons.add_rounded), label: const Text('Машин нэмэх')),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    return Expanded(
      child: CsCard(
        padding: const EdgeInsets.all(12),
        radius: 14,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: theme.mutedText)),
            const SizedBox(height: 2),
            Text(value, style: csMono(fontSize: 15, color: theme.ink)),
          ],
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.order, required this.onTap});
  final ServiceOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    final d = order.completedAt.toLocal();
    final tone = switch (order.status) {
      ServiceOrderStatus.paid => CsTone.success,
      ServiceOrderStatus.partiallyPaid => CsTone.warning,
      ServiceOrderStatus.unpaid => CsTone.accent,
    };
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              child: Text(
                '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}',
                textAlign: TextAlign.center,
                style: csMono(fontSize: 12, color: theme.mutedText),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.tenantName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${formatAmount(order.totalAmount)}₮',
                    style: csMono(fontSize: 12, color: theme.mutedText),
                  ),
                ],
              ),
            ),
            if (order.isCancelled)
              const CsBadge('Цуцлагдсан')
            else
              CsBadge(order.status.localizedLabel, tone: tone),
          ],
        ),
      ),
    );
  }
}
