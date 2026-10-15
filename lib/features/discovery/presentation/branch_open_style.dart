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
