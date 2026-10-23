import 'package:carservice_customer/app/theme/app_surfaces.dart';
import 'package:carservice_customer/app/theme/app_theme.dart';
import 'package:carservice_customer/features/booking/domain/appointment_repository.dart';
import 'package:carservice_customer/features/booking/presentation/controllers/booking_form_controller.dart';
import 'package:carservice_customer/features/booking/presentation/widgets/booking_calendar.dart';
import 'package:carservice_customer/features/booking/presentation/widgets/booking_form_sections.dart';
import 'package:carservice_customer/features/booking/presentation/widgets/booking_header.dart';
import 'package:carservice_customer/features/booking/presentation/widgets/booking_locked_notices.dart';
import 'package:carservice_customer/features/booking/presentation/widgets/booking_vehicle_picker.dart';
import 'package:carservice_customer/features/discovery/domain/organization.dart';
import 'package:carservice_customer/features/vehicles/presentation/controllers/vehicles_controller.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class BookingRequestScreen extends StatefulWidget {
  const BookingRequestScreen({
    required this.organization,
    this.initialBranchId,
    required this.repository,
    required this.onAddVehicle,
    required this.onBack,
    required this.onCompleted,
    required this.onUnauthenticated,
    this.initialCategoryIds,
    this.lockCategories = false,
    this.lockBranch = false,
    super.key,
  });

  final OrganizationDetail organization;
  final String? initialBranchId;
  final AppointmentRepository repository;
  final VoidCallback onAddVehicle;
  final VoidCallback onBack;
  final ValueChanged<CreatedAppointment> onCompleted;
  final VoidCallback onUnauthenticated;

  /// Cross-org "юу хийлгэх гэж байна?" пикерээс (Booking tab) аль хэдийн
  /// сонгогдсон ангилалуудын id — зөвхөн [lockCategories] үнэн үед хэрэглэгдэнэ.
  final List<String>? initialCategoryIds;

  /// Ангилалыг Booking tab-ийн пикер дээр аль хэдийн сонгосон тул энд дахин
  /// сонгуулахгүй (зөвхөн товч тоймоор харуулна), мөн [initialBranchId]-аас
  /// өөр салбар руу сольж болохгүй (тухайн салбар л сонгосон бүх ажлыг санал
  /// болгодог гэдгийг үр дүнгийн жагсаалт дээр аль хэдийн баталгаажуулсан).
  final bool lockCategories;

  /// Discover-ийн салбарын дэлгэрэнгүйгээс тодорхой салбар сонгож ирсэн бол
  /// (харах: [initialBranchId]) байгууллага/салбарын сонголтыг ТҮГЖИНЭ —
  /// хэрэглэгч зөвхөн ангилал, огноо/цагаа сонгоно. [lockCategories]-ийн
  /// эсрэг тэнхлэг: тэнд ангилал түгжигдэж салбар (тохирох хүрээнд) чөлөөтэй,
  /// энд салбар түгжигдэж ангилал чөлөөтэй. Хоёул `false`-той адилтгах
  /// боломжгүй (харилцан үл шүтэлцээтэй урсгалууд).
  final bool lockBranch;

  @override
  State<BookingRequestScreen> createState() => _BookingRequestScreenState();
}

