import 'package:carservice_customer/app/app_messages.dart';
import 'package:carservice_customer/features/history/presentation/widgets/order_intake_tile.dart';
import 'package:carservice_customer/features/history/domain/service_history_repository.dart';

import 'dart:async';

import 'package:carservice_customer/app/theme/app_surfaces.dart';
import 'package:carservice_customer/core/widgets/cs_ui.dart';
import 'package:carservice_customer/core/widgets/skeletons.dart';
import 'package:carservice_customer/app/theme/app_theme.dart';
import 'package:carservice_customer/core/errors/app_failure.dart';
import 'package:carservice_customer/features/booking/domain/appointment.dart';
import 'package:carservice_customer/features/booking/domain/appointment_payment.dart';
import 'package:carservice_customer/features/booking/domain/appointment_status.dart';
import 'package:carservice_customer/features/booking/presentation/controllers/appointments_controller.dart';
import 'package:carservice_customer/features/booking/presentation/controllers/appointments_state.dart';
import 'package:carservice_customer/features/booking/presentation/widgets/service_progress_section.dart';
import 'package:carservice_customer/features/discovery/domain/branch.dart';
import 'package:carservice_customer/features/discovery/domain/organization_repository.dart';
import 'package:carservice_customer/features/discovery/services/location_permission_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Full-page view of a single appointment. Reads the appointment reactively
/// from [AppointmentsController] by id rather than taking it as a constructor
/// argument, so the same screen serves a list tap, the post-booking landing,
/// and (later) a push-notification deep link — each of which only knows the id.
/// When the id isn't in the loaded list yet (e.g. right after booking, before
/// the refetch lands), it shows a loading state and resolves once `load()`
/// completes.
class AppointmentDetailScreen extends StatefulWidget {
  const AppointmentDetailScreen({
    required this.appointmentId,
    required this.organizationRepository,
    required this.onBack,
    required this.onPay,
    this.onReportSelected,
    this.historyRepository,
    super.key,
  });

  final String appointmentId;

  /// Used to fetch the branch's location/hours/contact — none of which the
  /// appointment payload carries (it has only the branch *name*).
  final OrganizationRepository organizationRepository;

  final VoidCallback onBack;

  /// Opens the fee-payment screen for [appointment]. Wired by the router, the
  /// same way the appointments list does it.
  final ValueChanged<Appointment> onPay;

  /// Opens a diagnostic report's detail screen. Same callback the history
  /// screens use — wired by the router to the shared diagnostics detail page.
  final ValueChanged<String>? onReportSelected;
  // «Хүлээн авах» бүртгэлийг татахад ашиглана; null бол tile нуугдана.
  final ServiceHistoryRepository? historyRepository;

  @override
  State<AppointmentDetailScreen> createState() =>
      _AppointmentDetailScreenState();
}

class _AppointmentDetailScreenState extends State<AppointmentDetailScreen>
    with WidgetsBindingObserver {
  Timer? _pollTimer;

  // Item-level order progress (labor/parts being checked off) has no push
  // notification of its own (would be spammy — see project notes), so while
  // this screen is open and in the foreground, poll for it periodically
  // instead. Paused while backgrounded, cancelled on leaving the screen —
  // never runs when nobody is looking at it.
  static const _pollInterval = Duration(seconds: 25);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startPolling();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      if (!mounted) return;
      // Silent + guarded: no loading flash, and a tick is skipped while a
      // previous load is still in flight.
      context.read<AppointmentsController>().refreshSilently();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPolling();
    } else {
      _pollTimer?.cancel();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    super.dispose();
  }

  Appointment? _find(AppointmentsController controller) {
    for (final appointment in controller.state.appointments) {
      if (appointment.id == widget.appointmentId) return appointment;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppointmentsController>();
    final appointment = _find(controller);
    final isLoading =
        controller.state.status == AppointmentsStatus.loading ||
        controller.state.status == AppointmentsStatus.initial;

    return Scaffold(
      body: AppShellBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DetailHeader(
                title: 'Цагийн дэлгэрэнгүй',
                subtitle: appointment == null
                    ? null
                    : _vehicleCaption(appointment),
                onBack: widget.onBack,
              ),
              Expanded(
                child: switch ((appointment, isLoading)) {
                  (final Appointment appointment, _) => _AppointmentDetailBody(
                    appointment: appointment,
                    organizationRepository: widget.organizationRepository,
                    isCancelling: controller.isCancelling(appointment.id),
                    onRefresh: controller.load,
                    onCancel: appointment.canCancel
                        ? () => _confirmCancel(context, controller, appointment)
                        : null,
                    onPay: appointment.canPayFee
                        ? () => widget.onPay(appointment)
                        : null,
                    onReportSelected: widget.onReportSelected,
                    historyRepository: widget.historyRepository,
                  ),
                  (null, true) => const SkeletonDetail(),
                  (null, false) => _NotFound(onBack: widget.onBack),
                },
              ),
            ],
          ),
        ),
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
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Үгүй'),
          ),
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

