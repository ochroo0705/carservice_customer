import 'package:carservice_customer/app/theme/app_theme.dart';
import 'package:carservice_customer/core/widgets/cs_ui.dart';
import 'package:carservice_customer/features/history/domain/service_order_status.dart';
import 'package:carservice_customer/core/widgets/skeletons.dart';
import 'package:carservice_customer/core/errors/app_failure.dart';
import 'package:carservice_customer/features/history/domain/service_history_repository.dart';
import 'package:carservice_customer/features/history/domain/service_order_detail.dart';
import 'package:carservice_customer/features/history/domain/service_order_item.dart';
import 'package:carservice_customer/features/history/presentation/controllers/history_controller.dart';
import 'package:carservice_customer/features/history/presentation/format_amount.dart';
import 'package:carservice_customer/features/history/presentation/widgets/diagnostic_report_row.dart';
import 'package:carservice_customer/features/history/presentation/widgets/order_intake_tile.dart';
import 'package:flutter/material.dart';

enum _DetailStatus { loading, data, error }

class ServiceOrderDetailScreen extends StatefulWidget {
  const ServiceOrderDetailScreen({
    required this.repository,
    required this.orderId,
    required this.onBack,
    required this.historyController,
    this.onReportSelected,
    super.key,
  });

  final ServiceHistoryRepository repository;
  final String orderId;
  final VoidCallback onBack;
  // Энэ дэлгэц HistoryController-оос дата авахгүй, өөрөө нэг удаа шууд
  // repository-с татдаг тул push мэдэгдлээр (жишээ нь захиалга дуусахад)
  // жагсаалт дахин ачаалагдахад энэ дэлгэц НЭЭЛТТЭЙ байсан ч шинэчлэгдэхгүй
  // байсан — тиймээс энд controller-ийг сонсож дэвсгэр дээр (skeleton
  // харуулахгүйгээр) чимээгүй дахин татна.
  final HistoryController historyController;

  /// Хавсаргасан оношилгооны тайлангийн товч мөрөнд дарахад дуудагдана —
  /// `null` бол мөр дарах боломжгүй хэвээр үлдэнэ.
  final ValueChanged<String>? onReportSelected;

  @override
  State<ServiceOrderDetailScreen> createState() => _ServiceOrderDetailScreenState();
}

class _ServiceOrderDetailScreenState extends State<ServiceOrderDetailScreen> {
  _DetailStatus _status = _DetailStatus.loading;
  ServiceOrderDetail? _detail;
  String? _message;

  @override
  void initState() {
    super.initState();
    widget.historyController.addListener(_handleHistoryChanged);
    _load();
  }

  @override
  void dispose() {
    widget.historyController.removeListener(_handleHistoryChanged);
    super.dispose();
  }

  void _handleHistoryChanged() {
    // Loading skeleton рүү буцахгүй — History дахин ачаалагдах шалтгаан
    // (login, connectivity, push мэдэгдэл) бүр ямар нэгэн харилцан хамааралгүй
    // байж болно; одоо байгаа мэдээллийг харуулсаар, зөвхөн амжилттай ирвэл
    // солино.
    _refreshSilently();
  }

