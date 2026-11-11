import 'package:carservice_customer/app/theme/app_theme.dart';
import 'package:carservice_customer/core/widgets/cs_ui.dart';
import 'package:flutter/material.dart';

/// `lockCategories` урсгал үргэлжлэх боломжгүй үеийн бүтэн дэлгэцийн мэдэгдэл
/// (салбар олдоогүй, эсвэл сонгосон ангилал БҮГД цаашид энэ салбарт байхгүй
/// болсон) — цаашаа явахгүй, буцаж дахин сонгуулна.
class LockedFlowUnavailable extends StatelessWidget {
  const LockedFlowUnavailable({
    super.key,
    required this.branchMissing,
    required this.onBack,
  });

  final bool branchMissing;
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
              icon: Icons.info_outline_rounded,
              size: 56,
              background: theme.card,
              color: theme.mutedText,
            ),
            const SizedBox(height: 16),
            Text(
              branchMissing
                  ? 'Сонгосон салбар олдсонгүй. Дахин сонгоно уу.'
                  : 'Сонгосон бүх үйлчилгээг энэ салбар цаашид санал болгохгүй '
                        'боллоо. Дахин сонгоно уу.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: theme.ink, height: 1.4),
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: onBack,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 28),
              ),
              child: const Text('Буцах'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Хэсэгчлэн боломжгүй болсон ангиллуудыг сануулах — блокдоггүй, зөвхөн
/// мэдээлнэ (боломжтой хэсгээр захиалга үргэлжилнэ).
class LockedCategoriesWarning extends StatelessWidget {
  const LockedCategoriesWarning({super.key, required this.unavailableNames});

  final List<String> unavailableNames;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    final color = AppColors.readable(
      AppColors.warning,
      Theme.of(context).brightness,
    );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.warningSoft,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Энэ салбар цаашид дараах үйлчилгээг санал болгохгүй тул '
              'захиалгаас хасагдлаа: ${unavailableNames.join(', ')}.',
              style: TextStyle(fontSize: 13, color: color, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