/// "Prius 30 · 1234 УБА" under the page title — the car this visit is for.
String? _vehicleCaption(Appointment appointment) {
  final progress = appointment.serviceProgress;
  final model = progress == null
      ? null
      : [
          progress.vehicleMake,
          progress.vehicleModel,
        ].whereType<String>().where((s) => s.trim().isNotEmpty).join(' ');
  final plate = progress?.vehiclePlate ?? appointment.vehiclePlate;
  final parts = [
    model,
    plate,
  ].whereType<String>().where((s) => s.trim().isNotEmpty).toList();
  return parts.isEmpty ? null : parts.join(' · ');
}

/// Design header for pushed pages: round back button + title (+ mono caption).
class _DetailHeader extends StatelessWidget {
  const _DetailHeader({
    required this.title,
    required this.onBack,
    this.subtitle,
  });

  final String title;
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
                    title,
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

class _AppointmentDetailBody extends StatelessWidget {
  const _AppointmentDetailBody({
    required this.appointment,
    required this.organizationRepository,
    required this.isCancelling,
    required this.onRefresh,
    this.onCancel,
    this.onPay,
    this.onReportSelected,
    this.historyRepository,
  });

  final Appointment appointment;
  final OrganizationRepository organizationRepository;
  final bool isCancelling;
  final Future<void> Function() onRefresh;
  final VoidCallback? onCancel;
  final VoidCallback? onPay;
  final ValueChanged<String>? onReportSelected;
  final ServiceHistoryRepository? historyRepository;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    final progress = appointment.serviceProgress;
    final infoRows = <Widget>[
      // Захиалга үүссэн үед баатар карт нь явцыг харуулдаг тул захиалсан
      // цагийг энд үлдээнэ; үүсээгүй бол баатар карт өөрөө цагийг харуулна.
      if (progress != null)
        _DetailRow(
          icon: Icons.event_outlined,
          label: 'Цаг',
          value: _formatDateTime(appointment.requestedAt),
          mono: true,
        ),
      // Захиалга үүсмэгц `ServiceProgressSection` бодит үйлчилгээний
      // жагсаалтыг харуулдаг тул энэ мөр давхцаж, хоцрогдсон болно
      // (appointments_screen.dart-ийн ижил нөхцөл).
      if (progress == null && appointment.categoryNames.isNotEmpty)
        _DetailRow(
          icon: Icons.construction_outlined,
          label: appointment.categoryNames.length > 1 ? 'Ангиллууд' : 'Ангилал',
          value: appointment.categoryNames.join(' · '),
        ),
      if (appointment.vehiclePlate != null)
        _DetailRow(
          icon: Icons.directions_car_outlined,
          label: 'Тээврийн хэрэгсэл',
          value: appointment.vehiclePlate!,
          plate: true,
        ),
      if (appointment.note != null && appointment.note!.trim().isNotEmpty)
        _DetailRow(
          icon: Icons.sticky_note_2_outlined,
          label: 'Тэмдэглэл',
          value: appointment.note!,
        ),
    ];
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          if (progress != null)
            ServiceProgressHero(
              progress: progress,
              label: '${appointment.tenantName} · ${appointment.branchName}',
            )
          else
            _AppointmentHero(appointment: appointment),
          // Хэсгүүдийн дараалал: юу болж байна → юу хийх ёстой → хаашаа
          // очих. Явц (ServiceProgressSection) нь захиалга үүссэний дараа энэ
          // хуудсыг нээх БАРАГ цорын ганц шалтгаан тул салбарын лавлах
          // мэдээллээс дээр байна; хураамжийн сэрэмжлүүлэг нь богино бөгөөд
          // мөнгөтэй холбоотой үйлдэл учир төлвийн картын шууд доор үлдэнэ
          // (урт явцын картын доор дарагдвал анзаарагдахгүй өнгөрөх эрсдэлтэй).
          //
          // Зай: нэг бүлгийн дотор 12, бүлэг хооронд 20.
          if (onPay != null) ...[
            const SizedBox(height: 12),
            _Notice(
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
                        fontWeight: FontWeight.w600,
                        color: AppColors.readable(
                          AppColors.red,
                          Theme.of(context).brightness,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    key: ValueKey('detail-pay-${appointment.id}'),
                    onPressed: onPay,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(48, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                    ),
                    child: const Text('Төлөх'),
                  ),
                ],
              ),
            ),
          ],
          // Хураамж төлөгдсөн бол баталгаажуулах badge — цаг захиалгын status
          // (Хүлээгдэж буй) нь салангид: төлбөр төлөгдсөн ч ажилтан баталгаажуулах
          // хүртэл PENDING хэвээр. Хоёрыг андуурахгүйн тулд төлбөрийг тусад нь
          // тэмдэглэнэ.
          if (appointment.payment?.status == AppointmentFeeStatus.paid) ...[
            const SizedBox(height: 12),
            _FeePaidBadge(key: ValueKey('detail-fee-paid-${appointment.id}')),
          ],
          if (appointment.payment?.status == AppointmentFeeStatus.refunded) ...[
            const SizedBox(height: 12),
            _Notice(
              key: ValueKey('detail-fee-refunded-${appointment.id}'),
              tint: AppColors.accent,
              background: theme.shellBackground,
              child: Text(
                'Хураамж буцаагдсан',
                style: TextStyle(fontWeight: FontWeight.w600, color: theme.ink),
              ),
            ),
          ],
          if (infoRows.isNotEmpty) ...[
            const SizedBox(height: 12),
            CsCard(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: infoRows,
              ),
            ),
          ],
          if (progress != null) ...[
            const SizedBox(height: 20),
            ServiceProgressSection(
              progress: progress,
              onReportSelected: onReportSelected,
            ),
            if (progress.hasIntake && historyRepository != null) ...[
              const SizedBox(height: 12),
              OrderIntakeTile(
                orderId: progress.id,
                repository: historyRepository,
              ),
            ],
          ],
          const SizedBox(height: 20),
          _BranchInfoCard(
            tenantSlug: appointment.tenantSlug,
            tenantName: appointment.tenantName,
            branchName: appointment.branchName,
            repository: organizationRepository,
          ),
          if (onCancel != null) ...[
            const SizedBox(height: 20),
            // Цуцлах нь эргэлт буцалтгүй үйлдэл тул аюулын өнгөөр ялгана.
            // Үүнгүйгээр энэ нь салбарын картын "Газрын зураг дээр харах"
            // OutlinedButton-той яг ижил харагдана — дээр нь шууд залгаа
            // байрладаг тул андуурч дарах бодит эрсдэл үүснэ.
            OutlinedButton.icon(
              key: ValueKey('detail-cancel-${appointment.id}'),
              onPressed: isCancelling ? null : onCancel,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.readable(
                  AppColors.red,
                  Theme.of(context).brightness,
                ),
                side: BorderSide(
                  color: AppColors.red.withValues(
                    alpha: isCancelling ? 0.2 : 0.5,
                  ),
                ),
              ),
              icon: isCancelling
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.close_rounded),
              label: const Text('Захиалга цуцлах'),
            ),
          ],
        ],
      ),
    );
  }
}