class _BookingRequestScreenState extends State<BookingRequestScreen>
    with WidgetsBindingObserver {
  final _noteController = TextEditingController();
  late final BookingFormController _form;

  // Step anchors, for scrolling the form to the step that needs attention.
  final _servicesKey = GlobalKey();
  final _branchKey = GlobalKey();
  final _dateKey = GlobalKey();
  final _slotKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _form = BookingFormController(
      organization: widget.organization,
      repository: widget.repository,
      vehiclesController: context.read<VehiclesController>(),
      initialBranchId: widget.initialBranchId,
      initialCategoryIds: widget.initialCategoryIds,
      lockCategories: widget.lockCategories,
      lockBranch: widget.lockBranch,
    );
    WidgetsBinding.instance.addObserver(this);
  }

  /// Апп background-оос буцаж ирэхэд сонгосон огноо/цаг хугацаандаа хоцорсон
  /// эсвэл дүүрсэн байж болзошгүй — controller дахин ачаалж шинэчилнэ.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _form.onAppResumed();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _form.dispose();
    _noteController.dispose();
    super.dispose();
  }

  /// Brings [key]'s step into view after the next frame (it may only be
  /// built by the change that triggered the scroll).
  void _scrollTo(GlobalKey key) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = key.currentContext;
      if (!mounted || target == null) return;
      final reduceMotion = MediaQuery.of(context).disableAnimations;
      Scrollable.ensureVisible(
        target,
        alignment: 0.05,
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    });
  }

  /// The first step still missing a choice, matching
  /// [bookingNextStepHint].
  GlobalKey? get _firstIncompleteStep {
    final form = _form;
    if (form.selectedBranch == null) {
      return form.selectedCategoryIds.isEmpty && !form.lockCategories
          ? _servicesKey
          : _branchKey;
    }
    if (form.selectedDate == null) return _dateKey;
    if (form.selectedSlot == null) return _slotKey;
    return null;
  }

  Future<void> _submit() async {
    final missing = _firstIncompleteStep;
    final outcome = await _form.submit(_noteController.text);
    if (!mounted) return;
    switch (outcome.status) {
      case BookingSubmitStatus.completed:
        widget.onCompleted(outcome.created!);
      case BookingSubmitStatus.unauthenticated:
        widget.onUnauthenticated();
      case BookingSubmitStatus.ignored:
        if (missing != null) _scrollTo(missing);
      case BookingSubmitStatus.failed:
        break;
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _form,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: widget.onBack),
        title: const Text('Цаг хүсэх'),
      ),
      body: AppShellBackground(
        child: SafeArea(
          top: false,
          bottom: false,
          child: _form.lockedFlowBlocked
              ? LockedFlowUnavailable(
                  branchMissing: _form.lockedBranchMissing,
                  onBack: widget.onBack,
                )
              : _buildForm(context),
        ),
      ),
      bottomNavigationBar: _form.lockedFlowBlocked
          ? null
          : BookingSummaryBar(form: _form, onSubmit: _submit),
    ),
  );

  Widget _buildForm(BuildContext context) {
    final form = _form;
    final muted = CarserviceTheme.of(context).mutedText;
    final showServices = form.lockCategories || form.allCategories.isNotEmpty;
    final showBranch = bookingBranchStepVisible(form);
    var step = 0;
    // Not a lazy ListView: every step stays built, so scrolling to whichever
    // one needs attention always has a target.
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BookingHeader(
            organization: widget.organization,
            selectedBranch: form.selectedBranch,
            categoryCount: form.allCategories.length,
          ),
          if (showServices) ...[
            const SizedBox(height: 24),
            KeyedSubtree(
              key: _servicesKey,
              child: BookingCategorySection(form: form, number: ++step),
            ),
          ],
          if (showBranch) ...[
            const SizedBox(height: 24),
            KeyedSubtree(
              key: _branchKey,
              child: BookingBranchSection(form: form, number: ++step),
            ),
          ],
          const SizedBox(height: 24),
          BookingStep(
            key: _dateKey,
            number: ++step,
            title: 'Өдөр',
            complete: form.selectedDate != null,
            trailing: form.selectedDate == null
                ? null
                : bookingDateLabel(form.selectedDate!, DateTime.now()),
            child: form.selectedBranch == null
                ? BookingStepHint(
                    text: showServices && form.selectedCategoryIds.isEmpty
                        ? 'Эхлээд үйлчилгээ, салбараа сонгоно уу.'
                        : 'Эхлээд салбараа сонгоно уу.',
                  )
                : GlassSurface(
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
                    child: BookingCalendar(
                      month: form.displayedMonth,
                      selectedDate: form.selectedDate,
                      branch: form.selectedBranch,
                      onMonthChanged: form.setDisplayedMonth,
                      onDateSelected: (date) {
                        form.selectDate(date);
                        _scrollTo(_slotKey);
                      },
                    ),
                  ),
          ),
          const SizedBox(height: 24),
          KeyedSubtree(
            key: _slotKey,
            child: BookingSlotSection(form: form, number: ++step),
          ),
          const SizedBox(height: 24),
          BookingStep(
            number: ++step,
            title: 'Нэмэлт мэдээлэл',
            complete: false,
            trailing: 'Заавал биш',
            child: GlassSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  VehiclePicker(
                    controller: form.vehiclesController,
                    selectedVehicleId: form.selectedVehicleId,
                    onChanged: form.selectVehicle,
                    onAddVehicle: widget.onAddVehicle,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _noteController,
                    maxLines: 4,
                    minLines: 2,
                    maxLength: 500,
                    decoration: const InputDecoration(
                      labelText: 'Тэмдэглэл',
                      hintText: 'Машины асуудал, хүсэлтээ товч бичнэ үү',
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, size: 16, color: muted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Энэ нь хүсэлт илгээх үйлдэл. Сервис баталгаажуулсны дараа '
                  'цаг баталгаажна.',
                  style: TextStyle(fontSize: 12, color: muted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
