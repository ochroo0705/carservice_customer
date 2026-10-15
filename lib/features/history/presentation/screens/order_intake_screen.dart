import 'package:carservice_customer/app/theme/app_surfaces.dart';
import 'package:carservice_customer/features/history/domain/order_intake.dart';
import 'package:carservice_customer/features/history/domain/upload_url.dart';
import 'package:flutter/material.dart';

String _formatRecordedAt(DateTime t) =>
    '${t.year}.${t.month.toString().padLeft(2, '0')}.${t.day.toString().padLeft(2, '0')} '
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

Widget _networkImage(
  String url, {
  BoxFit fit = BoxFit.cover,
  String? baseUrl,
}) => Image.network(
  resolveUploadUrl(url, baseUrl: baseUrl),
  fit: fit,
  errorBuilder: (context, _, _) => Center(
    child: Icon(
      Icons.broken_image_outlined,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
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
        child: _IntakePhotoPager(
          photos: intake.photos,
          initialIndex: index,
          baseUrl: baseUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final signature = intake.signatureUrl;
    return Scaffold(
      appBar: AppBar(title: const Text('Хүлээн авах')),
      body: AppShellBackground(
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Бүртгэсэн: ${_formatRecordedAt(intake.recordedAt)}',
                style: textTheme.bodySmall,
              ),
              if (intake.mileageLabel != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Гүйлт: ${intake.mileageLabel}',
                  key: const ValueKey('intake-mileage'),
                  style: textTheme.bodyMedium,
                ),
              ],
              if (intake.hasNotes) ...[
                const SizedBox(height: 12),
                GlassSurface(child: Text(intake.notes!)),
              ],
              if (intake.photos.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Зураг',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
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
                      borderRadius: BorderRadius.circular(8),
                      child: _networkImage(
                        intake.photos[i].url,
                        baseUrl: baseUrl,
                      ),
                    ),
                  ),
                ),
              ],
              if (signature != null) ...[
                const SizedBox(height: 16),
                Text(
                  'Гарын үсэг',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 140,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: _networkImage(
                    signature,
                    fit: BoxFit.contain,
                    baseUrl: baseUrl,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _IntakePhotoPager extends StatefulWidget {
  const _IntakePhotoPager({
    required this.photos,
    required this.initialIndex,
    this.baseUrl,
  });

  final List<OrderIntakePhoto> photos;
  final int initialIndex;
  final String? baseUrl;

  @override
  State<_IntakePhotoPager> createState() => _IntakePhotoPagerState();
}

class _IntakePhotoPagerState extends State<_IntakePhotoPager> {
  late final PageController _controller = PageController(
    initialPage: widget.initialIndex,
  );
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
          child: _networkImage(
            widget.photos[i].url,
            fit: BoxFit.contain,
            baseUrl: widget.baseUrl,
          ),
        ),
      ),
    ),
  );
}
