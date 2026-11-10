import 'package:flutter/material.dart';

import '../../data/models/study_models.dart';
import '../../state/study_controller.dart';
import '../../core/theme/app_theme.dart';
import 'course_documents.dart';
import 'timetable_page.dart';

const _weekdays = [
  'Lundi',
  'Mardi',
  'Mercredi',
  'Jeudi',
  'Vendredi',
  'Samedi',
  'Dimanche',
];

class CourseManagementPage extends StatefulWidget {
  const CourseManagementPage({
    super.key,
    required this.controller,
    required this.onRefresh,
  });

  final StudyController controller;
  final Future<void> Function() onRefresh;

  @override
  State<CourseManagementPage> createState() => _CourseManagementPageState();
}

class _CourseManagementPageState extends State<CourseManagementPage> {
  bool _showSchedule = false;
  int _selectedWeekday = DateTime.now().weekday - 1;

  @override
  Widget build(BuildContext context) {
    final courses = widget.controller.courses;
    final schedule = widget.controller.weeklySchedule
        .where((course) => course.weekday == _selectedWeekday)
        .toList()
      ..sort((a, b) => (a.startTime ?? '').compareTo(b.startTime ?? ''));

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 100),
        children: [
          Text(
            'Cours et emploi du temps',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 5),
          Text(
            'Organise tes matières et tes séances de la semaine.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          Card(
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: AppGradients.brand,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.calendar_view_week_rounded,
                  color: Colors.white,
                ),
              ),
              title: const Text(
                'Emploi du temps de la semaine',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text(
                'Jours fériés, conflits, créneaux libres et partage QR.',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => TimetablePage(api: widget.controller.api),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: false,
                icon: Icon(Icons.menu_book_outlined),
                label: Text('Mes cours'),
              ),
              ButtonSegment(
                value: true,
                icon: Icon(Icons.calendar_view_week_outlined),
                label: Text('Semaine'),
              ),
            ],
            selected: {_showSchedule},
            onSelectionChanged: (selection) =>
                setState(() => _showSchedule = selection.first),
          ),
          const SizedBox(height: 16),
          if (_showSchedule) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var day = 0; day < _weekdays.length; day++) ...[
                    if (day > 0) const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text(_weekdays[day]),
                      selected: _selectedWeekday == day,
                      onSelected: (_) => setState(() => _selectedWeekday = day),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (schedule.isEmpty)
              _EmptyCourses(
                title:
                    'Aucun cours le ${_weekdays[_selectedWeekday].toLowerCase()}',
                onAdd: _addCourse,
              )
            else
              for (final course in schedule) ...[
                _CourseCard(
                  course: course,
                  onTap: () => _openDetails(course),
                ),
                const SizedBox(height: 10),
              ],
          ] else if (courses.isEmpty)
            _EmptyCourses(
              title: 'Aucun cours enregistré',
              onAdd: _addCourse,
            )
          else
            for (final course in courses) ...[
              _CourseCard(
                course: course,
                onTap: () => _openDetails(course),
              ),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }

  Future<void> _addCourse() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CourseFormPage(controller: widget.controller),
      ),
    );
  }

  Future<void> _openDetails(StudyCourse course) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CourseDetailPage(
          course: course,
          controller: widget.controller,
        ),
      ),
    );
  }
}

class _EmptyCourses extends StatelessWidget {
  const _EmptyCourses({required this.title, required this.onAdd});

  final String title;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              Icon(
                Icons.event_available_outlined,
                size: 38,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 8),
              Text(title, textAlign: TextAlign.center),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Ajouter un cours'),
              ),
            ],
          ),
        ),
      );
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({required this.course, required this.onTap});

  final StudyCourse course;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final details = [
      if (_formatTime(course.startTime) case final start?)
        '$start – ${_formatTime(course.endTime)}',
      if (course.professor?.isNotEmpty == true) course.professor!,
      if (course.room?.isNotEmpty == true) 'Salle ${course.room}',
    ];
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
          child: Icon(
            Icons.menu_book_rounded,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Text(
          course.title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          [
            if (course.code?.isNotEmpty == true) course.code!,
            ...details,
          ].join(' · ').isEmpty
              ? 'Appuie pour afficher le détail'
              : [
                  if (course.code?.isNotEmpty == true) course.code!,
                  ...details,
                ].join(' · '),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class CourseDetailPage extends StatelessWidget {
  const CourseDetailPage({
    super.key,
    required this.course,
    required this.controller,
  });

  final StudyCourse course;
  final StudyController controller;

  @override
  Widget build(BuildContext context) {
    final info = <(String, String)>[
      if (course.code?.isNotEmpty == true) ('Code', course.code!),
      if (course.professor?.isNotEmpty == true)
        ('Professeur', course.professor!),
      if (course.room?.isNotEmpty == true) ('Salle', course.room!),
      if (course.weekday != null) ('Jour', _weekdays[course.weekday!]),
      if (_formatTime(course.startTime) case final start?)
        ('Horaire', '$start – ${_formatTime(course.endTime)}'),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Détail du cours')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            course.title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                for (var index = 0; index < info.length; index++) ...[
                  if (index > 0)
                    const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: Text(info[index].$1),
                    subtitle: Text(info[index].$2),
                  ),
                ],
                if (info.isEmpty)
                  const ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('Aucune information complémentaire'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          CourseDocumentsSection(controller: controller, course: course),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () async {
              final saved = await Navigator.of(context).push<bool>(
                MaterialPageRoute<bool>(
                  builder: (_) => CourseFormPage(
                    controller: controller,
                    course: course,
                  ),
                ),
              );
              if (saved == true && context.mounted) Navigator.pop(context);
            },
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Modifier le cours'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _delete(context),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Supprimer le cours'),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer ce cours ?'),
        content: Text('« ${course.title} » sera supprimé définitivement.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    try {
      await controller.deleteCourse(course);
      if (context.mounted) Navigator.pop(context);
    } on Exception catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    }
  }
}

