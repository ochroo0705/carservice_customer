import 'package:carservice_customer/app/theme/app_surfaces.dart';
import 'package:carservice_customer/app/theme/app_theme.dart';
import 'package:carservice_customer/features/booking/presentation/controllers/booking_form_controller.dart';
import 'package:carservice_customer/features/booking/presentation/widgets/booking_locked_notices.dart';
import 'package:carservice_customer/features/booking/presentation/widgets/time_slot_grid.dart';
import 'package:carservice_customer/features/discovery/domain/branch.dart';
import 'package:flutter/material.dart';

const _weekdayShort = ['Да', 'Мя', 'Лх', 'Пү', 'Ба', 'Бя', 'Ня'];

/// "Өнөөдөр", "Маргааш", or "10-р сарын 24, Ба" for a booking date.
String bookingDateLabel(DateTime date, DateTime now) {
  // Calendar-day difference via UTC dates, so a DST shift can't skew it.
  final days = DateTime.utc(
    date.year,
    date.month,
    date.day,
  ).difference(DateTime.utc(now.year, now.month, now.day)).inDays;
  if (days == 0) return 'Өнөөдөр';
  if (days == 1) return 'Маргааш';
  return '${date.month}-р сарын ${date.day}, ${_weekdayShort[date.weekday - 1]}';
}

String _clock(({int hour, int minute}) time) =>
    '${time.hour.toString().padLeft(2, '0')}:'
    '${time.minute.toString().padLeft(2, '0')}';

/// The selected services' approximate total — from the chosen branch's own
/// durations once there is one, else from the organisation-wide list.
int bookingSelectedMinutes(BookingFormController form) =>
    form.selectedBranch != null
    ? form.selectedDurationMinutes
    : form.allCategories
          .where((category) => form.selectedCategoryIds.contains(category.id))
          .fold(0, (sum, category) => sum + category.durationMinutes);

/// What still stands between the form and a sendable request, as a short
/// prompt — null once a branch, date and time are all picked.
String? bookingNextStepHint(BookingFormController form) {
  if (form.selectedBranch == null) {
    final needsServices =
        !form.lockBranch &&
        form.allCategories.isNotEmpty &&
        form.selectedCategoryIds.isEmpty;
    return needsServices ? 'Үйлчилгээгээ сонгоно уу' : 'Салбараа сонгоно уу';
  }
  if (form.selectedDate == null) return 'Өдрөө сонгоно уу';
  if (form.selectedSlot == null) return 'Цагаа сонгоно уу';
  return null;
}

/// One numbered step of the booking form: a badge that turns into a check
/// once the step is done, a title, an optional summary on the right, and
/// the step's controls below.
class BookingStep extends StatelessWidget {
  const BookingStep({
    required this.number,
    required this.title,
    required this.complete,
    required this.child,
    this.trailing,
    super.key,
  });

  final int number;
  final String title;
  final bool complete;
  final Widget child;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _StepBadge(number: number, complete: complete),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (trailing != null)
              Text(
                trailing!,
                style: TextStyle(fontSize: 12, color: theme.mutedText),
              ),
          ],
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _StepBadge extends StatelessWidget {
  const _StepBadge({required this.number, required this.complete});

  final int number;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: complete ? AppColors.accent : Colors.transparent,
        shape: BoxShape.circle,
        border: complete
            ? null
            : Border.all(color: theme.glassBorder, width: 1.5),
      ),
      alignment: Alignment.center,
      child: complete
          ? const Icon(Icons.check_rounded, size: 16, color: AppColors.onAccent)
          : Text(
              '$number',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: theme.mutedText,
              ),
            ),
    );
  }
}

/// A muted placeholder inside a step that isn't reachable yet.
class BookingStepHint extends StatelessWidget {
  const BookingStepHint({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.large),
        border: Border.all(color: theme.glassBorder),
      ),
      child: Text(text, style: TextStyle(fontSize: 13, color: theme.mutedText)),
    );
  }
}

/// Үйлчилгээний алхам: сонгох боломжтой мөрүүд (нэр + хугацаа). `lockCategories`
/// үед Booking tab-ийн пикер дээр аль хэдийн сонгосон тул зөвхөн харуулна.
class BookingCategorySection extends StatelessWidget {
  const BookingCategorySection({
    required this.form,
    required this.number,
    super.key,
  });

  final BookingFormController form;
  final int number;

