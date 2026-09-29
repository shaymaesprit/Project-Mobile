import 'package:flutter/material.dart';
import '../models/study_models.dart';

class EntityForm extends StatefulWidget {
  const EntityForm({super.key, required this.kind, required this.courses, this.existing});
  final String kind;
  final List<Course> courses;
  final Object? existing;

  @override
  State<EntityForm> createState() => _EntityFormState();
}

class _EntityFormState extends State<EntityForm> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, dynamic> _values = {};

  @override
  void initState() {
    super.initState();
    if (widget.kind == 'Course') {
      final course = widget.existing as Course?;
      _values.addAll({
        'name': course?.name ?? '',
        'code': course?.code ?? '',
        'professor': course?.professor ?? '',
        'room': course?.room ?? '',
        'type': course?.type.index ?? 0,
        'day': course?.day ?? 'Monday',
        'start': course?.start ?? '09:00',
        'end': course?.end ?? '10:30',
        'semester': course?.semester ?? 'Fall 2025',
        'color': course?.color ?? 0xFF006D77,
      });
    }
    if (widget.kind == 'Task') {
      final task = widget.existing as StudyTask?;
      _values.addAll({
        'title': task?.title ?? '',
        'courseId': task?.courseId ?? widget.courses.first.id,
        'deadline': task?.deadline ?? DateTime.now().add(const Duration(days: 2)),
        'status': task?.status.index ?? 0,
        'priority': task?.priority.index ?? 1,
        'progress': task?.progress ?? 35,
        'reminder': task?.reminder ?? false,
      });
    }
    if (widget.kind == 'Note') {
      final note = widget.existing as StudyNote?;
      _values.addAll({
        'title': note?.title ?? '',
        'body': note?.body ?? '',
        'courseId': note?.courseId ?? widget.courses.first.id,
      });
    }
    if (widget.kind == 'Event') {
      final event = widget.existing as StudyEvent?;
      _values.addAll({
        'title': event?.title ?? '',
        'description': event?.description ?? '',
        'dateTime': event?.dateTime ?? DateTime.now().add(const Duration(days: 2)),
        'type': event?.type.index ?? 0,
        'location': event?.location ?? 'Campus',
        'courseId': event?.courseId ?? widget.courses.first.id,
        'reminder': event?.reminder ?? true,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(color: Color(0xFFF8FAFC), borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('${widget.kind} details', style: Theme.of(context).textTheme.titleLarge), IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded))]),
              const SizedBox(height: 16),
              if (widget.kind == 'Course') ...[
                _TextField(label: 'Name', value: _values['name'], onChanged: (v) => _values['name'] = v),
                _TextField(label: 'Code', value: _values['code'], onChanged: (v) => _values['code'] = v),
                _TextField(label: 'Professor', value: _values['professor'], onChanged: (v) => _values['professor'] = v),
                _TextField(label: 'Classroom', value: _values['room'], onChanged: (v) => _values['room'] = v),
                DropdownButtonFormField<int>(value: _values['type'], onChanged: (v) => _values['type'] = v, items: CourseType.values.map((e) => DropdownMenuItem(value: e.index, child: Text(e.name))).toList(), decoration: const InputDecoration(labelText: 'Type')),
                DropdownButtonFormField<String>(value: _values['day'], onChanged: (v) => _values['day'] = v, items: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'].map((day) => DropdownMenuItem(value: day, child: Text(day))).toList(), decoration: const InputDecoration(labelText: 'Day')),
                Row(children: [Expanded(child: _TextField(label: 'Start', value: _values['start'], onChanged: (v) => _values['start'] = v)), const SizedBox(width: 12), Expanded(child: _TextField(label: 'End', value: _values['end'], onChanged: (v) => _values['end'] = v))]),
                _TextField(label: 'Semester', value: _values['semester'], onChanged: (v) => _values['semester'] = v),
              ],
              if (widget.kind == 'Task') ...[
                _TextField(label: 'Title', value: _values['title'], onChanged: (v) => _values['title'] = v),
                DropdownButtonFormField<String>(value: _values['courseId'], onChanged: (v) => _values['courseId'] = v, items: widget.courses.map((course) => DropdownMenuItem(value: course.id, child: Text(course.name))).toList(), decoration: const InputDecoration(labelText: 'Course')),
                DropdownButtonFormField<int>(value: _values['status'], onChanged: (v) => _values['status'] = v, items: TaskStatus.values.map((e) => DropdownMenuItem(value: e.index, child: Text(e.name))).toList(), decoration: const InputDecoration(labelText: 'Status')),
                DropdownButtonFormField<int>(value: _values['priority'], onChanged: (v) => _values['priority'] = v, items: Priority.values.map((e) => DropdownMenuItem(value: e.index, child: Text(e.name))).toList(), decoration: const InputDecoration(labelText: 'Priority')),
                const SizedBox(height: 12),
                TextButton.icon(onPressed: () async { final date = await showDatePicker(context: context, initialDate: _values['deadline'], firstDate: DateTime.now().subtract(const Duration(days: 365)), lastDate: DateTime.now().add(const Duration(days: 3650))); if (date != null) setState(() => _values['deadline'] = DateTime(date.year, date.month, date.day, 18, 0)); }, icon: const Icon(Icons.calendar_today_outlined), label: Text(_values['deadline'] == null ? 'Select deadline' : '${_values['deadline'].day}/${_values['deadline'].month}/${_values['deadline'].year}')),
                const SizedBox(height: 12),
                Slider(value: (_values['progress'] ?? 0).toDouble(), min: 0, max: 100, divisions: 10, label: '${_values['progress']}%', onChanged: (value) => setState(() => _values['progress'] = value.round())),
                SwitchListTile(value: _values['reminder'] ?? false, onChanged: (value) => setState(() => _values['reminder'] = value), title: const Text('Reminder'), contentPadding: EdgeInsets.zero),
              ],
              if (widget.kind == 'Note') ...[
                _TextField(label: 'Title', value: _values['title'], onChanged: (v) => _values['title'] = v),
                DropdownButtonFormField<String>(value: _values['courseId'], onChanged: (v) => _values['courseId'] = v, items: widget.courses.map((course) => DropdownMenuItem(value: course.id, child: Text(course.name))).toList(), decoration: const InputDecoration(labelText: 'Course')),
                TextFormField(initialValue: _values['body'], maxLines: 7, onChanged: (v) => _values['body'] = v, decoration: InputDecoration(labelText: 'Body', border: OutlineInputBorder(borderRadius: BorderRadius.circular(16))),),
              ],
              if (widget.kind == 'Event') ...[
                _TextField(label: 'Title', value: _values['title'], onChanged: (v) => _values['title'] = v),
                _TextField(label: 'Description', value: _values['description'], onChanged: (v) => _values['description'] = v),
                _TextField(label: 'Location', value: _values['location'], onChanged: (v) => _values['location'] = v),
                DropdownButtonFormField<int>(value: _values['type'], onChanged: (v) => _values['type'] = v, items: EventType.values.map((e) => DropdownMenuItem(value: e.index, child: Text(e.name))).toList(), decoration: const InputDecoration(labelText: 'Event type')),
                DropdownButtonFormField<String>(value: _values['courseId'], onChanged: (v) => _values['courseId'] = v, items: widget.courses.map((course) => DropdownMenuItem(value: course.id, child: Text(course.name))).toList(), decoration: const InputDecoration(labelText: 'Associated course')),
                SwitchListTile(value: _values['reminder'] ?? false, onChanged: (value) => setState(() => _values['reminder'] = value), title: const Text('Reminder'), contentPadding: EdgeInsets.zero),
              ],
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(context, _values), style: FilledButton.styleFrom(backgroundColor: const Color(0xFF006D77), minimumSize: const Size.fromHeight(48)), child: const Text('Save'))),
            ]),
          ),
        ),
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  const _TextField({required this.label, required this.value, required this.onChanged});
  final String label; final String value; final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      initialValue: value,
      onChanged: onChanged,
      decoration: InputDecoration(labelText: label, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16))),
    ),
  );
}
