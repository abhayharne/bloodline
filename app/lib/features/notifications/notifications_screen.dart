import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/in_app_notification.dart';
import '../../core/providers/notifications_provider.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  IconData _iconForType(String type) {
    switch (type) {
      case 'eligible_again':
        return Icons.favorite;
      case 'match_nearby':
        return Icons.emergency;
      case 'thanks':
        return Icons.thumb_up_alt;
      case 'rank_up':
        return Icons.military_tech;
      default:
        return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationsProvider>();
    final notifications = provider.notifications;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (provider.hasUnread)
            TextButton(
              onPressed: () => provider.markAllAsRead(),
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => provider.fetchNotifications(),
        child: notifications.isEmpty
            ? Center(
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_none,
                        size: 64,
                        color: theme.colorScheme.outline,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No notifications yet',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Updates about nearby requests and reminders will appear here.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            : ListView.separated(
                itemCount: notifications.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, index) {
                  final notif = notifications[index];
                  return _NotificationListTile(
                    notification: notif,
                    icon: _iconForType(notif.type),
                    onTap: () {
                      if (!notif.read) {
                        provider.markAsRead(notif.id);
                      }
                    },
                    onMarkRead: () => provider.markAsRead(notif.id),
                  );
                },
              ),
      ),
    );
  }
}

class _NotificationListTile extends StatelessWidget {
  final InAppNotification notification;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback onMarkRead;

  const _NotificationListTile({
    required this.notification,
    required this.icon,
    required this.onTap,
    required this.onMarkRead,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUnread = !notification.read;

    return ListTile(
      tileColor: isUnread
          ? theme.colorScheme.primaryContainer.withAlpha(50)
          : null,
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            backgroundColor: isUnread
                ? theme.colorScheme.primary.withAlpha(30)
                : theme.colorScheme.surfaceContainerHighest,
            child: Icon(
              icon,
              color: isUnread
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
              size: 20,
            ),
          ),
          if (isUnread)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: theme.colorScheme.error,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
        ],
      ),
      title: Text(
        notification.title,
        style: TextStyle(
          fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notification.body,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isUnread
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (notification.createdAt != null) ...[
              const SizedBox(height: 4),
              Text(
                _formatTimestamp(notification.createdAt!),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
      trailing: isUnread
          ? IconButton(
              icon: const Icon(Icons.check_circle_outline, size: 20),
              tooltip: 'Mark as read',
              onPressed: onMarkRead,
            )
          : null,
      onTap: onTap,
    );
  }

  String _formatTimestamp(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
