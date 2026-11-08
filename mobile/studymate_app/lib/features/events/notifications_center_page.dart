import 'package:flutter/material.dart';

import '../../data/models/event_models.dart';
import '../../state/study_controller.dart';
import 'event_detail_page.dart';
import 'event_helpers.dart';
import 'events_controller.dart';

/// Centre de notifications : liste, filtres, lecture, suppression par balayage.
class NotificationsCenterPage extends StatefulWidget {
  const NotificationsCenterPage({
    super.key,
    required this.studyController,
    required this.events,
  });

  final StudyController studyController;
  final EventsController events;

  @override
  State<NotificationsCenterPage> createState() =>
      _NotificationsCenterPageState();
}

enum _Filter { all, unread, exam, deadline, reminder }

class _NotificationsCenterPageState extends State<NotificationsCenterPage> {
  _Filter _filter = _Filter.all;

  EventsController get _events => widget.events;

  static const _labels = {
    _Filter.all: 'Toutes',
    _Filter.unread: 'Non lues',
    _Filter.exam: 'Examens',
    _Filter.deadline: 'Échéances',
    _Filter.reminder: 'Rappels',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() => _events.loadNotifications(
        unreadOnly: _filter == _Filter.unread,
        type: switch (_filter) {
          _Filter.exam => 'exam',
          _Filter.deadline => 'deadline',
          _Filter.reminder => 'reminder',
          _ => null,
        },
      );

  Future<void> _open(AppNotification notification) async {
    await _events.markRead(notification);
    final eventId = notification.eventId;
    if (eventId == null || !mounted) return;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EventDetailPage(
          studyController: widget.studyController,
          events: _events,
          eventId: eventId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          ListenableBuilder(
            listenable: _events,
            builder: (context, _) => IconButton(
              tooltip: 'Tout marquer comme lu',
              onPressed: _events.unreadCount == 0 ? null : _events.markAllRead,
              icon: const Icon(Icons.done_all_rounded),
            ),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _events,
        builder: (context, _) {
          final notifications = _events.notifications;
          return Column(
            children: [
              SizedBox(
                height: 52,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    for (final filter in _Filter.values)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 8,
                        ),
                        child: ChoiceChip(
                          label: Text(_labels[filter]!),
                          selected: _filter == filter,
                          onSelected: (_) {
                            setState(() => _filter = filter);
                            _load();
                          },
                        ),
                      ),
                  ],
                ),
              ),
              if (_events.isLoading) const LinearProgressIndicator(minHeight: 2),
              if (_events.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _events.errorMessage!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _load,
                  child: notifications.isEmpty && !_events.isLoading
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 120),
                            Icon(Icons.notifications_none_rounded, size: 48),
                            SizedBox(height: 12),
                            Center(child: Text('Aucune notification')),
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: notifications.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) =>
                              _tile(notifications[index]),
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _tile(AppNotification notification) {
    final colors = Theme.of(context).colorScheme;
    final color = categoryColor(
      notification.type == 'reminder' ? 'other' : notification.type,
    );
    return Dismissible(
      key: ValueKey(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: colors.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Icon(Icons.delete_outline_rounded, color: colors.onErrorContainer),
      ),
      onDismissed: (_) => _events.deleteNotification(notification),
      child: ListTile(
        onTap: () => _open(notification),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(notificationIcon(notification.type), color: color),
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight:
                notification.isRead ? FontWeight.w500 : FontWeight.w800,
          ),
        ),
        subtitle: Text(
          '${notification.body}\n${relativeTime(notification.createdAt)}',
        ),
        isThreeLine: true,
        trailing: notification.isRead
            ? null
            : Icon(Icons.circle, size: 10, color: colors.primary),
      ),
    );
  }
}
