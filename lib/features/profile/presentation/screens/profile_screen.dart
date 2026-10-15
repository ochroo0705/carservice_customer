import 'package:carservice_customer/app/app_messages.dart';
import 'package:carservice_customer/app/theme/app_theme.dart';
import 'package:carservice_customer/app/theme/app_surfaces.dart';
import 'package:carservice_customer/core/widgets/offline_banner.dart';
import 'package:carservice_customer/core/widgets/skeletons.dart';
import 'package:carservice_customer/features/booking/auth/domain/account.dart';
import 'package:carservice_customer/features/booking/auth/presentation/auth_controller.dart';
import 'package:carservice_customer/features/vehicles/domain/vehicle.dart';
import 'package:carservice_customer/features/vehicles/presentation/controllers/vehicles_controller.dart';
import 'package:carservice_customer/features/vehicles/presentation/controllers/vehicles_state.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:carservice_customer/core/widgets/state_views.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    required this.onLoginRequested,
    required this.onAddVehicle,
    this.onVehicleSelected,
    this.onAccountClosureRequested,
    this.onPasswordSettingsRequested,
    this.onTermsRequested,
    this.onPrivacyRequested,
    super.key,
  });

  final VoidCallback onLoginRequested;
  final VoidCallback onAddVehicle;
  final ValueChanged<Vehicle>? onVehicleSelected;

  /// Opens the account-closure page on the router delegate's stack. The tile
  /// is hidden when null.
  final VoidCallback? onAccountClosureRequested;

  /// Opens the account password page (set/change/remove). The tile is hidden
  /// when null.
  final VoidCallback? onPasswordSettingsRequested;

  /// Open the bundled Үйлчилгээний нөхцөл / Нууцлалын бодлого pages. Each tile
  /// is hidden when its callback is null.
  final VoidCallback? onTermsRequested;
  final VoidCallback? onPrivacyRequested;

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();
    final isAuthenticated = authController.isAuthenticated;
    final controller = context.watch<VehiclesController>();
    return Scaffold(
      floatingActionButton: !isAuthenticated
          ? null
          : FloatingActionButton.extended(
              key: const ValueKey('profile-add-vehicle-fab'),
              onPressed: onAddVehicle,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Машин нэмэх'),
            ),
      body: AppShellBackground(
        child: SafeArea(
          child: isAuthenticated
              ? _ProfileBody(
                  controller: controller,
                  account: authController.account,
                  onSignOut: authController.signOut,
                  onVehicleSelected: onVehicleSelected,
                  onAccountClosureRequested: onAccountClosureRequested,
                  onPasswordSettingsRequested: onPasswordSettingsRequested,
                  onTermsRequested: onTermsRequested,
                  onPrivacyRequested: onPrivacyRequested,
                )
              : _UnauthenticatedPrompt(
                  onLoginRequested: onLoginRequested,
                  onTermsRequested: onTermsRequested,
                  onPrivacyRequested: onPrivacyRequested,
                ),
        ),
      ),
    );
  }
}

class _UnauthenticatedPrompt extends StatelessWidget {
  const _UnauthenticatedPrompt({
    required this.onLoginRequested,
    this.onTermsRequested,
    this.onPrivacyRequested,
  });

  final VoidCallback onLoginRequested;

