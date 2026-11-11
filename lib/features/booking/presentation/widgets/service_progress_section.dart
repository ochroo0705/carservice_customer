import 'package:carservice_customer/app/theme/app_theme.dart';
import 'package:carservice_customer/core/widgets/cs_ui.dart';
import 'package:carservice_customer/features/booking/domain/service_progress.dart';
import 'package:carservice_customer/features/history/domain/service_order_item.dart'
    show ServiceOrderItemKind, ServiceOrderItemKindUi;
import 'package:carservice_customer/features/history/presentation/format_amount.dart';
import 'package:carservice_customer/features/history/presentation/widgets/diagnostic_report_row.dart';
import 'package:flutter/material.dart';

/// The navy "Засварын явц" status block (CustTrack design): place label,
/// status pill, the current activity, a segmented bar of the order's items and
/// the timing facts. Shown at the top of the appointment / walk-in detail.
class ServiceProgressHero extends StatelessWidget {
  const ServiceProgressHero({
    required this.progress,
    required this.label,
    super.key,
  });

  final AppointmentServiceProgress progress;

  /// Mono uppercase caption, e.g. "LEXUS SERVICE · БАЯНЗҮРХ".
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    return CsHeroCard(
      key: const ValueKey('appointment-progress-hero'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: csMono(
                    fontSize: 11,
                    letterSpacing: 0.66,
                    color: theme.onHeroMuted,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              HeroStatusPill(
                label: progress.status.localizedLabel,
                emphasized: progress.status == ServiceProgressStatus.inProgress,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _currentActivity(progress),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.22,
              height: 1.2,
              color: theme.onHero,
            ),
          ),
          const SizedBox(height: 12),
          _SegmentedProgress(progress: progress),
          ..._timingFacts(context, progress),
        ],
      ),
    );
  }
}

/// A status pill on the navy hero: solid accent while work is live,
/// otherwise a translucent light pill.
class HeroStatusPill extends StatelessWidget {
  const HeroStatusPill({
    required this.label,
    this.emphasized = false,
    super.key,
  });

  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    if (emphasized) return CsBadge(label, solid: true);
    final theme = CarserviceTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.onHero.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: theme.onHero,
          height: 1.2,
        ),
      ),
    );
  }
}

/// What the hero headline says: the labour item being worked on right now,
/// else a sentence for the order's status. Never an estimate.
String _currentActivity(AppointmentServiceProgress progress) {
  for (final item in progress.items) {
    if (item.status == ServiceProgressStatus.inProgress &&
        item.kind != ServiceOrderItemKind.part) {
      return item.name;
    }
  }
  return switch (progress.status) {
    ServiceProgressStatus.inProgress => 'Засвар хийгдэж байна',
    ServiceProgressStatus.pending => 'Засвар эхлэхийг хүлээж байна',
    ServiceProgressStatus.scheduled => 'Засварын цаг товлогдсон',
    ServiceProgressStatus.postponed => 'Засвар түр хойшлогдсон',
    ServiceProgressStatus.completed => 'Засвар дууссан',
    ServiceProgressStatus.cancelled => 'Захиалга цуцлагдсан',
    ServiceProgressStatus.unknown => progress.status.localizedLabel,
  };
}

class _SegmentedProgress extends StatelessWidget {
  const _SegmentedProgress({required this.progress});

