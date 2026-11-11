import 'package:carservice_customer/app/app_messages.dart';
import 'package:carservice_customer/app/theme/app_theme.dart';
import 'package:carservice_customer/app/theme/theme_controller.dart';
import 'package:carservice_customer/core/widgets/cs_ui.dart';
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
      backgroundColor: CarserviceTheme.of(context).shellBackground,
      body: SafeArea(
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
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    final rows = <Widget>[
      if (onTermsRequested != null)
        _SettingsRow(
          key: const ValueKey('profile-terms-tile'),
          icon: Icons.description_outlined,
          label: 'Үйлчилгээний нөхцөл',
          onTap: onTermsRequested!,
        ),
      if (onPrivacyRequested != null)
        _SettingsRow(
          key: const ValueKey('profile-privacy-tile'),
          icon: Icons.privacy_tip_outlined,
          label: 'Нууцлалын бодлого',
          onTap: onPrivacyRequested!,
        ),
    ];
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: CsIconTile(icon: Icons.person_outline_rounded, size: 64)),
            const SizedBox(height: 18),
            Text(
              'Профайлаа харахын тулд нэвтэрнэ үү',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.44,
                color: theme.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Таны мэдээлэл болон бүртгэсэн машинууд энд харагдана.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: theme.mutedText),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              key: const ValueKey('profile-login'),
              onPressed: onLoginRequested,
              icon: const Icon(Icons.login_rounded),
              label: const Text('Нэвтрэх'),
            ),
            if (rows.isNotEmpty) ...[
              const SizedBox(height: 28),
              const CsSectionLabel('Мэдээлэл'),
              const SizedBox(height: 8),
              _SettingsGroup(children: rows),
            ],
          ],
        ),
      ),
    );
  }
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
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const CsSectionLabel('Тохиргоо'),
            const SizedBox(height: 8),
            _SettingsGroup(
              children: [
                if (context.watch<ThemeController?>() != null) const _AppearanceRow(),
                if (account != null && onPasswordSettingsRequested != null)
                  _SettingsRow(
                    key: const ValueKey('profile-password-tile'),
                    icon: Icons.lock_outline,
                    label: 'Нууц үг',
                    onTap: onPasswordSettingsRequested!,
                  ),
                if (onTermsRequested != null)
                  _SettingsRow(
                    key: const ValueKey('profile-terms-tile'),
                    icon: Icons.description_outlined,
                    label: 'Үйлчилгээний нөхцөл',
                    onTap: onTermsRequested!,
                  ),
                if (onPrivacyRequested != null)
                  _SettingsRow(
                    key: const ValueKey('profile-privacy-tile'),
                    icon: Icons.privacy_tip_outlined,
                    label: 'Нууцлалын бодлого',
                    onTap: onPrivacyRequested!,
                  ),
                if (account != null && onAccountClosureRequested != null)
                  _SettingsRow(
                    key: const ValueKey('profile-account-closure-tile'),
                    icon: Icons.person_off_outlined,
                    label: 'Бүртгэл хаах',
                    destructive: true,
                    onTap: onAccountClosureRequested!,
                  ),
              ],
            ),
          ],
        ),
      ),
    ];
    return RefreshIndicator(
      onRefresh: controller.load,
      child: ListView.separated(
        key: const PageStorageKey('profile-list'),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 112),
        itemCount: items.length,
        separatorBuilder: (_, index) => SizedBox(height: index == 0 ? 22 : 10),
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
    final theme = CarserviceTheme.of(context);
    final label = _displayLabel(account);
    final showPhoneSubtitle = label != account.phone;
    return CsHeroCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(AppRadii.control),
            ),
            child: Text(
              _initials(label),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: theme.onHero),
                ),
                if (showPhoneSubtitle) ...[
                  const SizedBox(height: 3),
                  Text(account.phone, style: csMono(fontSize: 13, color: theme.onHeroMuted)),
                ],
              ],
            ),
          ),
          TextButton.icon(
            key: const ValueKey('profile-sign-out'),
            onPressed: onSignOut,
            style: TextButton.styleFrom(foregroundColor: theme.onHero),
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Гарах'),
          ),
        ],
      ),
    );
  }
}

String _initials(String label) {
  final words = label.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return '?';
  return words.take(2).map((w) => w.characters.first.toUpperCase()).join();
}

/// A grouped settings card: rows separated by hairlines.
class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    return CsCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: theme.cardBorder),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 20, color: destructive ? theme.link : theme.mutedText),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: destructive ? theme.link : theme.ink,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: theme.mutedText),
            ],
          ),
        ),
      ),
    );
  }
}

/// Харагдах байдал: system / light / dark, persisted by [ThemeController]
/// (it replaces the toggle that used to sit in the shell's app bar).
class _AppearanceRow extends StatelessWidget {
  const _AppearanceRow();

  static const _options = [
    (ThemeMode.system, 'Систем', Icons.brightness_auto_outlined),
    (ThemeMode.light, 'Цайвар', Icons.light_mode_outlined),
    (ThemeMode.dark, 'Бараан', Icons.dark_mode_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ThemeController>();
    final theme = CarserviceTheme.of(context);
    return Padding(
      key: const ValueKey('profile-appearance'),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.contrast_rounded, size: 20, color: theme.mutedText),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Харагдах байдал',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: theme.ink),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (mode, label, icon) in _options)
                Semantics(
                  selected: controller.mode == mode,
                  child: CsChoicePill(
                    key: ValueKey('profile-theme-${mode.name}'),
                    label: label,
                    icon: icon,
                    selected: controller.mode == mode,
                    onTap: () => controller.setMode(mode),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
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
    style: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.22,
      color: CarserviceTheme.of(context).ink,
    ),
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
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    final facts = _vehicleFacts(vehicle);
    return CsCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 14, 4, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CsIconTile(icon: Icons.directions_car_outlined, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${vehicle.make} ${vehicle.model}',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: theme.ink),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    CsPlate(vehicle.plate, fontSize: 12),
                    if (vehicle.year != null)
                      Text('${vehicle.year}', style: csMono(fontSize: 12, color: theme.mutedText)),
                  ],
                ),
                if (facts.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(facts.join(' · '), style: TextStyle(fontSize: 12, color: theme.mutedText)),
                ],
                const SizedBox(height: 6),
                Text(
                  '${vehicle.serviceCount} үйлчилгээ · ${vehicle.diagnosisCount} оношилгоо',
                  style: csMono(fontSize: 11, color: theme.mutedText),
                ),
              ],
            ),
          ),
          IconButton(
            key: ValueKey('delete-vehicle-${vehicle.id}'),
            onPressed: isDeleting ? null : onDelete,
            tooltip: 'Устгах',
            icon: isDeleting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(Icons.delete_outline_rounded, color: theme.link),
          ),
        ],
      ),
    );
  }
}

List<String> _vehicleFacts(Vehicle vehicle) => [
  if (vehicle.colorName != null) vehicle.colorName!,
  if (vehicle.fuelType != null) vehicle.fuelType!,
  if (vehicle.capacity != null) '${vehicle.capacity} см³',
  if (vehicle.wheelPosition != null) 'Хүрд: ${vehicle.wheelPosition}',
  if (vehicle.purpose != null) vehicle.purpose!,
];