  @override
  Widget build(BuildContext context) {
    final selectedIds = form.selectedCategoryIds;
    final categories = form.lockCategories
        ? form.allCategories.where((c) => selectedIds.contains(c.id)).toList()
        : form.allCategories;
    final minutes = bookingSelectedMinutes(form);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (form.lockCategories &&
            form.lockedUnavailableCategoryNames.isNotEmpty) ...[
          LockedCategoriesWarning(
            unavailableNames: form.lockedUnavailableCategoryNames,
          ),
          const SizedBox(height: 16),
        ],
        BookingStep(
          number: number,
          title: 'Үйлчилгээ',
          complete: selectedIds.isNotEmpty,
          trailing: selectedIds.isEmpty ? null : 'Нийт ~$minutes мин',
          child: GlassSurface(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final (index, category) in categories.indexed) ...[
                  if (index > 0)
                    Divider(
                      height: 1,
                      color: CarserviceTheme.of(context).glassBorder,
                    ),
                  _OptionRow(
                    key: ValueKey('booking-category-${category.id}'),
                    title: category.name,
                    subtitle: '~ ${category.durationMinutes} мин',
                    selected: selectedIds.contains(category.id),
                    // Locked rows show the hand-off's picks, not a choice.
                    onTap: form.lockCategories
                        ? null
                        : () => form.toggleCategory(
                            category.id,
                            !selectedIds.contains(category.id),
                          ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Whether the branch step applies: more than one branch to choose from and
/// neither side of the flow locked. Until services are picked it only
/// explains that branches follow from them (see [BookingBranchSection]).
bool bookingBranchStepVisible(BookingFormController form) =>
    !form.lockCategories &&
    !form.lockBranch &&
    form.organization.branches.length > 1;

/// Салбарын алхам — сонгосон бүх үйлчилгээг санал болгодог салбарууд. Анхны
/// дэвийн шийдвэрээр: ангилал сонгогдоогүй бол салбарыг сонгуулахгүй (харин
/// байгууллагад ангилал огт байхгүй бол шууд сонгуулна).
class BookingBranchSection extends StatelessWidget {
  const BookingBranchSection({
    required this.form,
    required this.number,
    super.key,
  });

  final BookingFormController form;
  final int number;

  @override
  Widget build(BuildContext context) {
    final waitingForServices =
        form.allCategories.isNotEmpty && form.selectedCategoryIds.isEmpty;
    final compatible = form.compatibleBranches;
    final Widget child;
    if (waitingForServices) {
      child = const BookingStepHint(
        text:
            'Үйлчилгээгээ сонгоход тэдгээрийг санал болгодог салбарууд гарна.',
      );
    } else if (compatible.isEmpty) {
      child = const BookingStepHint(
        text:
            'Сонгосон бүх үйлчилгээг нэгэн зэрэг санал болгодог салбар алга '
            'байна. Үйлчилгээнийхээ сонголтоо өөрчилнө үү.',
      );
    } else {
      child = GlassSurface(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (final (index, branch) in compatible.indexed) ...[
              if (index > 0)
                Divider(
                  height: 1,
                  color: CarserviceTheme.of(context).glassBorder,
                ),
              _OptionRow(
                key: ValueKey('booking-branch-${branch.id}'),
                title: branch.name,
                subtitle: _branchAddress(branch),
                selected: form.selectedBranch?.id == branch.id,
                radio: true,
                onTap: () => form.selectBranch(branch),
              ),
            ],
          ],
        ),
      );
    }
    return BookingStep(
      number: number,
      title: 'Салбар',
      complete: form.selectedBranch != null,
      child: child,
    );
  }

  static String? _branchAddress(BranchDetail branch) {
    final address = [
      branch.district,
      branch.fullAddress,
    ].where((part) => part.trim().isNotEmpty).join(', ');
    return address.isEmpty ? null : address;
  }
}

/// A selectable row — a check (multi-select) or radio (single) on the right.
class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.radio = false,
    super.key,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final bool radio;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    return Semantics(
      checked: radio ? null : selected,
      inMutuallyExclusiveGroup: radio ? true : null,
      selected: radio ? selected : null,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(fontSize: 12, color: theme.mutedText),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _SelectionMark(selected: selected, radio: radio),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectionMark extends StatelessWidget {
  const _SelectionMark({required this.selected, required this.radio});

  final bool selected;
  final bool radio;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    final shape = radio
        ? const CircleBorder()
        : RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.small));
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 22,
      height: 22,
      decoration: ShapeDecoration(
        color: selected ? AppColors.accent : Colors.transparent,
        shape: radio
            ? CircleBorder(
                side: selected
                    ? BorderSide.none
                    : BorderSide(color: theme.mutedText, width: 1.5),
              )
            : RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.small),
                side: selected
                    ? BorderSide.none
                    : BorderSide(color: theme.mutedText, width: 1.5),
              ),
      ),
      child: !selected
          ? null
          : radio
          ? Center(
              child: Container(
                width: 8,
                height: 8,
                decoration: ShapeDecoration(
                  color: AppColors.onAccent,
                  shape: shape,
                ),
              ),
            )
          : const Icon(
              Icons.check_rounded,
              size: 16,
              color: AppColors.onAccent,
            ),
    );
  }
}

