import 'package:carservice_customer/features/history/presentation/widgets/order_intake_tile.dart';
import 'package:carservice_customer/features/history/domain/service_history_repository.dart';
import 'package:carservice_customer/app/theme/app_surfaces.dart';
import 'package:carservice_customer/app/theme/app_theme.dart';
import 'package:carservice_customer/core/widgets/cs_ui.dart';
import 'package:carservice_customer/core/widgets/skeletons.dart';
import 'package:carservice_customer/features/booking/domain/walk_in_order.dart';
import 'package:carservice_customer/features/booking/presentation/controllers/appointments_controller.dart';
import 'package:carservice_customer/features/booking/presentation/controllers/appointments_state.dart';
import 'package:carservice_customer/features/booking/presentation/widgets/service_progress_section.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Захиалгагүй (walk-in, appointment-гүй) захиалгын дэлгэрэнгүй.
/// `AppointmentDetailScreen`-тэй адил зарчим — `AppointmentsController`-ийн
/// аль хэдийн ачаалсан жагсаалтаас id-аар олно, тусад нь дахин татахгүй
/// (list payload дотор бүх дэлгэрэнгүй — үнэ, ажлын жагсаалт — аль хэдийн
/// иржээ). Цуцлах/төлбөр/шилжүүлэх гэсэн ойлголт байхгүй тул
/// `AppointmentDetailScreen`-ээс хамаагүй хялбар.
class WalkInOrderDetailScreen extends StatelessWidget {
  const WalkInOrderDetailScreen({
    required this.orderId,
    required this.onBack,
    this.onReportSelected,
    this.historyRepository,
    super.key,
  });

  final String orderId;
  final VoidCallback onBack;
  final ValueChanged<String>? onReportSelected;
  // «Хүлээн авах» бүртгэлийг дарахад татахад ашиглана; null бол tile нуугдана.
  final ServiceHistoryRepository? historyRepository;

  WalkInOrder? _find(AppointmentsController controller) {
    for (final order in controller.state.walkInOrders) {
      if (order.progress.id == orderId) return order;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppointmentsController>();
    final order = _find(controller);
    final isLoading =
        controller.state.status == AppointmentsStatus.loading ||
        controller.state.status == AppointmentsStatus.initial;

    return Scaffold(
      body: AppShellBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(
                subtitle: order == null ? null : _vehicleCaption(order),
                onBack: onBack,
              ),
              Expanded(
                child: switch ((order, isLoading)) {
                  (final WalkInOrder order, _) => _WalkInOrderDetailBody(
                    order: order,
                    onRefresh: controller.load,
                    onReportSelected: onReportSelected,
                    historyRepository: historyRepository,
                  ),
                  (null, true) => const SkeletonDetail(),
                  (null, false) => _NotFound(onBack: onBack),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Prius 30 · 1234 УБА" under the page title.
String? _vehicleCaption(WalkInOrder order) {
  final p = order.progress;
  final model = [
    p.vehicleMake,
    p.vehicleModel,
  ].whereType<String>().where((s) => s.trim().isNotEmpty).join(' ');
  final parts = [
    model,
    p.vehiclePlate,
  ].whereType<String>().where((s) => s.trim().isNotEmpty).toList();
  return parts.isEmpty ? null : parts.join(' · ');
}

/// Design header: round back button + title + mono vehicle caption.
class _Header extends StatelessWidget {
  const _Header({required this.onBack, this.subtitle});

  final String? subtitle;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        children: [
          CsCircleButton.back(context, onPressed: onBack),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    'Захиалгын дэлгэрэнгүй',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: theme.ink,
                    ),
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: csMono(fontSize: 12, color: theme.mutedText),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WalkInOrderDetailBody extends StatelessWidget {
  const _WalkInOrderDetailBody({
    required this.order,
    required this.onRefresh,
    this.onReportSelected,
    this.historyRepository,
  });

  final WalkInOrder order;
  final Future<void> Function() onRefresh;
  final ValueChanged<String>? onReportSelected;
  final ServiceHistoryRepository? historyRepository;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          ServiceProgressHero(
            progress: order.progress,
            label: order.branchName,
          ),
          const SizedBox(height: 12),
          CsCard(
            child: Row(
              children: [
                CsMonogram(name: order.tenantName, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.tenantName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: theme.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        order.branchName,
                        style: TextStyle(fontSize: 13, color: theme.mutedText),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ServiceProgressSection(
            progress: order.progress,
            onReportSelected: onReportSelected,
          ),
          if (order.progress.hasIntake && historyRepository != null) ...[
            const SizedBox(height: 12),
            OrderIntakeTile(
              orderId: order.progress.id,
              repository: historyRepository,
            ),
          ],
        ],
      ),
    );
  }
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
          CsIconTile(
            icon: Icons.event_busy_outlined,
            size: 56,
            color: CarserviceTheme.of(context).mutedText,
            background: CarserviceTheme.of(context).card,
          ),
          const SizedBox(height: 16),
          Text(
            'Захиалга олдсонгүй',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
              color: CarserviceTheme.of(context).ink,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onBack, child: const Text('Буцах')),
        ],
      ),
    ),
  );
}
