import 'package:carservice_customer/app/theme/app_theme.dart';
import 'package:carservice_customer/core/widgets/cs_ui.dart';
import 'package:carservice_customer/features/booking/auth/domain/account.dart';
import 'package:carservice_customer/features/booking/auth/presentation/auth_controller.dart';
import 'package:carservice_customer/features/booking/domain/appointment_status.dart';
import 'package:carservice_customer/features/booking/presentation/controllers/appointments_controller.dart';
import 'package:carservice_customer/features/discovery/presentation/controllers/discovery_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

/// The four top-level tabs of the 2026-11 design: Нүүр · Сервис · Захиалга ·
/// Машин. Profile and full history are pushed routes reached from Home /
/// Garage, and booking starts from Home's "Цаг захиалах".
class CustomerShell extends StatefulWidget {
  const CustomerShell({required this.destinations, super.key})
    : assert(destinations.length == 4);

  /// Home, Discovery, Appointments, Garage — in that order.
  final List<Widget> destinations;

  @override
  State<CustomerShell> createState() => CustomerShellState();
}

class CustomerShellState extends State<CustomerShell> with SingleTickerProviderStateMixin {
  static const homeIndex = 0;
  static const discoveryIndex = 1;
  static const appointmentsIndex = 2;
  static const garageIndex = 3;

  int _selectedIndex = homeIndex;

  // A quick scale-in on tab change; transform-only (no opacity) so blurred
  // surfaces underneath keep compositing.
  late final AnimationController _tabAnim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    value: 1,
  );
  late final Animation<double> _tabScale = Tween<double>(
    begin: 0.985,
    end: 1,
  ).animate(CurvedAnimation(parent: _tabAnim, curve: Curves.easeOut));

  @override
  void dispose() {
    _tabAnim.dispose();
    super.dispose();
  }

  static const _items = [
    (Icons.home_outlined, Icons.home_rounded, 'Нүүр'),
    (Icons.search_rounded, Icons.search_rounded, 'Сервис'),
    (Icons.receipt_long_outlined, Icons.receipt_long_rounded, 'Захиалга'),
    (Icons.directions_car_outlined, Icons.directions_car_rounded, 'Машин'),
  ];

  @override
  Widget build(BuildContext context) {
    final account = context.select<AuthController, Account?>((c) => c.account);
    final hasActiveBooking =
        account != null &&
        context.select<AppointmentsController, bool>(
          (c) => c.sortedAppointments.any((a) => a.status.isActive),
        );
    final discoveryMapView = context.select<DiscoveryController, bool>((c) => c.mapView);
    final theme = CarserviceTheme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= 720;
        final mq = MediaQuery.of(context);
        final navSpace = useRail ? 0.0 : CsFloatingNav.reservedHeight + mq.padding.bottom;

        Widget tab(int i, Widget child) {
          switch (i) {
            case homeIndex:
            case garageIndex:
              // These screens lay out their own insets and nav clearance.
              return child;
            case discoveryIndex:
              return Padding(
                padding: EdgeInsets.only(bottom: navSpace),
                child: discoveryMapView ? child : SafeArea(bottom: false, child: child),
              );
            default:
              return Padding(
                padding: EdgeInsets.only(bottom: navSpace),
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
                        child: Text(
                          'Захиалгууд',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.2),
                        ),
                      ),
                      Expanded(child: child),
                    ],
                  ),
                ),
              );
          }
        }

        final content = ScaleTransition(
          scale: _tabScale,
          child: IndexedStack(
            index: _selectedIndex,
            children: [
              for (var i = 0; i < widget.destinations.length; i++) tab(i, widget.destinations[i]),
            ],
          ),
        );

        if (useRail) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: _selectDestination,
                  labelType: NavigationRailLabelType.all,
                  backgroundColor: theme.card,
                  indicatorColor: theme.inverse,
                  selectedIconTheme: IconThemeData(color: theme.onInverse),
                  destinations: [
                    for (var i = 0; i < _items.length; i++)
                      NavigationRailDestination(
                        // Same keys as the phone nav, so flows find a tab
                        // regardless of the layout width.
                        icon: KeyedSubtree(key: ValueKey('shell-tab-$i'), child: Icon(_items[i].$1)),
                        selectedIcon: KeyedSubtree(key: ValueKey('shell-tab-$i'), child: Icon(_items[i].$2)),
                        label: Text(_items[i].$3),
                      ),
                  ],
                ),
                VerticalDivider(width: 1, color: theme.cardBorder),
                Expanded(child: content),
              ],
            ),
          );
        }

        return Scaffold(
          body: Stack(
            children: [
              Positioned.fill(child: content),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: CsFloatingNav(
                  key: const ValueKey('shell-nav'),
                  selectedIndex: _selectedIndex,
                  onSelected: _selectDestination,
                  items: [
                    for (var i = 0; i < _items.length; i++)
                      CsNavItem(
                        key: ValueKey('shell-tab-$i'),
                        icon: i == _selectedIndex ? _items[i].$2 : _items[i].$1,
                        label: _items[i].$3,
                        badge: i == appointmentsIndex && hasActiveBooking && _selectedIndex != i,
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _selectDestination(int index) {
    if (_selectedIndex == index) return;
    HapticFeedback.selectionClick();
    setState(() => _selectedIndex = index);
    if (!(MediaQuery.maybeOf(context)?.disableAnimations ?? false)) {
      _tabAnim.forward(from: 0);
    }
  }

  /// Lets the router imperatively switch tabs, e.g. jumping to Appointments
  /// right after a booking succeeds.
  void selectDestination(int index) => _selectDestination(index);

  int get selectedIndex => _selectedIndex;
}
