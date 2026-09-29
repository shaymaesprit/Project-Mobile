import 'package:flutter/material.dart';
import '../models/study_models.dart';
import '../utils/event_utils.dart';

/// Bottom-sheet form for creating / editing an event (exam, deadline, course, personal, other).
/// Pops a map with the keys used by the shell: title, description, dateTime, endDateTime, type,
/// location, courseId, reminder, reminderAt, status.
class EventForm extends StatefulWidget {
  const EventForm({super.key, required this.courses, this.existing, this.initialDate});
  final List<Course> courses;
  final StudyEvent? existing;
  final DateTime? initialDate;

  @override
  State<EventForm> createState() => _EventFormState();
}

class _EventFormState extends State<EventForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _location;
  late EventType _type;
  late EventStatus _status;
  late DateTime _date;
  late TimeOfDay _start;
  TimeOfDay? _end;
  String? _courseId;
  late bool _reminder;
  ReminderPreset? _preset;
  bool _custom = false;
  DateTime? _customReminder;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _description = TextEditingController(text: e?.description ?? '');
    _location = TextEditingController(text: e?.location ?? '');
    _type = e?.type ?? EventType.exam;
    _status = e?.status ?? EventStatus.planned;
    _date = dateOnly(e?.dateTime ?? widget.initialDate ?? DateTime.now());
    _start = e == null ? const TimeOfDay(hour: 9, minute: 0) : TimeOfDay.fromDateTime(e.dateTime);
    final end = e?.endDateTime;
    _end = end == null ? null : TimeOfDay.fromDateTime(end);
    final courseId = e?.courseId;
    _courseId = widget.courses.any((c) => c.id == courseId) ? courseId : null;
    _reminder = e?.reminder ?? false;
    final at = e?.reminderAt;
    if (e != null && at != null) {
      final diff = e.dateTime.difference(at);
      _preset = reminderPresets.where((p) => p.before == diff).firstOrNull;
      if (_preset == null) {
        _custom = true;
        _customReminder = at;
      }
    } else if (_reminder) {
      _preset = reminderPresets.first;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    super.dispose();
  }

  DateTime get _startDateTime => DateTime(_date.year, _date.month, _date.day, _start.hour, _start.minute);
  DateTime? get _endDateTime => _end == null ? null : DateTime(_date.year, _date.month, _date.day, _end!.hour, _end!.minute);
  DateTime? get _reminderAt {
    if (!_reminder) return null;
    if (_custom) return _customReminder;
    final preset = _preset;
    return preset == null ? null : _startDateTime.subtract(preset.before);
  }

  InputDecoration _decoration(String label) => InputDecoration(labelText: label, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)));

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickStart() async {
    final picked = await showTimePicker(context: context, initialTime: _start);
    if (picked != null) setState(() => _start = picked);
  }

  Future<void> _pickEnd() async {
    final picked = await showTimePicker(context: context, initialTime: _end ?? TimeOfDay(hour: (_start.hour + 1) % 24, minute: _start.minute));
    if (picked != null) setState(() => _end = picked);
  }

  Future<void> _pickCustomReminder() async {
    final base = _customReminder ?? _startDateTime.subtract(const Duration(hours: 1));
    final date = await showDatePicker(context: context, initialDate: base, firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(base));
    if (time == null) return;
    setState(() => _customReminder = DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  void _save() {
    final fieldsValid = _formKey.currentState!.validate();
    final error = validateEventTimes(start: _startDateTime, end: _endDateTime, reminderEnabled: _reminder, reminderAt: _reminderAt);
    if (!fieldsValid || error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.pop(context, <String, dynamic>{
      'title': _title.text.trim(),
      'description': _description.text.trim(),
      'dateTime': _startDateTime,
      'endDateTime': _endDateTime,
      'type': _type.index,
      'location': _location.text.trim(),
      'courseId': _courseId,
      'reminder': _reminder,
      'reminderAt': _reminderAt,
      'status': _status.index,
    });
  }

  @override
  Widget build(BuildContext context) {
    final isExam = _type == EventType.exam;
    final reminderAt = _reminderAt;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(color: Color(0xFFF8FAFC), borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(widget.existing == null ? 'New event' : 'Edit event', style: Theme.of(context).textTheme.titleLarge),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
              ]),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final t in EventType.values)
                  ChoiceChip(
                    avatar: Icon(t.icon, size: 18, color: _type == t ? Colors.white : t.color),
                    label: Text(t.label),
                    selected: _type == t,
                    showCheckmark: false,
                    selectedColor: t.color,
                    labelStyle: TextStyle(fontWeight: FontWeight.w600, color: _type == t ? Colors.white : null),
                    onSelected: (_) => setState(() => _type = t),
                  ),
              ]),
              const SizedBox(height: 16),
              TextFormField(
                controller: _title,
                textCapitalization: TextCapitalization.sentences,
                decoration: _decoration(isExam ? 'Subject *' : 'Title *'),
                validator: (value) => (value == null || value.trim().isEmpty) ? 'A title is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(controller: _description, maxLines: 2, textCapitalization: TextCapitalization.sentences, decoration: _decoration('Description')),
              const SizedBox(height: 12),
              TextFormField(controller: _location, decoration: _decoration(isExam ? 'Room' : 'Location')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                value: _courseId,
                decoration: _decoration('Associated course'),
                onChanged: (value) => setState(() => _courseId = value),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('No course')),
                  ...widget.courses.map((c) => DropdownMenuItem<String?>(value: c.id, child: Text(c.name))),
                ],
              ),
              const SizedBox(height: 12),
              _PickerTile(icon: Icons.calendar_today_outlined, label: 'Date *', value: formatDate(_date), onTap: _pickDate),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _PickerTile(icon: Icons.schedule_rounded, label: 'Start *', value: _start.format(context), onTap: _pickStart)),
                const SizedBox(width: 12),
                Expanded(child: _PickerTile(icon: Icons.schedule_rounded, label: 'End (optional)', value: _end == null ? 'Not set' : _end!.format(context), onTap: _pickEnd, onClear: _end == null ? null : () => setState(() => _end = null))),
              ]),
              const SizedBox(height: 12),
              DropdownButtonFormField<EventStatus>(
                value: _status,
                decoration: _decoration('Status'),
                onChanged: (value) => setState(() => _status = value ?? _status),
                items: EventStatus.values.map((s) => DropdownMenuItem(value: s, child: Text(s.label))).toList(),
              ),
              SwitchListTile(
                value: _reminder,
                contentPadding: EdgeInsets.zero,
                title: const Text('Reminder'),
                onChanged: (value) => setState(() {
                  _reminder = value;
                  if (value && !_custom && _preset == null) _preset = reminderPresets.first;
                }),
              ),
              if (_reminder) ...[
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final p in reminderPresets)
                    ChoiceChip(label: Text(p.label), selected: !_custom && _preset == p, onSelected: (_) => setState(() { _custom = false; _preset = p; })),
                  ChoiceChip(label: const Text('Custom'), selected: _custom, onSelected: (_) => setState(() => _custom = true)),
                ]),
                if (_custom) ...[
                  const SizedBox(height: 12),
                  _PickerTile(
                    icon: Icons.alarm_rounded,
                    label: 'Reminder date & time',
                    value: _customReminder == null ? 'Pick a date and time' : '${formatDate(_customReminder!)} · ${formatTime(_customReminder!)}',
                    onTap: _pickCustomReminder,
                  ),
                ],
                if (reminderAt != null)
                  Padding(padding: const EdgeInsets.only(top: 8), child: Text('You will be notified on ${formatDate(reminderAt)} at ${formatTime(reminderAt)}.', style: const TextStyle(fontSize: 12.5, color: calendarMuted))),
              ],
              if (_error != null)
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: calendarDanger.withOpacity(0.10), borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    const Icon(Icons.error_outline_rounded, size: 18, color: calendarDanger),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!, style: const TextStyle(color: calendarDanger, fontSize: 13))),
                  ]),
                ),
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, child: FilledButton(onPressed: _save, style: FilledButton.styleFrom(backgroundColor: calendarPrimary, minimumSize: const Size.fromHeight(48)), child: const Text('Save'))),
            ]),
          ),
        ),
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({required this.icon, required this.label, required this.value, required this.onTap, this.onClear});
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            prefixIcon: Icon(icon, size: 20),
            suffixIcon: onClear == null ? null : IconButton(icon: const Icon(Icons.close_rounded, size: 18), onPressed: onClear),
          ),
          child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      );
}
