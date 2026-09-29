import 'package:flutter/material.dart';
import '../models/study_models.dart';
import '../utils/event_utils.dart';
import '../widgets/event_card.dart';

class EventDetailsScreen extends StatefulWidget {
  const EventDetailsScreen({super.key, required this.event, required this.courseName, required this.onEdit, required this.onDelete});
  final StudyEvent event;
  final String Function(String?) courseName;
  final Future<void> Function(StudyEvent) onEdit;
  final Future<bool> Function(StudyEvent) onDelete;

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  StudyEvent get _event => widget.event;

  Future<void> _edit() async {
    await widget.onEdit(_event);
    if (mounted) setState(() {});
  }

  Future<void> _delete() async {
    final deleted = await widget.onDelete(_event);
    if (deleted && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final e = _event;
    final cancelled = e.status == EventStatus.cancelled;
    final isPast = e.status == EventStatus.planned && (e.endDateTime ?? e.dateTime).isBefore(DateTime.now());
    final reminderAt = e.reminderAt;
    var reminderText = reminderLabel(e);
    if (e.reminder && reminderAt != null) reminderText += '\n${formatDate(reminderAt)} at ${formatTime(reminderAt)}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Event details'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(tooltip: 'Edit', onPressed: _edit, icon: const Icon(Icons.edit_outlined)),
          IconButton(tooltip: 'Delete', onPressed: _delete, icon: const Icon(Icons.delete_outline_rounded, color: calendarDanger)),
        ],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 32), children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: e.type.color.withOpacity(0.10), borderRadius: BorderRadius.circular(22)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 6, runSpacing: 6, children: [
              EventBadge(label: e.type.label, color: e.type.color, icon: e.type.icon),
              EventBadge(label: e.status.label, color: e.status.color),
              if (isPast) const EventBadge(label: 'Past', color: calendarMuted, icon: Icons.history_rounded),
            ]),
            const SizedBox(height: 12),
            Text(e.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(decoration: cancelled ? TextDecoration.lineThrough : null)),
          ]),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: Column(children: [
            _InfoRow(icon: Icons.calendar_today_outlined, label: 'Date', value: formatDate(e.dateTime)),
            _InfoRow(icon: Icons.schedule_rounded, label: 'Time', value: eventTimeRange(e)),
            if (e.location.isNotEmpty) _InfoRow(icon: Icons.place_outlined, label: e.type == EventType.exam ? 'Room' : 'Location', value: e.location),
            if (e.courseId != null) _InfoRow(icon: Icons.menu_book_outlined, label: 'Course', value: widget.courseName(e.courseId)),
            _InfoRow(icon: Icons.notifications_active_outlined, label: 'Reminder', value: reminderText),
            if (e.description.isNotEmpty) _InfoRow(icon: Icons.notes_rounded, label: 'Description', value: e.description, last: true),
          ]),
        ),
      ]),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value, this.last = false});
  final IconData icon;
  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: Color(0xFFF1F5F9)))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 36, height: 36, decoration: BoxDecoration(color: const Color(0xFFEDF6F9), borderRadius: BorderRadius.circular(10)), child: Icon(icon, size: 18, color: calendarPrimary)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 12, color: calendarMuted)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
          ])),
        ]),
      );
}