  /// The legal pages stay readable before sign-in.
  final VoidCallback? onTermsRequested;
  final VoidCallback? onPrivacyRequested;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.person_outline_rounded,
            size: 58,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 18),
          Text(
            'Профайлаа харахын тулд нэвтэрнэ үү',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Таны мэдээлэл болон бүртгэсэн машинууд энд харагдана.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            key: const ValueKey('profile-login'),
            onPressed: onLoginRequested,
            icon: const Icon(Icons.login_rounded),
            label: const Text('Нэвтрэх'),
          ),
          if (onTermsRequested != null) ...[
            const SizedBox(height: 28),
            _ProfileLinkTile(
              key: const ValueKey('profile-terms-tile'),
              icon: Icons.description_outlined,
              label: 'Үйлчилгээний нөхцөл',
              onTap: onTermsRequested!,
            ),
          ],
          if (onPrivacyRequested != null) ...[
            const SizedBox(height: 12),
            _ProfileLinkTile(
              key: const ValueKey('profile-privacy-tile'),
              icon: Icons.privacy_tip_outlined,
              label: 'Нууцлалын бодлого',
              onTap: onPrivacyRequested!,
            ),
          ],
        ],
      ),
    ),
  );
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({
    required this.controller,
    required this.account,
    required this.onSignOut,
    this.onVehicleSelected,
    this.onAccountClosureRequested,
    this.onPasswordSettingsRequested,
    this.onTermsRequested,
    this.onPrivacyRequested,
  });

  final VehiclesController controller;
  final Account? account;
  final VoidCallback onSignOut;
  final ValueChanged<Vehicle>? onVehicleSelected;
  final VoidCallback? onAccountClosureRequested;
  final VoidCallback? onPasswordSettingsRequested;
  final VoidCallback? onTermsRequested;
  final VoidCallback? onPrivacyRequested;

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    final items = <Widget>[
      if (account != null) _ProfileHeader(account: account!, onSignOut: onSignOut),
      const _VehiclesHeader(),
      ...switch (state.status) {
        VehiclesStatus.initial || VehiclesStatus.loading => [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Semantics(
              container: true,
              liveRegion: true,
              label: 'Профайлыг ачаалж байна',
              child: const SkeletonCardColumn(),
            ),
          ),
        ],
        VehiclesStatus.error => [
          ErrorView(
            message: state.message ?? 'Тодорхойгүй алдаа гарлаа.',
            onRetry: controller.load,
            retryKey: const ValueKey('profile-retry'),
          ),
        ],
        VehiclesStatus.empty => const [
          EmptyView(
            icon: Icons.directions_car_outlined,
            title: 'Бүртгэсэн машин алга',
            message: 'Доорх товчоор шинэ машинаа бүртгүүлээрэй.',
          ),
        ],
        VehiclesStatus.data => [
          if (state.isFromCache)
            OfflineBanner(
              message: 'Сүлжээгүй байна — сүүлд ачаалсан машинуудыг харуулж байна',
              semanticsLabel:
                  'Сүлжээгүй байна. Сүүлд ачаалсан машинуудын жагсаалтыг харуулж байна.',
              retryKey: const ValueKey('profile-offline-retry'),
              onRetry: controller.load,
            ),
          for (final vehicle in state.vehicles)
            _VehicleCard(
              vehicle: vehicle,
              isDeleting: controller.isDeleting(vehicle.id),
              onDelete: () => _confirmDelete(context, controller, vehicle),
              onTap: onVehicleSelected == null ? null : () => onVehicleSelected!(vehicle),
            ),
        ],
      },
      if (account != null && onPasswordSettingsRequested != null)
        _ProfileLinkTile(
          key: const ValueKey('profile-password-tile'),
          icon: Icons.lock_outline,
          label: 'Нууц үг',
          onTap: onPasswordSettingsRequested!,
        ),
      if (onTermsRequested != null)
        _ProfileLinkTile(
          key: const ValueKey('profile-terms-tile'),
          icon: Icons.description_outlined,
          label: 'Үйлчилгээний нөхцөл',
          onTap: onTermsRequested!,
        ),
      if (onPrivacyRequested != null)
        _ProfileLinkTile(
          key: const ValueKey('profile-privacy-tile'),
          icon: Icons.privacy_tip_outlined,
          label: 'Нууцлалын бодлого',
          onTap: onPrivacyRequested!,
        ),
      if (account != null && onAccountClosureRequested != null)
        _AccountClosureTile(onTap: onAccountClosureRequested!),
    ];
    return RefreshIndicator(
      onRefresh: controller.load,
      child: ListView.separated(
        key: const PageStorageKey('profile-list'),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 96),
        itemCount: items.length,
        separatorBuilder: (_, index) => SizedBox(height: index == 0 ? 18 : 12),
        itemBuilder: (context, index) => items[index],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    VehiclesController controller,
    Vehicle vehicle,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Машин устгах уу?'),
        content: Text('${vehicle.make} ${vehicle.model} — ${vehicle.plate}'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Үгүй')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Тийм, устгах'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final error = await controller.delete(vehicle.id);
    if (error != null && context.mounted) {
      AppMessages.show(error);
    }
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.account, required this.onSignOut});

  final Account account;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = _displayLabel(account);
    final showPhoneSubtitle = label != account.phone;
    return GlassSurface(
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: scheme.primary,
            child: Text(
              label.substring(0, 1).toUpperCase(),
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(color: scheme.onPrimary, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                if (showPhoneSubtitle) ...[
                  const SizedBox(height: 2),
                  Text(
                    account.phone,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
          TextButton.icon(
            key: const ValueKey('profile-sign-out'),
            onPressed: onSignOut,
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Гарах'),
          ),
        ],
      ),
    );
  }
}