class CourseFormPage extends StatefulWidget {
  const CourseFormPage({
    super.key,
    required this.controller,
    this.course,
  });

  final StudyController controller;
  final StudyCourse? course;

  @override
  State<CourseFormPage> createState() => _CourseFormPageState();
}

class _CourseFormPageState extends State<CourseFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _codeController;
  late final TextEditingController _professorController;
  late final TextEditingController _roomController;
  int? _weekday;
  TimeOfDay? _start;
  TimeOfDay? _end;
  bool _isSaving = false;

  bool get _isEditing => widget.course != null;

  @override
  void initState() {
    super.initState();
    final course = widget.course;
    _titleController = TextEditingController(text: course?.title);
    _codeController = TextEditingController(text: course?.code);
    _professorController = TextEditingController(text: course?.professor);
    _roomController = TextEditingController(text: course?.room);
    _weekday = course?.weekday;
    _start = _parseTime(course?.startTime);
    _end = _parseTime(course?.endTime);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _codeController.dispose();
    _professorController.dispose();
    _roomController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? 'Modifier le cours' : 'Ajouter un cours'),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              TextFormField(
                controller: _titleController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nom du cours *',
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Le nom du cours est requis.'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _codeController,
                decoration: const InputDecoration(
                  labelText: 'Code du cours',
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _professorController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Professeur',
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _roomController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Salle',
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Emploi du temps',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                initialValue: _weekday,
                decoration: const InputDecoration(
                  labelText: 'Jour (facultatif)',
                ),
                items: [
                  const DropdownMenuItem<int>(
                    value: null,
                    child: Text('Pas de jour défini'),
                  ),
                  for (var day = 0; day < _weekdays.length; day++)
                    DropdownMenuItem(value: day, child: Text(_weekdays[day])),
                ],
                onChanged: (value) => setState(() => _weekday = value),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _TimePickerField(
                      label: 'Début',
                      value: _start,
                      onTap: () => _pickTime(isStart: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TimePickerField(
                      label: 'Fin',
                      value: _end,
                      onTap: () => _pickTime(isStart: false),
                    ),
                  ),
                ],
              ),
              if (_weekday != null && (_start == null || _end == null))
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Choisis les heures de début et de fin pour planifier ce cours.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(_isEditing ? 'Enregistrer' : 'Créer le cours'),
              ),
            ],
          ),
        ),
      );

  Future<void> _pickTime({required bool isStart}) async {
    final value = await showTimePicker(
      context: context,
      initialTime:
          (isStart ? _start : _end) ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (value != null) {
      setState(() {
        if (isStart) {
          _start = value;
        } else {
          _end = value;
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_weekday != null &&
        (_start == null || _end == null || !_isAfter(_end!, _start!))) {
      _showError(
        _start == null || _end == null
            ? 'Ajoute une heure de début et de fin.'
            : 'L’heure de fin doit être après l’heure de début.',
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      final start = _weekday == null ? null : _formatTimeOfDay(_start!);
      final end = _weekday == null ? null : _formatTimeOfDay(_end!);
      if (_isEditing) {
        await widget.controller.updateCourse(
          course: widget.course!,
          title: _titleController.text.trim(),
          code: _optional(_codeController.text),
          professor: _optional(_professorController.text),
          room: _optional(_roomController.text),
          weekday: _weekday,
          startTime: start,
          endTime: end,
        );
      } else {
        await widget.controller.addCourse(
          title: _titleController.text.trim(),
          code: _optional(_codeController.text),
          professor: _optional(_professorController.text),
          room: _optional(_roomController.text),
          weekday: _weekday,
          startTime: start,
          endTime: end,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } on Exception catch (error) {
      _showError(error.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _TimePickerField extends StatelessWidget {
  const _TimePickerField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final TimeOfDay? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            suffixIcon: const Icon(Icons.schedule),
          ),
          child: Text(value?.format(context) ?? 'Choisir'),
        ),
      );
}

String? _formatTime(String? value) {
  if (value == null || value.isEmpty) return null;
  final parts = value.split(':');
  if (parts.length < 2) return value;
  return '${parts[0]}:${parts[1]}';
}

TimeOfDay? _parseTime(String? value) {
  if (value == null) return null;
  final parts = value.split(':');
  if (parts.length < 2) return null;
  return TimeOfDay(
    hour: int.tryParse(parts[0]) ?? 0,
    minute: int.tryParse(parts[1]) ?? 0,
  );
}

String _formatTimeOfDay(TimeOfDay value) =>
    '${value.hour.toString().padLeft(2, '0')}:'
    '${value.minute.toString().padLeft(2, '0')}';

bool _isAfter(TimeOfDay value, TimeOfDay other) =>
    value.hour * 60 + value.minute > other.hour * 60 + other.minute;

String? _optional(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