  Future<void> _load() async {
    setState(() => _status = _DetailStatus.loading);
    try {
      final detail = await widget.repository.getServiceOrderDetail(widget.orderId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _status = _DetailStatus.data;
      });
    } on AppFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _message = failure.message;
        _status = _DetailStatus.error;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _message = 'Тодорхойгүй алдаа гарлаа.';
        _status = _DetailStatus.error;
      });
    }
  }

  Future<void> _refreshSilently() async {
    try {
      final detail = await widget.repository.getServiceOrderDetail(widget.orderId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _status = _DetailStatus.data;
      });
    } catch (_) {
      // Дэвсгэр дээрх чимээгүй шинэчлэлт — амжилтгүй бол одоо харуулж буй
      // мэдээллийг алдаа/skeleton-оор орлуулахгүй, зүгээр алгасна.
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
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
                  CsCircleButton.back(context, onPressed: widget.onBack),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Захиалгын дэлгэрэнгүй',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: theme.ink),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() => switch (_status) {
    _DetailStatus.loading => const SkeletonDetail(),
    _DetailStatus.error => Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 52, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text(
              _message ?? 'Тодорхойгүй алдаа гарлаа.',
              textAlign: TextAlign.center,
              style: TextStyle(color: CarserviceTheme.of(context).ink),
            ),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: _load, child: const Text('Дахин оролдох')),
          ],
        ),
      ),
    ),
    _DetailStatus.data => _DetailBody(detail: _detail!, onReportSelected: widget.onReportSelected),
  };
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.detail, this.onReportSelected});

  final ServiceOrderDetail detail;
  final ValueChanged<String>? onReportSelected;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    final order = detail.order;
    final date = order.completedAt;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        CsCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      order.tenantName,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                        color: theme.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  order.isCancelled
                      ? const CsBadge('Цуцлагдсан', tone: CsTone.accent)
                      : CsBadge(
                          order.status.localizedLabel,
                          tone: switch (order.status) {
                            ServiceOrderStatus.paid => CsTone.success,
                            ServiceOrderStatus.partiallyPaid => CsTone.info,
                            ServiceOrderStatus.unpaid => CsTone.accent,
                          },
                        ),
                ],
              ),
              const SizedBox(height: 4),
              Text(order.branchName, style: TextStyle(fontSize: 13, color: theme.mutedText)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}',
                    style: csMono(fontSize: 13, color: theme.mutedText),
                  ),
                  if (order.vehiclePlate != null)
                    Semantics(
                      label: 'Тээврийн хэрэгсэл: ${order.vehiclePlate}',
                      excludeSemantics: true,
                      child: CsPlate(order.vehiclePlate!, fontSize: 12),
                    ),
                ],
              ),
              if (detail.note != null && detail.note!.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(detail.note!, style: TextStyle(fontSize: 13, color: theme.ink, height: 1.4)),
              ],
            ],
          ),
        ),
        if (detail.intake != null) ...[
          const SizedBox(height: 16),
          OrderIntakeTile(orderId: order.id, intake: detail.intake!),
        ],
        const SizedBox(height: 22),
        const CsSectionHeader('Дэлгэрэнгүй'),
        const SizedBox(height: 8),
        CsCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < detail.items.length; i++) ...[
                if (i > 0) Divider(height: 1, thickness: 1, color: theme.shellBackground),
                _ItemRow(item: detail.items[i]),
              ],
              if (detail.items.isNotEmpty)
                Divider(height: 1, thickness: 1, color: theme.cardBorder),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  children: [
                    _TotalsRow(label: 'Нийт дүн', value: order.totalAmount, emphasized: true),
                    const SizedBox(height: 6),
                    _TotalsRow(label: 'Төлсөн', value: order.paidAmount),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (detail.reports.isNotEmpty) ...[
          const SizedBox(height: 22),
          const CsSectionHeader('Оношилгооны тайлан'),
          const SizedBox(height: 8),
          CsCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Column(
              children: [
                for (final report in detail.reports)
                  DiagnosticReportRow(
                    report: report,
                    onTap: onReportSelected == null ? null : () => onReportSelected!(report.id),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});

  final ServiceOrderItem item;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.kind.localizedLabel} · ${item.quantity} ширхэг',
                  style: TextStyle(fontSize: 12, color: theme.mutedText),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text('${formatAmount(item.totalPrice)}₮', style: csMono(fontSize: 13, color: theme.ink)),
        ],
      ),
    );
  }
}

class _TotalsRow extends StatelessWidget {
  const _TotalsRow({required this.label, required this.value, this.emphasized = false});

  final String label;
  final int value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: emphasized ? theme.ink : theme.mutedText,
            fontWeight: emphasized ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        Text(
          '${formatAmount(value)}₮',
          style: csMono(
            fontSize: emphasized ? 16 : 13,
            fontWeight: FontWeight.w500,
            color: theme.ink,
          ),
        ),
      ],
    );
  }
}
