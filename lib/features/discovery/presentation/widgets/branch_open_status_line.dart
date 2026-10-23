import 'package:carservice_customer/app/theme/app_theme.dart';
import 'package:carservice_customer/features/discovery/domain/branch.dart';
import 'package:carservice_customer/features/discovery/presentation/branch_open_style.dart';
import 'package:flutter/material.dart';

/// "● Хаалттай · 11:00-д нээгдэнэ" — a branch's open state right now from
/// its loaded hours, plus when that changes next. Shared by the map's
/// branch sheet and the detail page.
class BranchOpenStatusLine extends StatelessWidget {
  const BranchOpenStatusLine({required this.branch, super.key});

  final BranchDetail branch;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final status = branch.openStatusAt(now);
    final color = branchOpenColor(status, context);
    final label = switch (status) {
      BranchOpenStatus.open => 'Нээлттэй',
      BranchOpenStatus.closed => 'Хаалттай',
      BranchOpenStatus.unknown => 'Төлөв тодорхойгүй',
    };
    final hint = branchOpenHint(branch, status, now);
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: label,
                  style: TextStyle(
                    color: AppColors.readable(
                      color,
                      Theme.of(context).brightness,
                    ),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (hint != null) TextSpan(text: ' · $hint'),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: CarserviceTheme.of(context).mutedText,
            ),
          ),
        ),
      ],
    );
  }
}
