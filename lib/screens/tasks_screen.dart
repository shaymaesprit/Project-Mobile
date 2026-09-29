import 'package:flutter/material.dart';
import '../models/study_models.dart';

class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key, required this.tasks, required this.courseName, required this.filter, required this.onFilter, required this.onAdd, required this.onEdit, required this.onDelete, required this.onToggle});
  final List<StudyTask> tasks;
  final String Function(String?) courseName;
  final String filter;
  final void Function(String) onFilter;
  final VoidCallback onAdd;
  final void Function(StudyTask) onEdit;
  final void Function(StudyTask) onDelete;
  final void Function(StudyTask) onToggle;

  @override
  Widget build(BuildContext context) {
    final visible = tasks.where((task) {
      switch (filter) {
        case 'To Do': return task.status == TaskStatus.todo;
        case 'In Progress': return task.status == TaskStatus.inProgress;
        case 'Completed': return task.status == TaskStatus.completed;
        default: return true;
      }
    }).toList();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Tasks', style: Theme.of(context).textTheme.titleLarge),
              IconButton(onPressed: onAdd, icon: const Icon(Icons.add_rounded)),
            ]),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: ['All', 'To Do', 'In Progress', 'Completed'].map((item) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(item),
                  selected: filter == item,
                  onSelected: (_) => onFilter(item),
                  selectedColor: const Color(0xFF006D77),
                  labelStyle: TextStyle(color: filter == item ? Colors.white : const Color(0xFF1E293B)),
                ),
              )).toList()),
            ),
            const SizedBox(height: 14),
            Expanded(child: ListView.separated(
              itemCount: visible.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, index) {
                final task = visible[index];
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 5))]),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(task.title, style: Theme.of(context).textTheme.titleMedium)),
                      Checkbox(value: task.status == TaskStatus.completed, onChanged: (_) => onToggle(task)),
                    ]),
                    const SizedBox(height: 6),
                    Text('${courseName(task.courseId)} • ${task.deadline.day}/${task.deadline.month}', style: const TextStyle(color: Color(0xFF64748B))),
                    const SizedBox(height: 12),
                    Row(children: [
                      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), decoration: BoxDecoration(color: const Color(0xFFEDF6F9), borderRadius: BorderRadius.circular(999)), child: Text(task.priority.name.toUpperCase(), style: const TextStyle(color: Color(0xFF006D77), fontSize: 10, fontWeight: FontWeight.w700))),
                      const SizedBox(width: 8),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), decoration: BoxDecoration(color: const Color(0xFFEDF6F9), borderRadius: BorderRadius.circular(999)), child: Text(task.status.name.toUpperCase(), style: const TextStyle(color: Color(0xFF006D77), fontSize: 10, fontWeight: FontWeight.w700))),
                      const Spacer(),
                      PopupMenuButton<String>(itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Edit')), PopupMenuItem(value: 'delete', child: Text('Delete'))], onSelected: (value) { if (value == 'edit') onEdit(task); if (value == 'delete') onDelete(task); }),
                    ]),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(value: task.progress / 100, minHeight: 7, borderRadius: BorderRadius.circular(8), color: const Color(0xFF10B981), backgroundColor: const Color(0xFFE2E8F0)),
                    const SizedBox(height: 8),
                    Align(alignment: Alignment.centerRight, child: Text('${task.progress}% complete', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12))),
                  ]),
                );
              },
            )),
          ]),
        ),
      ),
    );
  }
}