/// Цагийн алхам: ачаалж байна / алдаа (дахин оролдох) / хаалттай өдөр / тор.
class BookingSlotSection extends StatelessWidget {
  const BookingSlotSection({
    required this.form,
    required this.number,
    super.key,
  });

  final BookingFormController form;
  final int number;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final availability = form.availability;
    final slotsError = form.slotsError;
    final Widget content;
    if (form.selectedDate == null) {
      content = const BookingStepHint(
        text: 'Өдрөө сонгоход тухайн өдрийн сул цагууд гарна.',
      );
    } else if (form.loadingSlots) {
      content = const GlassSurface(
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    } else if (slotsError != null) {
      content = GlassSurface(
        child: Row(
          children: [
            Icon(Icons.cloud_off_outlined, size: 20, color: scheme.error),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                slotsError,
                style: TextStyle(fontSize: 13, color: scheme.error),
              ),
            ),
            TextButton(
              key: const ValueKey('booking-slots-retry'),
              onPressed: form.loadAvailability,
              child: const Text('Дахин оролдох'),
            ),
          ],
        ),
      );
    } else if (availability != null && !availability.open) {
      content = BookingStepHint(
        text: availability.reason ?? 'Энэ өдөр хаалттай.',
      );
    } else {
      content = GlassSurface(
        child: TimeSlotGrid(
          slots: availability?.slots ?? const [],
          selected: form.selectedSlot,
          onSelected: form.selectSlot,
        ),
      );
    }
    return BookingStep(
      number: number,
      title: 'Цаг',
      complete: form.selectedSlot != null,
      trailing: availability != null && availability.open
          ? 'Нэг захиалга ≈ ${availability.durationMinutes} мин'
          : null,
      child: content,
    );
  }
}

/// The sticky bottom bar: what's been picked (or what's still missing),
/// any submit error, and the send button.
class BookingSummaryBar extends StatelessWidget {
  const BookingSummaryBar({
    required this.form,
    required this.onSubmit,
    super.key,
  });

  final BookingFormController form;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    final scheme = Theme.of(context).colorScheme;
    final hint = bookingNextStepHint(form);
    final count = form.selectedCategoryIds.length;
    final String label;
    final String value;
    if (hint != null) {
      label = 'Дараагийн алхам';
      value = hint;
    } else {
      label = count == 0
          ? 'Сонгосон цаг'
          : '$count үйлчилгээ · ~${bookingSelectedMinutes(form)} мин';
      value =
          '${bookingDateLabel(form.selectedDate!, DateTime.now())} · '
          '${_clock(form.selectedSlot!)}';
    }
    final error = form.error;
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        12 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: theme.shellSurface,
        border: Border(top: BorderSide(color: theme.glassBorder)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (error != null) ...[
            Semantics(
              liveRegion: true,
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 18,
                    color: scheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      error,
                      style: TextStyle(fontSize: 13, color: scheme.error),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Expanded(
                child: Column(
                  key: const ValueKey('booking-summary'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: theme.mutedText),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: hint == null ? null : theme.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              FilledButton.icon(
                key: const ValueKey('submit-booking'),
                onPressed: form.submitting ? null : onSubmit,
                icon: form.submitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_outlined, size: 18),
                // Short on purpose: the summary beside it needs the room, and
                // the title and footnote already say this is a request.
                label: Text(form.submitting ? 'Илгээж байна…' : 'Илгээх'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 52),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.large),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
