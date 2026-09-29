import 'package:flutter/material.dart';
import '../models/study_models.dart';
import '../utils/event_utils.dart';
import '../widgets/event_card.dart';

/// Notification centre. Operates on the shared in-memory list (same pattern as the other screens)
/// and calls [onChanged] so the caller can refresh badges.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, required this.notifications, required this.events, required this.onChanged, required this.onOpenEvent, required this.onMessage});
  final List<StudyNotification> notifications;
  final List<StudyEvent> events;
  final VoidCallback onChanged;
  final void Function(StudyEvent) onOpenEvent;
  final void Function(String) onMessage;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _unreadOnly = false;

  int get _unread => widget.notifications.where((n) => !n.read).length;

  void _markRead(StudyNotification n) {
    if (n.read) return;
    setState(() => n.read = true);
    widget.onChanged();
  }

  void _markAllRead() {
    setState(() {
      for (final n in widget.notifications) {
        n.read = true;
      }
    });
    widget.onChanged();
    widget.onMessage('All notifications marked as read');
  }

  void _delete(StudyNotification n) {
    setState(() => widget.notifications.remove(n));
    widget.onChanged();
    widget.onMessage('Notification deleted');
  }

  Future<void> _deleteAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_outline_rounded, color: calendarDanger),
        title: const Text('Delete all notifications?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton.tonal(onPressed: () => Navigator.pop(context, true), child: const Text('Delete all')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => widget.notifications.clear());
    widget.onChanged();
    widget.onMessage('All notifications deleted');
  }

  void _open(StudyNotification n) {
    _markRead(n);
    if (n.eventId != null) {
      final event = widget.events.where((e) => e.id == n.eventId).firstOrNull;
      if (event == null) {
        widget.onMessage('This event no longer exists.');
        return;
      }
      widget.onOpenEvent(event);
    } else if (n.taskId != null) {
      widget.onMessage('Task details will open here once the Tasks screen is linked.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = [...widget.notifications]..sort((a, b) => b.dateTime.compareTo(a.dateTime));
    final items = _unreadOnly ? all.where((n) => !n.read).toList() : all;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.transparent,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) => value == 'read' ? _markAllRead() : _deleteAll(),
            itemBuilder: (_) => <PopupMenuEntry<String>>[
              PopupMenuItem(value: 'read', enabled: _unread > 0, child: const Text('Mark all as read')),
              PopupMenuItem(value: 'clear', enabled: widget.notifications.isNotEmpty, child: const Text('Delete all')),
            ],
          ),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Row(children: [
            ChoiceChip(label: Text('All (${widget.notifications.length})'), selected: !_unreadOnly, onSelected: (_) => setState(() => _unreadOnly = false)),
            const SizedBox(width: 8),
            ChoiceChip(label: Text('Unread ($_unread)'), selected: _unreadOnly, onSelected: (_) => setState(() => _unreadOnly = true)),
          ]),
        ),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.notifications_off_outlined, size: 48, color: Color(0xFF94A3B8)),
                    const SizedBox(height: 10),
                    Text(_unreadOnly ? 'You are all caught up' : 'No notifications', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(_unreadOnly ? 'No unread notifications.' : 'Reminders and alerts will appear here.', style: const TextStyle(color: calendarMuted)),
                  ]),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, index) {
                    final n = items[index];
                    return Dismissible(
                      key: ValueKey(n.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(color: calendarDanger.withOpacity(0.12), borderRadius: BorderRadius.circular(16)),
                        child: const Icon(Icons.delete_outline_rounded, color: calendarDanger),
                      ),
                      onDismissed: (_) => _delete(n),
                      child: _NotificationCard(notification: n, hasLink: n.eventId != null || n.taskId != null, onTap: () => _open(n), onMarkRead: () => _markRead(n), onDelete: () => _delete(n)),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification, required this.hasLink, required this.onTap, required this.onMarkRead, required this.onDelete});
  final StudyNotification notification;
  final bool hasLink;
  final VoidCallback onTap;
  final VoidCallback onMarkRead;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final style = notificationStyle(n.category);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: n.read ? Colors.transparent : const Color(0xFF83C5BE))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 42, height: 42, decoration: BoxDecoration(color: style.color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)), child: Icon(style.icon, color: style.color)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  if (!n.read) Container(width: 8, height: 8, margin: const EdgeInsets.only(right: 6), decoration: const BoxDecoration(color: calendarPrimary, shape: BoxShape.circle)),
                  Expanded(child: Text(n.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, fontWeight: n.read ? FontWeight.w500 : FontWeight.w700))),
                ]),
                const SizedBox(height: 4),
                Text(n.message, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: calendarMuted)),
                const SizedBox(height: 8),
                Row(children: [
                  EventBadge(label: n.category, color: style.color),
                  const SizedBox(width: 8),
                  Text(formatRelative(n.dateTime), style: const TextStyle(fontSize: 12, color: calendarMuted)),
                  if (hasLink) ...[
                    const Spacer(),
                    const Text('View', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: calendarPrimary)),
                    const Icon(Icons.chevron_right_rounded, size: 16, color: calendarPrimary),
                    const SizedBox(width: 4),
                  ],
                ]),
              ]),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: calendarMuted),
              onSelected: (value) => value == 'read' ? onMarkRead() : onDelete(),
              itemBuilder: (_) => <PopupMenuEntry<String>>[
                if (!n.read) const PopupMenuItem(value: 'read', child: Text('Mark as read')),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ]),
        ),
      ),
    );
  }
}
