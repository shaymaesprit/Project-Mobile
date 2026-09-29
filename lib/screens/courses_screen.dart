import 'package:flutter/material.dart';
import '../models/study_models.dart';

class CoursesScreen extends StatelessWidget {
  const CoursesScreen({super.key, required this.courses, required this.onAdd, required this.onEdit, required this.onDelete});
  final List<Course> courses;
  final VoidCallback onAdd;
  final void Function(Course) onEdit;
  final void Function(Course) onDelete;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Courses', style: Theme.of(context).textTheme.titleLarge),
              IconButton(onPressed: onAdd, icon: const Icon(Icons.add_rounded)),
            ]),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                itemCount: courses.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, index) {
                  final course = courses[index];
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 5))]),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Container(width: 12, height: 46, decoration: BoxDecoration(color: Color(course.color), borderRadius: BorderRadius.circular(10))),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(course.name, style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 4), Text(course.code, style: const TextStyle(color: Color(0xFF64748B)))])),
                        PopupMenuButton<String>(itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Edit')), PopupMenuItem(value: 'delete', child: Text('Delete'))], onSelected: (value) { if (value == 'edit') onEdit(course); if (value == 'delete') onDelete(course); }),
                      ]),
                      const SizedBox(height: 12),
                      Text('${course.professor} • ${course.type.name.toUpperCase()}', style: const TextStyle(color: Color(0xFF64748B))),
                      const SizedBox(height: 8),
                      Row(children: [
                        _MetaChip(icon: Icons.location_on_outlined, label: course.room),
                        const SizedBox(width: 8),
                        _MetaChip(icon: Icons.calendar_today_outlined, label: course.day),
                      ]),
                      const SizedBox(height: 8),
                      Text('${course.start} - ${course.end} • ${course.semester}', style: const TextStyle(color: Color(0xFF64748B))),
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
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});
  final IconData icon; final String label;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), decoration: BoxDecoration(color: const Color(0xFFEDF6F9), borderRadius: BorderRadius.circular(999)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 14, color: const Color(0xFF006D77)), const SizedBox(width: 4), Text(label, style: const TextStyle(color: Color(0xFF006D77), fontSize: 12))]));
}
