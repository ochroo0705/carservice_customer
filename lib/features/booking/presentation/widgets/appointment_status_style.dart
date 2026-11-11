import 'package:carservice_customer/app/theme/app_theme.dart';
import 'package:carservice_customer/features/booking/domain/appointment_status.dart';
import 'package:carservice_customer/features/booking/domain/service_progress.dart';
import 'package:flutter/material.dart';
import 'package:carservice_customer/core/widgets/cs_ui.dart' show CsTone;

Color appointmentStatusColor(AppointmentStatus status, BuildContext context) =>
    switch (status) {
      AppointmentStatus.confirmed => AppColors.green,
      AppointmentStatus.pending => AppColors.blue,
      AppointmentStatus.rejected ||
      AppointmentStatus.cancelled => AppColors.red,
      AppointmentStatus.noShow || AppointmentStatus.unknown => Theme.of(
        context,
      ).colorScheme.onSurfaceVariant,
    };

Color serviceProgressStatusColor(
  ServiceProgressStatus status,
  BuildContext context,
) => switch (status) {
  ServiceProgressStatus.completed => AppColors.green,
  ServiceProgressStatus.cancelled => AppColors.red,
  ServiceProgressStatus.inProgress => AppColors.blue,
  ServiceProgressStatus.postponed => AppColors.purple,
  ServiceProgressStatus.pending ||
  ServiceProgressStatus.scheduled ||
  ServiceProgressStatus.unknown => Theme.of(
    context,
  ).colorScheme.onSurfaceVariant,
};

/// [CsBadge] tone for an appointment status (2026-11 design): pending is
/// informational, confirmed is good news, rejected stands out in accent and
/// the closed states stay neutral.
CsTone appointmentStatusTone(AppointmentStatus status) => switch (status) {
  AppointmentStatus.confirmed => CsTone.success,
  AppointmentStatus.pending => CsTone.info,
  AppointmentStatus.rejected => CsTone.accent,
  AppointmentStatus.cancelled ||
  AppointmentStatus.noShow ||
  AppointmentStatus.unknown => CsTone.neutral,
};

/// [CsBadge] tone for a service-order (repair) status.
CsTone serviceProgressStatusTone(ServiceProgressStatus status) =>
    switch (status) {
      ServiceProgressStatus.completed => CsTone.success,
      ServiceProgressStatus.inProgress => CsTone.info,
      ServiceProgressStatus.postponed => CsTone.warning,
      ServiceProgressStatus.cancelled => CsTone.neutral,
      ServiceProgressStatus.pending ||
      ServiceProgressStatus.scheduled ||
      ServiceProgressStatus.unknown => CsTone.neutral,
    };
