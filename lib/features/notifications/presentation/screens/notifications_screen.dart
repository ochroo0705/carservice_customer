import 'package:carservice_customer/app/theme/app_theme.dart';
import 'package:carservice_customer/core/widgets/cs_ui.dart';
import 'package:carservice_customer/core/widgets/animations.dart';
import 'package:carservice_customer/core/widgets/coming_soon_view.dart';
import 'package:carservice_customer/core/widgets/skeletons.dart';
import 'package:carservice_customer/features/notifications/domain/app_notification.dart';
import 'package:carservice_customer/features/notifications/presentation/controllers/notifications_controller.dart';
import 'package:carservice_customer/features/notifications/presentation/controllers/notifications_state.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:carservice_customer/core/widgets/state_views.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({required this.onBack, required this.onOpen, super.key});

  final VoidCallback onBack;

  /// Deep-links the tapped notification (router wiring decides where, from the
  /// same `data` map a push tap carries). A notification with nothing routable
  /// — a broadcast, say — simply stays on this screen.
  final void Function(AppNotification notification) onOpen;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<NotificationsController>();
    final theme = CarserviceTheme.of(context);
    return Scaffold(
      backgroundColor: theme.shellBackground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
              child: Row(
                children: [
                  CsCircleButton.back(context, onPressed: onBack),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Мэдэгдэл',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: theme.ink),
                    ),
                  ),
                  // The server's unread total, not the loaded page's: with more
                  // than one page of notifications the unread ones can all sit
                  // below the first page, which would show a bell badge with no
                  // way to clear it.
                  if (controller.unreadCount > 0)
                    TextButton(
                      onPressed: controller.markAllRead,
                      style: TextButton.styleFrom(foregroundColor: theme.link),
                      child: const Text('Бүгдийг уншсан'),
                    ),
                ],
              ),
            ),
            Expanded(
              child: _Body(controller: controller, onOpen: onOpen),
            ),
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.controller, required this.onOpen});

  final NotificationsController controller;
  final void Function(AppNotification notification) onOpen;

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    return switch (state.status) {
      NotificationsStatus.initial ||
      NotificationsStatus.loading => const SkeletonNotificationList(),
      NotificationsStatus.error => ErrorView(
        message: state.message ?? 'Тодорхойгүй алдаа гарлаа.',
        onRetry: controller.load,
      ),
      NotificationsStatus.empty => const EmptyView(
        icon: Icons.notifications_none_rounded,
        title: 'Мэдэгдэл алга',
      ),
      NotificationsStatus.unavailable => const ComingSoonView(
        icon: Icons.notifications_none_rounded,
        title: 'Тун удахгүй',
        message: 'Мэдэгдлийн жагсаалт удахгүй нэмэгдэнэ.',
      ),
      NotificationsStatus.data => _NotificationsList(controller: controller, onOpen: onOpen),
    };
  }
}

class _NotificationsList extends StatelessWidget {
  const _NotificationsList({required this.controller, required this.onOpen});

  final NotificationsController controller;
  final void Function(AppNotification notification) onOpen;

  @override
  Widget build(BuildContext context) {
    final notifications = controller.state.notifications;
    return RefreshIndicator(
      onRefresh: controller.load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        itemCount: notifications.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final notification = notifications[index];
          return RiseIn(
            index: index,
            child: _NotificationCard(
              notification: notification,
              // Read rows stay tappable — opening the thing a notification is
              // about is useful long after it has been read.
              onTap: () {
                if (!notification.isRead) controller.markRead(notification.id);
                onOpen(notification);
              },
            ),
          );
        },
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification, this.onTap});

  final AppNotification notification;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    final unread = !notification.isRead;
    return CsCard(
      key: ValueKey('notification-${notification.id}'),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CsIconTile(
                icon: Icons.notifications_none_rounded,
                size: 40,
                color: unread ? theme.link : theme.mutedText,
                background: unread ? theme.accentSoft : theme.shellBackground,
              ),
              if (unread)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                      border: Border.all(color: theme.card, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                    color: theme.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  notification.message,
                  style: TextStyle(fontSize: 13, color: theme.mutedText, height: 1.35),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatRelative(notification.createdAt),
                  style: csMono(fontSize: 11, color: theme.mutedText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatRelative(DateTime value) {
  final diff = DateTime.now().difference(value);
  if (diff.inMinutes < 1) return 'дөнгөж сая';
  if (diff.inHours < 1) return '${diff.inMinutes} минутын өмнө';
  if (diff.inDays < 1) return '${diff.inHours} цагийн өмнө';
  return '${diff.inDays} өдрийн өмнө';
}
