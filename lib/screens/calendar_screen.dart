import 'package:flutter/material.dart';
import '../models/study_models.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key, required this.events, required this.mode, required this.onMode, required this.onAdd, required this.onEdit, required this.onDelete});
  final List<StudyEvent> events;
  final String mode;
  final void Function(String) onMode;
  final VoidCallback onAdd;
  final void Function(StudyEvent) onEdit;
  final void Function(StudyEvent) onDelete;

  @override
  Widget build(BuildContext context) {
    final modes = ['Day', 'Week', 'Month'];
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Calendar', style: Theme.of(context).textTheme.titleLarge),
              IconButton(onPressed: onAdd, icon: const Icon(Icons.add_rounded)),
            ]),
            const SizedBox(height: 12),
            ToggleButtons(
              isSelected: modes.map((value) => value == mode).toList(),
              constraints: const BoxConstraints(minWidth: 88, minHeight: 38),
              borderRadius: BorderRadius.circular(12),
              onPressed: (index) => onMode(modes[index]),
              children: modes.map((value) => Text(value)).toList(),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: ListView.separated(
                itemCount: events.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, index) {
                  final event = events[index];
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 5))]),
                    child: Row(children: [
                      Container(width: 12, height: 62, decoration: BoxDecoration(color: _colorForType(event.type), borderRadius: BorderRadius.circular(10))),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(event.title, style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 4), Text('${event.description} • ${event.dateTime.day}/${event.dateTime.month}', style: const TextStyle(color: Color(0xFF64748B)))])),
                      PopupMenuButton<String>(itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Edit')), PopupMenuItem(value: 'delete', child: Text('Delete'))], onSelected: (value) { if (value == 'edit') onEdit(event); if (value == 'delete') onDelete(event); }),
                    ]),
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Color _colorForType(EventType type) {
    switch (type) {
      case EventType.exam: return const Color(0xFFEF4444);
      case EventType.deadline: return const Color(0xFFF59E0B);
      case EventType.course: return const Color(0xFF006D77);
      case EventType.personal: return const Color(0xFF10B981);
      case EventType.other: return const Color(0xFF83C5BE);
    }
  }
}
