import 'package:carservice_customer/app/theme/app_theme.dart';
import 'package:flutter/material.dart';

class MapLoadingOverlay extends StatelessWidget {
  const MapLoadingOverlay({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    liveRegion: true,
    label: 'Газрын зураг ачаалж байна',
    child: ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 14),
            Text('Газрын зураг ачаалж байна…'),
          ],
        ),
      ),
    ),
  );
}

class MapFailureOverlay extends StatelessWidget {
  const MapFailureOverlay({
    required this.onRetry,
    required this.onShowList,
    super.key,
  });

  final VoidCallback onRetry;
  final VoidCallback onShowList;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    liveRegion: true,
    label: 'Газрын зураг ачаалсангүй',
    child: ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.map_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 14),
              Text(
                'Газрын зураг ачаалсангүй',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 7),
              Text(
                'Сервисүүдийг жагсаалтаар харах эсвэл дахин оролдоно уу.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                key: const ValueKey('map-show-list'),
                onPressed: onShowList,
                icon: const Icon(Icons.view_list_outlined),
                label: const Text('Жагсаалтаар харах'),
              ),
              TextButton.icon(
                key: const ValueKey('map-retry'),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Дахин оролдох'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class MapUnavailableOverlay extends StatelessWidget {
  const MapUnavailableOverlay({required this.onShowList, super.key});

  final VoidCallback onShowList;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    liveRegion: true,
    label: 'Газрын зураг энэ хувилбарт тохируулагдаагүй байна',
    child: ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.map_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 14),
              Text(
                'Газрын зураг ашиглах боломжгүй байна',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 7),
              Text(
                'Энэ хувилбарт газрын зургийн тохиргоо дутуу байна. Сервисүүдийг жагсаалтаар харна уу.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                key: const ValueKey('map-unavailable-show-list'),
                onPressed: onShowList,
                icon: const Icon(Icons.view_list_outlined),
                label: const Text('Жагсаалтаар харах'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// A note floating over an empty viewport. Ignores touches, so the map
/// under it still pans and zooms — the way out of an empty area.
class NoMapLocations extends StatelessWidget {
  const NoMapLocations({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    return IgnorePointer(
      child: Semantics(
        container: true,
        liveRegion: true,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: theme.shellSurface,
            border: Border.all(color: theme.glassBorder),
            borderRadius: BorderRadius.circular(AppRadii.large),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_off_outlined, color: theme.mutedText),
              const SizedBox(height: 8),
              const Text(
                'Энэ хэсэгт сервис олдсонгүй',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'Газрын зургийг хөдөлгөх эсвэл шүүлтүүрээ өөрчилж үзээрэй.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: theme.mutedText),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