  final AppointmentServiceProgress progress;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    final statuses = progress.items.isEmpty
        ? [progress.status]
        : [for (final item in progress.items) item.status];
    final done = statuses.where((s) => s.isCompleted).length;
    return Semantics(
      label: 'Явц: $done/${statuses.length}',
      excludeSemantics: true,
      child: Row(
        children: [
          for (var i = 0; i < statuses.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: Container(
                height: 5,
                decoration: BoxDecoration(
                  color: switch (statuses[i]) {
                    ServiceProgressStatus.completed => theme.onHero,
                    ServiceProgressStatus.inProgress => AppColors.accent,
                    _ => AppColors.darkBorder,
                  },
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Хугацааны БОДИТ баримтууд — item-completion хувиас тусад нь харуулна.
///
/// Урьдчилсан таамаг (`estimatedDurationMinutes`, `expectedFinishAt`) болон
/// тэдгээрээс гарах "хожимдож байна" анхааруулгыг зориудаар харуулахгүй:
/// үйлчлүүлэгчид улаанаар харагдах таамаг нь ажилтны хяналтаас гадуурх
/// шалтгаанаар байнга зөрдөг тул батлагдаагүй амлалт мэт сэтгэгдэл төрүүлж
/// байв. Оронд нь эхэлсэн/товлосон/буцах гэсэн баримтуудыг л харуулна (дизайны
/// "Бэлэн болох хугацаа ойролцоогоор" мөрийн байранд).
/// Талбарууд нь model/DTO-д хэвээр (API contract өөрчлөгдөөгүй).
List<Widget> _timingFacts(
  BuildContext context,
  AppointmentServiceProgress progress,
) {
  final theme = CarserviceTheme.of(context);
  final facts = <(String, String)>[
    // Хараахан эхлээгүй бол товлосон огноо, эхэлсэн бол бодит эхэлсэн цаг —
    // хоёулаа зэрэг утгатай байх тохиолдол байхгүй тул харилцан орлоно.
    if (progress.startedAt != null)
      ('Ажил эхэлсэн', _formatDateTime(progress.startedAt!))
    else if (progress.scheduledAt != null)
      ('Товлосон огноо', _formatDateTime(progress.scheduledAt!)),
    // Засвар үргэлжлэх цаг — хойшлогдсон үеийн хамгийн чухал мэдээлэл.
    if (progress.status == ServiceProgressStatus.postponed &&
        progress.scheduledReturnAt != null)
      ('Засвар үргэлжлэх цаг', _formatDateTime(progress.scheduledReturnAt!)),
  ];
  return [
    for (final (label, value) in facts) ...[
      const SizedBox(height: 10),
      Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '$label: '),
            TextSpan(
              text: value,
              style: TextStyle(
                color: theme.onHero,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        style: TextStyle(fontSize: 13, color: theme.onHeroMuted),
      ),
    ],
  ];
}

/// Customer-facing read-only view of the repair progress created from an
/// appointment: the item list with prices, totals, the status timeline and
/// diagnostic reports. Payment status stays in its own section on the detail
/// page; the status headline lives in [ServiceProgressHero].
class ServiceProgressSection extends StatelessWidget {
  const ServiceProgressSection({
    required this.progress,
    this.onReportSelected,
    super.key,
  });

  final AppointmentServiceProgress progress;
  // Ажил дуусахаас өмнө ч (жиш: захиалга гараад дараа нь оношилгоо хийгдвэл)
  // тайлан бэлэн болмогц энд харагдана — `service_order_detail_screen.dart`-
  // тай ижил зарчим, зөвхөн дууссан захиалгаар хязгаарлахгүй.
  final ValueChanged<String>? onReportSelected;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    final hasItems = progress.items.isNotEmpty;
    final completed = progress.completedItemCount;
    final vehicle = [
      progress.vehiclePlate,
      if (progress.vehicleMake != null || progress.vehicleModel != null)
        [
          progress.vehicleMake,
          progress.vehicleModel,
        ].whereType<String>().join(' '),
      if (progress.vehicleYear != null) '${progress.vehicleYear}',
    ].whereType<String>().where((s) => s.isNotEmpty).join(' · ');

    return Column(
      key: const ValueKey('appointment-progress'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CsCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Үйлчилгээний явц',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
              if (progress.number.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Засварын хуудас №${progress.number}',
                  style: csMono(fontSize: 12, color: theme.mutedText),
                ),
              ],
              if (progress.vehiclePlate != null && vehicle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  vehicle,
                  style: csMono(fontSize: 12, color: theme.mutedText),
                ),
              ],
              if (hasItems) ...[
                const SizedBox(height: 8),
                Text(
                  '$completed/${progress.items.length} үйлчилгээ дууссан',
                  style: TextStyle(fontSize: 13, color: theme.mutedText),
                ),
                const SizedBox(height: 12),
                Divider(height: 1, color: theme.cardBorder),
                const SizedBox(height: 4),
                for (final item in progress.items)
                  _ProgressItemRow(
                    key: ValueKey('appointment-progress-${item.id}'),
                    item: item,
                  ),
              ],
              if (progress.totalAmount != null) ...[
                const SizedBox(height: 10),
                _TotalsBlock(progress: progress),
              ],
            ],
          ),
        ),
        if (progress.statusHistory.isNotEmpty) ...[
          const SizedBox(height: 12),
          CsCard(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CsSectionLabel('Төлвийн түүх'),
                const SizedBox(height: 14),
                _StatusTimeline(entries: progress.statusHistory),
              ],
            ),
          ),
        ],
        if (progress.reports.isNotEmpty) ...[
          const SizedBox(height: 12),
          CsCard(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CsSectionLabel('Оношилгооны тайлан'),
                const SizedBox(height: 6),
                for (final report in progress.reports)
                  DiagnosticReportRow(
                    key: ValueKey('appointment-progress-report-${report.id}'),
                    report: report,
                    onTap: onReportSelected == null
                        ? null
                        : () => onReportSelected!(report.id),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// D-079: customer-safe status timeline — mirrors the staff web's history
/// modal minus the free-text `reason` and staff identity, which the API
/// never sends to this client. Drawn oldest → newest as a vertical stepper:
/// past steps are filled check dots, the latest (still open) step gets the
/// accent ring.
class _StatusTimeline extends StatelessWidget {
  const _StatusTimeline({required this.entries});

  /// Newest first, per the API contract.
  final List<OrderStatusHistoryEntry> entries;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    final ordered = entries.reversed.toList();
    final latest = ordered.last.toStatus;
    // A finished/cancelled order has no "current" step left — all done.
    final closed =
        latest == ServiceProgressStatus.completed ||
        latest == ServiceProgressStatus.cancelled;
    bool isDone(int i) => closed || i < ordered.length - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < ordered.length; i++)
          IntrinsicHeight(
            key: ValueKey('status-history-${ordered[i].id}'),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 22,
                  child: Column(
                    children: [
                      _TimelineDot(done: isDone(i)),
                      if (i < ordered.length - 1)
                        Expanded(
                          child: Container(
                            width: 2,
                            margin: const EdgeInsets.symmetric(vertical: 2),
                            color: isDone(i + 1)
                                ? theme.inverse
                                : theme.cardBorder,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: 1,
                      bottom: i < ordered.length - 1 ? 14 : 0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ordered[i].toStatus.localizedLabel,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text.rich(
                          TextSpan(
                            children: [
                              if (ordered[i].reasonTag != null)
                                TextSpan(
                                  text:
                                      '${ordered[i].reasonTag!.localizedLabel} · ',
                                ),
                              TextSpan(
                                text: _formatDateTime(ordered[i].createdAt),
                                style: csMono(fontSize: 12),
                              ),
                            ],
                          ),
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.mutedText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TimelineDot extends StatelessWidget {
  const _TimelineDot({required this.done});

  final bool done;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    if (done) {
      return Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(color: theme.inverse, shape: BoxShape.circle),
        child: Icon(Icons.check_rounded, size: 13, color: theme.onInverse),
      );
    }
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: theme.card,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.accent, width: 6),
      ),
    );
  }
}

class _TotalsBlock extends StatelessWidget {
  const _TotalsBlock({required this.progress});

  final AppointmentServiceProgress progress;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    final labelStyle = TextStyle(fontSize: 13, color: theme.mutedText);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.shellBackground,
        borderRadius: BorderRadius.circular(AppRadii.large),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Нийт дүн', style: labelStyle),
                Text(
                  '${formatAmount(progress.totalAmount!.round())}₮',
                  style: csMono(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: theme.ink,
                  ),
                ),
              ],
            ),
            if (progress.paidAmount != null) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Төлсөн', style: labelStyle),
                  Text(
                    '${formatAmount(progress.paidAmount!.round())}₮',
                    style: csMono(fontSize: 13, color: theme.ink),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProgressItemRow extends StatelessWidget {
  const _ProgressItemRow({required this.item, super.key});

  final AppointmentServiceItemProgress item;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    final brightness = Theme.of(context).brightness;
    // Сэлбэгийн статус хажууд харуулахгүй — web dashboard дээр аль хэдийн
    // адилхан алгав (`order-items.tsx`: `g.kind !== "PART"`), учир нь
    // сэлбэгт статус солих боломж байхгүй болсон тул статус нь хоцрогдсон/
    // хамааралгүй мэдээлэл болно.
    final isPart = item.kind == ServiceOrderItemKind.part;
    final statusColor = switch (item.status) {
      ServiceProgressStatus.completed => AppColors.readable(
        AppColors.green,
        brightness,
      ),
      ServiceProgressStatus.inProgress => theme.link,
      ServiceProgressStatus.cancelled => theme.mutedText,
      _ => theme.mutedText,
    };

    final hasPrice = item.total != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Сэлбэгийн мөрөнд статусын дүрс харуулахгүй ч зэргэлдээх
          // ажил/оношилгооны мөртэй эгнээ зэрэгцэн харагддаг тул зайг
          // тэнцвэржүүлж (SizedBox), зүүн эхлэл шилжихгүй байлгав.
          SizedBox(
            width: 22,
            child: isPart ? null : _ItemStatusDot(status: item.status),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (hasPrice)
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: '${item.kind.localizedLabel} · '),
                        TextSpan(
                          text:
                              '${item.quantity ?? 1} × '
                              '${formatAmount((item.unitPrice ?? 0).round())}₮',
                          style: csMono(fontSize: 12),
                        ),
                      ],
                    ),
                    style: TextStyle(fontSize: 12, color: theme.mutedText),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isPart)
                Text(
                  item.status.localizedLabel,
                  style: TextStyle(
                    fontSize: 12,
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (hasPrice)
                Text(
                  '${formatAmount(item.total!.round())}₮',
                  style: csMono(fontSize: 13, color: theme.ink),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Item status as a 22px dot, same language as the status timeline.
class _ItemStatusDot extends StatelessWidget {
  const _ItemStatusDot({required this.status});

  final ServiceProgressStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    return switch (status) {
      ServiceProgressStatus.completed => Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(color: theme.inverse, shape: BoxShape.circle),
        child: Icon(Icons.check_rounded, size: 13, color: theme.onInverse),
      ),
      ServiceProgressStatus.inProgress => Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: theme.card,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.accent, width: 6),
        ),
      ),
      ServiceProgressStatus.cancelled => Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: theme.shellBackground,
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.close_rounded, size: 13, color: theme.mutedText),
      ),
      _ => Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: theme.cardBorder, width: 2),
        ),
      ),
    };
  }
}

String _formatDateTime(DateTime value) =>
    '${value.year}.${value.month.toString().padLeft(2, '0')}.${value.day.toString().padLeft(2, '0')} '
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