class _ProfileLinkTile extends StatelessWidget {
  const _ProfileLinkTile({required this.icon, required this.label, required this.onTap, super.key});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GlassSurface(
    onTap: onTap,
    child: Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Expanded(child: Text(label)),
        Icon(Icons.chevron_right_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant),
      ],
    ),
  );
}

class _AccountClosureTile extends StatelessWidget {
  const _AccountClosureTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GlassSurface(
    key: const ValueKey('profile-account-closure-tile'),
    onTap: onTap,
    child: Row(
      children: [
        Icon(Icons.person_off_outlined, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        const Expanded(child: Text('Бүртгэл хаах')),
        Icon(Icons.chevron_right_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant),
      ],
    ),
  );
}

String _displayLabel(Account account) {
  final name = account.name?.trim();
  return (name != null && name.isNotEmpty) ? name : account.phone;
}

class _VehiclesHeader extends StatelessWidget {
  const _VehiclesHeader();

  @override
  Widget build(BuildContext context) => Text(
    'Миний машинууд',
    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
  );
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({
    required this.vehicle,
    required this.isDeleting,
    required this.onDelete,
    this.onTap,
  });

  final Vehicle vehicle;
  final bool isDeleting;
  final VoidCallback onDelete;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GlassSurface(
    onTap: onTap,
    child: Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(AppRadii.medium),
          ),
          child: Icon(Icons.directions_car_outlined, color: Theme.of(context).colorScheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${vehicle.make} ${vehicle.model}',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  vehicle.year == null ? vehicle.plate : '${vehicle.plate} · ${vehicle.year}',
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                if (_vehicleFacts(vehicle).isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final fact in _vehicleFacts(vehicle))
                        Text(
                          fact,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  '${vehicle.serviceCount} үйлчилгээ · ${vehicle.diagnosisCount} оношилгоо',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
        Icon(Icons.chevron_right_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant),
        IconButton(
          key: ValueKey('delete-vehicle-${vehicle.id}'),
          onPressed: isDeleting ? null : onDelete,
          tooltip: 'Устгах',
          icon: isDeleting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(Icons.delete_outline_rounded, color: Theme.of(context).colorScheme.error),
        ),
      ],
    ),
  );
}

List<String> _vehicleFacts(Vehicle vehicle) => [
  if (vehicle.colorName != null) vehicle.colorName!,
  if (vehicle.fuelType != null) vehicle.fuelType!,
  if (vehicle.capacity != null) '${vehicle.capacity} см³',
  if (vehicle.wheelPosition != null) 'Хүрд: ${vehicle.wheelPosition}',
  if (vehicle.purpose != null) vehicle.purpose!,
];
