import 'dart:ui' show ImageFilter;

import 'package:carservice_customer/app/theme/app_theme.dart';
import 'package:carservice_customer/core/widgets/cs_ui.dart';
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

/// One step of the booking form (CustBook): a Geist Mono uppercase section
/// label ("ҮЙЛЧИЛГЭЭ", "ӨДӨР", "ЦАГ"), a small check once the step is done,
/// an optional muted summary on the right, and the step's controls below.
/// [number] is kept for callers that count steps; the design shows none.
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
    final done = AppColors.readable(
      AppColors.green,
      Theme.of(context).brightness,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Row(
            children: [
              CsSectionLabel(title),
              if (complete) ...[
                const SizedBox(width: 6),
                Icon(
                  Icons.check_circle_rounded,
                  size: 13,
                  color: done,
                  semanticLabel: 'Сонгосон',
                ),
              ],
              const Spacer(),
              if (trailing != null)
                Flexible(
                  flex: 4,
                  child: Text(
                    trailing!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: TextStyle(fontSize: 13, color: theme.mutedText),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        child,
      ],
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: theme.cardBorder),
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
          child: CsCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final (index, category) in categories.indexed) ...[
                  if (index > 0) const _RowDivider(),
                  _OptionRow(
                    key: ValueKey('booking-category-${category.id}'),
                    title: category.name,
                    meta: '~${category.durationMinutes} мин',
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
      child = CsCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (final (index, branch) in compatible.indexed) ...[
              if (index > 0) const _RowDivider(),
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

/// The hairline between rows of a service/branch card.
class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) =>
      Divider(height: 1, color: CarserviceTheme.of(context).shellBackground);
}

/// A selectable card row (CustBook): a 22px rounded check (multi-select) or
/// radio (single) on the left, the title, then an optional Geist Mono [meta]
/// on the right and a muted [subtitle] below.
class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.meta,
    this.radio = false,
    super.key,
  });

  final String title;
  final String? subtitle;
  final String? meta;
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
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                _SelectionMark(selected: selected, radio: radio),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: selected
                              ? FontWeight.w500
                              : FontWeight.w400,
                          color: theme.ink,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.mutedText,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (meta != null) ...[
                  const SizedBox(width: 12),
                  Text(
                    meta!,
                    style: csMono(
                      fontSize: 13,
                      color: selected ? theme.ink : theme.mutedText,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Checked = inverse (navy) fill with a white check; unchecked = a 2px
/// muted outline. Radios are circles with a dot.
class _SelectionMark extends StatelessWidget {
  const _SelectionMark({required this.selected, required this.radio});

  final bool selected;
  final bool radio;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    final outline = selected
        ? BorderSide.none
        : BorderSide(color: theme.mutedText.withValues(alpha: 0.55), width: 2);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 22,
      height: 22,
      decoration: ShapeDecoration(
        color: selected ? theme.inverse : Colors.transparent,
        shape: radio
            ? CircleBorder(side: outline)
            : RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(7),
                side: outline,
              ),
      ),
      child: !selected
          ? null
          : radio
          ? Center(
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: theme.onInverse,
                  shape: BoxShape.circle,
                ),
              ),
            )
          : Icon(Icons.check_rounded, size: 15, color: theme.onInverse),
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
      content = const CsCard(
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    } else if (slotsError != null) {
      content = CsCard(
        padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
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
      content = TimeSlotGrid(
        slots: availability?.slots ?? const [],
        selected: form.selectedSlot,
        onSelected: form.selectSlot,
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

/// The sticky bottom bar (CustBook): a translucent blurred card strip with
/// what's been picked — "date time · N үйлчилгээ" over the Geist Mono
/// "~X мин" duration (there is no price data) — or what's still missing,
/// any submit error, and the primary "Захиалах" button.
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    final hint = bookingNextStepHint(form);
    final count = form.selectedCategoryIds.length;
    final String label;
    final String value;
    var monoValue = false;
    if (hint != null) {
      label = 'Дараагийн алхам';
      value = hint;
    } else {
      final date = bookingDateLabel(form.selectedDate!, DateTime.now());
      final clock = _clock(form.selectedSlot!);
      if (count == 0) {
        label = 'Сонгосон цаг';
        value = '$date · $clock';
      } else {
        label = '$date $clock · $count үйлчилгээ';
        value = '~${bookingSelectedMinutes(form)} мин';
        monoValue = true;
      }
    }
    final error = form.error;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            20,
            14,
            20,
            14 + MediaQuery.paddingOf(context).bottom,
          ),
          decoration: BoxDecoration(
            color: theme.card.withValues(alpha: dark ? 0.92 : 0.9),
            border: Border(top: BorderSide(color: theme.cardBorder)),
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
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.mutedText,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: monoValue
                              ? csMono(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  color: theme.ink,
                                )
                              : TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: hint == null
                                      ? theme.ink
                                      : theme.mutedText,
                                ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  FilledButton(
                    key: const ValueKey('submit-booking'),
                    onPressed: form.submitting ? null : onSubmit,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 54),
                      padding: const EdgeInsets.symmetric(horizontal: 26),
                    ),
                    child: form.submitting
                        ? const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text('Илгээж байна…'),
                            ],
                          )
                        // Still a request: the service confirms it later, as
                        // the footnote above the bar says.
                        : const Text('Захиалах'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