/// The navy status block before a service order exists: booked time, the
/// appointment status, the service and branch.
class _AppointmentHero extends StatelessWidget {
  const _AppointmentHero({required this.appointment});

  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    return CsHeroCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _formatDateTime(appointment.requestedAt),
                  style: csMono(
                    fontSize: 12,
                    letterSpacing: 0.4,
                    color: theme.onHeroMuted,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              HeroStatusPill(
                label: appointment.status.localizedLabel,
                emphasized: appointment.status.isActive,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            appointment.tenantName,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.22,
              height: 1.2,
              color: theme.onHero,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            appointment.branchName,
            style: TextStyle(fontSize: 14, color: theme.onHeroMuted),
          ),
        ],
      ),
    );
  }
}

/// A tinted full-width notice (unpaid fee, refunded fee).
class _Notice extends StatelessWidget {
  const _Notice({
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
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: background,
      border: Border.all(color: tint.withValues(alpha: 0.35)),
      borderRadius: BorderRadius.circular(AppRadii.card),
    ),
    child: child,
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.mono = false,
    this.plate = false,
  });

  final IconData icon;
  final String label;
  final String value;

  /// Render the value in Geist Mono (times).
  final bool mono;

  /// Render the value as a licence-plate chip.
  final bool plate;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CsIconTile(
            icon: icon,
            size: 32,
            color: theme.ink,
            background: theme.shellBackground,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: theme.mutedText),
                ),
                const SizedBox(height: 2),
                if (plate)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: CsPlate(value),
                  )
                else
                  Text(
                    value,
                    style: mono
                        ? csMono(fontSize: 14, color: theme.ink)
                        : TextStyle(fontSize: 15, color: theme.ink),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CsIconTile(
              icon: Icons.event_busy_outlined,
              size: 56,
              color: theme.mutedText,
              background: theme.card,
            ),
            const SizedBox(height: 16),
            Text(
              'Захиалга олдсонгүй',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
                color: theme.ink,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onBack, child: const Text('Буцах')),
          ],
        ),
      ),
    );
  }
}

