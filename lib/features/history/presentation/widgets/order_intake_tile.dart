import 'package:carservice_customer/app/app_messages.dart';
import 'package:carservice_customer/app/customer_routes.dart';
import 'package:carservice_customer/app/theme/app_surfaces.dart';
import 'package:carservice_customer/core/errors/app_failure.dart';
import 'package:carservice_customer/features/history/domain/order_intake.dart';
import 'package:carservice_customer/features/history/domain/service_history_repository.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// «Хүлээн авах» бүртгэлийн товч мөр — дарахад бүтэн дэлгэц нээгдэнэ.
///
/// Хоёр хувилбартай: [intake] аль хэдийн мэдэгдэж байвал (захиалгын түүх)
/// шууд нээнэ; үгүй бол (идэвхтэй захиалга — жагсаалтад зөвхөн `hasIntake`
/// ирдэг) дарахад [repository]-оос захиалгын дэлгэрэнгүйг татаж, ачаалах
/// төлөвийг мөр дээр харуулаад, алдаа гарвал snackbar-аар мэдээлнэ.
class OrderIntakeTile extends StatefulWidget {
  const OrderIntakeTile({
    required this.orderId,
    this.intake,
    this.repository,
    super.key,
  }) : assert(
         intake != null || repository != null,
         'intake эсвэл repository-н аль нэг нь шаардлагатай',
       );

  final String orderId;
  final OrderIntake? intake;
  final ServiceHistoryRepository? repository;

  @override
  State<OrderIntakeTile> createState() => _OrderIntakeTileState();
}

class _OrderIntakeTileState extends State<OrderIntakeTile> {
  bool _loading = false;

  String get _summary {
    final intake = widget.intake;
    if (intake == null) return 'Бүртгэсэн';
    final parts = <String>[
      if (intake.mileageLabel != null) intake.mileageLabel!,
      if (intake.hasNotes) 'Тэмдэглэлтэй',
      if (intake.photos.isNotEmpty) '${intake.photos.length} зураг',
      if (intake.signatureUrl != null) 'Гарын үсэгтэй',
    ];
    return parts.isEmpty ? 'Бүртгэсэн' : parts.join(' · ');
  }

  Future<void> _open() async {
    if (_loading) return;
    final known = widget.intake;
    if (known != null) {
      context.push(CustomerRoutes.orderIntake(widget.orderId), extra: known);
      return;
    }
    setState(() => _loading = true);
    String? error;
    OrderIntake? loaded;
    try {
      final detail = await widget.repository!.getServiceOrderDetail(
        widget.orderId,
      );
      loaded = detail.intake;
      if (loaded == null) error = 'Хүлээн авах бүртгэл олдсонгүй.';
    } on AppFailure catch (failure) {
      error = failure.message;
    } catch (_) {
      error = 'Тодорхойгүй алдаа гарлаа.';
    }
    if (!mounted) return;
    setState(() => _loading = false);
    if (loaded != null) {
      context.push(CustomerRoutes.orderIntake(widget.orderId), extra: loaded);
    } else {
      AppMessages.show(error!);
    }
  }

  @override
  Widget build(BuildContext context) => GlassSurface(
    child: InkWell(
      key: const ValueKey('intake-tile'),
      onTap: _loading ? null : _open,
      child: Row(
        children: [
          const Icon(Icons.assignment_turned_in_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Хүлээн авах',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(_summary, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          if (_loading)
            const SizedBox(
              key: ValueKey('intake-tile-loading'),
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            const Icon(Icons.chevron_right_rounded),
        ],
      ),
    ),
  );
}
