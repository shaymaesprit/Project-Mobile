import 'package:flutter/material.dart';
import '../models/study_models.dart';
import '../utils/event_utils.dart';

class EventBadge extends StatelessWidget {
  const EventBadge({super.key, required this.label, required this.color, this.icon});
  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 12, color: color), const SizedBox(width: 4)],
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ]),
      );
}

class EventCard extends StatelessWidget {
  const EventCard({super.key, required this.event, required this.courseName, required this.onTap, this.onEdit, this.onDelete, this.compact = false});
  final StudyEvent event;
  final String Function(String?) courseName;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool compact;

  Widget _meta(IconData icon, String text) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: calendarMuted),
        const SizedBox(width: 4),
        Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: calendarMuted))),
      ]);

  @override
  Widget build(BuildContext context) {
    final cancelled = event.status == EventStatus.cancelled;
    final hasMenu = onEdit != null || onDelete != null;
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 5))]),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Container(width: 6, color: cancelled ? const Color(0xFFCBD5E1) : event.type.color),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(12, 12, hasMenu ? 0 : 12, 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      EventBadge(label: event.type.label, color: event.type.color, icon: event.type.icon),
                      if (event.status != EventStatus.planned) ...[
                        const SizedBox(width: 6),
                        EventBadge(label: event.status.label, color: event.status.color),
                      ],
                    ]),
                    const SizedBox(height: 6),
                    Text(
                      event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            decoration: cancelled ? TextDecoration.lineThrough : null,
                            color: cancelled ? const Color(0xFF94A3B8) : null,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(spacing: 12, runSpacing: 2, children: [
                      _meta(Icons.schedule_rounded, eventTimeRange(event)),
                      if (!compact && event.location.isNotEmpty) _meta(Icons.place_outlined, event.location),
                      if (!compact && event.courseId != null) _meta(Icons.menu_book_outlined, courseName(event.courseId)),
                      if (event.reminder) const Icon(Icons.notifications_active_outlined, size: 14, color: calendarPrimary),
                    ]),
                  ]),
                ),
              ),
              if (hasMenu)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, color: calendarMuted),
                  itemBuilder: (_) => <PopupMenuEntry<String>>[
                    if (onEdit != null) const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    if (onDelete != null) const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                  onSelected: (value) {
                    if (value == 'edit') onEdit?.call();
                    if (value == 'delete') onDelete?.call();
                  },
                ),
            ]),
          ),
        ),
      ),
    );
  }
}
