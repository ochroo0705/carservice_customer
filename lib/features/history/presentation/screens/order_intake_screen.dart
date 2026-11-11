import 'package:carservice_customer/core/widgets/cs_ui.dart';
import 'package:carservice_customer/features/history/domain/order_intake.dart';
import 'package:carservice_customer/features/history/domain/upload_url.dart';
import 'package:flutter/material.dart';
import 'package:carservice_customer/app/theme/app_theme.dart';

String _formatRecordedAt(DateTime t) =>
    '${t.year}.${t.month.toString().padLeft(2, '0')}.${t.day.toString().padLeft(2, '0')} '
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

Widget _networkImage(String url, {BoxFit fit = BoxFit.cover, String? baseUrl}) => Image.network(
  resolveUploadUrl(url, baseUrl: baseUrl),
  fit: fit,
  errorBuilder: (context, _, _) => Center(
    child: Icon(Icons.broken_image_outlined, color: Theme.of(context).colorScheme.onSurfaceVariant),
  ),
);

/// «Хүлээн авах» бүртгэлийн бүтэн дэлгэц (зөвхөн унших).
class OrderIntakeScreen extends StatelessWidget {
  const OrderIntakeScreen({required this.intake, this.baseUrl, super.key});

  final OrderIntake intake;

  /// Тестэд origin-г заахад; үгүй бол апп-ын API тохиргоо.
  final String? baseUrl;

  void _openPhoto(BuildContext context, int index) {
    // Түр зуурын бүтэн дэлгэцийн харагдац — чиглэл биш тул dialog.
    showDialog<void>(
      context: context,
      useSafeArea: false,
      builder: (_) => Dialog.fullscreen(
        child: _IntakePhotoPager(photos: intake.photos, initialIndex: index, baseUrl: baseUrl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    final signature = intake.signatureUrl;
    return Scaffold(
      backgroundColor: theme.shellBackground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                children: [
                  CsCircleButton.back(context),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Хүлээн авах',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: theme.ink),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  CsCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Бүртгэсэн: ${_formatRecordedAt(intake.recordedAt)}',
                          style: TextStyle(fontSize: 13, color: theme.mutedText),
                        ),
                        if (intake.mileageLabel != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Гүйлт: ${intake.mileageLabel}',
                            key: const ValueKey('intake-mileage'),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: theme.ink,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (intake.hasNotes) ...[
                    const SizedBox(height: 10),
                    CsCard(
                      child: Text(
                        intake.notes!,
                        style: TextStyle(fontSize: 14, color: theme.ink, height: 1.4),
                      ),
                    ),
                  ],
                  if (intake.photos.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    const CsSectionHeader('Зураг'),
                    const SizedBox(height: 8),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                      ),
                      itemCount: intake.photos.length,
                      itemBuilder: (context, i) => GestureDetector(
                        key: ValueKey('intake-photo-$i'),
                        onTap: () => _openPhoto(context, i),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadii.large),
                          child: ColoredBox(
                            color: theme.card,
                            child: _networkImage(intake.photos[i].url, baseUrl: baseUrl),
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (signature != null) ...[
                    const SizedBox(height: 22),
                    const CsSectionHeader('Гарын үсэг'),
                    const SizedBox(height: 8),
                    // Always white: the signature is dark ink on transparency.
                    Container(
                      height: 140,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadii.card),
                        border: Border.all(color: theme.cardBorder),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: _networkImage(signature, fit: BoxFit.contain, baseUrl: baseUrl),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntakePhotoPager extends StatefulWidget {
  const _IntakePhotoPager({required this.photos, required this.initialIndex, this.baseUrl});

  final List<OrderIntakePhoto> photos;
  final int initialIndex;
  final String? baseUrl;

  @override
  State<_IntakePhotoPager> createState() => _IntakePhotoPagerState();
}

class _IntakePhotoPagerState extends State<_IntakePhotoPager> {
  late final PageController _controller = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      title: Text('${_index + 1} / ${widget.photos.length}'),
    ),
    body: PageView.builder(
      controller: _controller,
      itemCount: widget.photos.length,
      onPageChanged: (i) => setState(() => _index = i),
      itemBuilder: (context, i) => InteractiveViewer(
        child: Center(
          child: _networkImage(widget.photos[i].url, fit: BoxFit.contain, baseUrl: widget.baseUrl),
        ),
      ),
    ),
  );
}