/// Location, work hours and contact for the appointment's branch. None of this
/// is in the appointment payload (which carries only the branch *name*), so it
/// fetches the organization detail by slug and matches the branch by name.
/// Degrades gracefully: a spinner while loading, an offline note when the fetch
/// fails for lack of network, and a muted "not found" if the branch can't be
/// matched.
class _BranchInfoCard extends StatefulWidget {
  const _BranchInfoCard({
    required this.tenantSlug,
    required this.tenantName,
    required this.branchName,
    required this.repository,
  });

  final String tenantSlug;
  final String tenantName;
  final String branchName;
  final OrganizationRepository repository;

  @override
  State<_BranchInfoCard> createState() => _BranchInfoCardState();
}

class _BranchInfoCardState extends State<_BranchInfoCard> {
  bool _loading = true;
  bool _offline = false;
  BranchDetail? _branch;
  String? _phone;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _offline = false;
    });
    try {
      final org = await widget.repository.getOrganization(widget.tenantSlug);
      if (!mounted) return;
      BranchDetail? match;
      for (final branch in org.branches) {
        if (branch.name.trim() == widget.branchName.trim()) {
          match = branch;
          break;
        }
      }
      setState(() {
        _branch = match;
        _phone = org.phone;
        _loading = false;
      });
    } on NetworkFailure {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _offline = true;
      });
    } on AppFailure {
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _openMaps(BranchDetail branch) async {
    final destination = '${branch.latitude},${branch.longitude}';
    // With location permission, open directions (Google Maps routes from the
    // user's position and highlights the path). Without it, just drop a pin on
    // the place — we don't force a permission prompt from a maps tap.
    LocationAccessState access;
    try {
      access = await const PermissionHandlerLocationPermissionService().check();
    } catch (_) {
      access = LocationAccessState.denied;
    }
    final directions = access == LocationAccessState.granted;
    // Prefer each platform's native map app: Apple Maps on iOS, Google Maps on
    // Android. Both are https universal links, so if the native app is absent
    // they still open in the browser (see the no-Maps-app case).
    final Uri uri;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      uri = directions
          ? Uri.parse('https://maps.apple.com/?daddr=$destination&dirflg=d')
          : Uri.parse('https://maps.apple.com/?q=$destination');
    } else {
      uri = directions
          ? Uri.parse(
              'https://www.google.com/maps/dir/?api=1&destination=$destination',
            )
          : Uri.parse(
              'https://www.google.com/maps/search/?api=1&query=$destination',
            );
    }
    // Edge case: no app can handle the URL (Maps unavailable) — launchUrl
    // returns false or throws depending on platform.
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) throw Exception('launch returned false');
    } catch (_) {
      if (!mounted) return;
      AppMessages.show('Газрын зураг нээх боломжгүй байна');
    }
  }

  Future<void> _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    final ok = await launchUrl(uri);
    if (!ok && mounted) {
      AppMessages.show('Дуудлага хийж чадсангүй');
    }
  }

  Future<void> _copy(String phone) async {
    await Clipboard.setData(ClipboardData(text: phone));
    if (!mounted) return;
    AppMessages.show('Утасны дугаар хууллаа');
  }

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CsCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Байршил ба цагийн хуваарь',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: theme.ink,
                ),
              ),
              const SizedBox(height: 12),
              if (_loading)
                Row(
                  children: [
                    const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Ачаалж байна…',
                      style: TextStyle(color: theme.mutedText),
                    ),
                  ],
                )
              else if (_offline)
                const _Note(
                  icon: Icons.wifi_off_rounded,
                  text: 'Сүлжээгүй үед байршил, цагийн мэдээлэл харагдахгүй.',
                )
              else if (_branch == null)
                const _Note(
                  icon: Icons.info_outline_rounded,
                  text: 'Салбарын дэлгэрэнгүй мэдээлэл олдсонгүй.',
                )
              else
                ..._content(context, _branch!),
            ],
          ),
        ),
        // Дизайны "механиктай холбогдох" мөрийн оронд: механикийн мэдээлэл
        // API-д байхгүй тул салбарын утсыг л харуулна.
        if (!_loading && _phone != null) ...[
          const SizedBox(height: 12),
          _ContactRow(
            name: widget.tenantName,
            phone: _phone!,
            onCall: () => _call(_phone!),
            onCopy: () => _copy(_phone!),
          ),
        ],
      ],
    );
  }

  List<Widget> _content(BuildContext context, BranchDetail branch) {
    final theme = CarserviceTheme.of(context);
    final hasCoords = branch.latitude != null && branch.longitude != null;
    return [
      if (branch.fullAddress.trim().isNotEmpty)
        _DetailRow(
          icon: Icons.place_outlined,
          label: 'Хаяг',
          value: branch.fullAddress,
        ),
      Row(
        children: [
          CsIconTile(
            icon: Icons.schedule_rounded,
            size: 32,
            color: theme.ink,
            background: theme.shellBackground,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              branch.hoursLabel,
              style: TextStyle(fontSize: 15, color: theme.ink),
            ),
          ),
          const SizedBox(width: 8),
          _openBadge(branch.openStatusAt(DateTime.now())),
        ],
      ),
      if (hasCoords) ...[
        const SizedBox(height: 14),
        OutlinedButton.icon(
          key: const ValueKey('detail-show-on-maps'),
          onPressed: () => _openMaps(branch),
          icon: const Icon(Icons.map_outlined),
          label: const Text('Газрын зураг дээр харах'),
        ),
      ],
    ];
  }
}

