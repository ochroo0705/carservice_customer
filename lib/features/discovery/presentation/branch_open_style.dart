import 'package:carservice_customer/app/theme/app_theme.dart';
import 'package:carservice_customer/features/discovery/domain/branch.dart';
import 'package:flutter/material.dart';

/// Base color for a branch's open/closed state (unknown → muted).
Color branchOpenColor(BranchOpenStatus status, BuildContext context) =>
    switch (status) {
      BranchOpenStatus.open => AppColors.green,
      BranchOpenStatus.closed => AppColors.red,
      BranchOpenStatus.unknown => Theme.of(
        context,
      ).colorScheme.onSurfaceVariant,
    };

/// The clause after the open/closed label on a branch's status line —
/// "18:00 хүртэл" while open, "11:00-д нээгдэнэ" or "Маргааш 09:00-д
/// нээгдэнэ" while closed — or null when the hours don't say.
///
/// [status] must be `branch.openStatusAt(now)`; like that, it reads the
/// clock from [now] as-is against the business day's resolved hours.
String? branchOpenHint(
  BranchDetail branch,
  BranchOpenStatus status,
  DateTime now,
) {
  switch (status) {
    case BranchOpenStatus.unknown:
      return null;
    case BranchOpenStatus.open:
      final closing = branch.effectiveScheduleAt(now).closeTime;
      return _clockMinutes(closing) == null ? null : '$closing хүртэл';
    case BranchOpenStatus.closed:
      final today = branch.effectiveScheduleAt(now);
      final opening = _clockMinutes(today.openTime);
      if (today.isOpen &&
          opening != null &&
          opening > now.hour * 60 + now.minute) {
        return '${today.openTime}-д нээгдэнэ';
      }
      final tomorrow = branch.effectiveScheduleAt(
        now.add(const Duration(days: 1)),
      );
      if (tomorrow.isOpen && _clockMinutes(tomorrow.openTime) != null) {
        return 'Маргааш ${tomorrow.openTime}-д нээгдэнэ';
      }
      return null;
  }
}

int? _clockMinutes(String? value) {
  final match = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(value?.trim() ?? '');
  if (match == null) return null;
  final hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2)!);
  if (hour > 23 || minute > 59) return null;
  return hour * 60 + minute;
}