/// The design's contact row (avatar + name + round call button), wired to the
/// branch's phone rather than a mechanic.
class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.name,
    required this.phone,
    required this.onCall,
    required this.onCopy,
  });

  final String name;
  final String phone;
  final VoidCallback onCall;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    final initials = words.isEmpty
        ? '?'
        : words.take(2).map((w) => w.characters.first.toUpperCase()).join();
    return CsCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.hero,
                shape: BoxShape.circle,
              ),
              child: Text(
                initials,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.onHero,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Салбартай холбогдох',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: theme.ink,
                  ),
                ),
                Text(
                  phone,
                  style: csMono(fontSize: 12, color: theme.mutedText),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          CsCircleButton(
            key: const ValueKey('detail-copy-phone'),
            icon: Icons.copy_rounded,
            tooltip: 'Дугаар хуулах',
            onPressed: onCopy,
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: 'Залгах',
            child: Material(
              key: const ValueKey('detail-call'),
              color: theme.inverse,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onCall,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(
                    Icons.phone_outlined,
                    size: 20,
                    color: theme.onInverse,
                    semanticLabel: 'Залгах',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final muted = CarserviceTheme.of(context).mutedText;
    return Row(
      children: [
        Icon(icon, size: 18, color: muted),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: TextStyle(color: muted)),
        ),
      ],
    );
  }
}

Widget _openBadge(BranchOpenStatus status) => switch (status) {
  BranchOpenStatus.open => const CsBadge('Нээлттэй', tone: CsTone.success, dot: true),
  BranchOpenStatus.closed => const CsBadge('Хаалттай', tone: CsTone.accent),
  BranchOpenStatus.unknown => const CsBadge('Тодорхойгүй'),
};

/// Хураамж төлөгдсөнийг харуулах ногоон badge (цаг захиалгын status-аас
/// тусдаа — доор жагсаалтын дэлгэц дээр ижил дүр зурагтай).
class _FeePaidBadge extends StatelessWidget {
  const _FeePaidBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    final green = AppColors.readable(
      AppColors.green,
      Theme.of(context).brightness,
    );
    return _Notice(
      tint: AppColors.green,
      background: theme.successSoft,
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, size: 18, color: green),
          const SizedBox(width: 8),
          Text(
            'Хураамж төлөгдсөн',
            style: TextStyle(fontWeight: FontWeight.w600, color: green),
          ),
        ],
      ),
    );
  }
}

String _formatDateTime(DateTime value) =>
    '${value.year}.${value.month.toString().padLeft(2, '0')}.${value.day.toString().padLeft(2, '0')} '
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
