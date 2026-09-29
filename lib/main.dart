import 'package:flutter/material.dart';
import 'data/mock_data.dart';
import 'models/study_models.dart';
import 'screens/study_screens.dart';
import 'widgets/study_widgets.dart';

void main() => runApp(const StudyMateApp());

class StudyMateApp extends StatelessWidget {
  const StudyMateApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'StudyMate',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFF8FAFC),
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF006D77), surface: Colors.white),
          fontFamily: 'Inter',
          textTheme: const TextTheme(
            headlineSmall: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
            titleLarge: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
            titleMedium: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
            bodyMedium: TextStyle(color: Color(0xFF1E293B)),
          ),
        ),
        home: const StudyMateShell(),
      );
}

class StudyMateShell extends StatefulWidget {
  const StudyMateShell({super.key});
  @override
  State<StudyMateShell> createState() => _StudyMateShellState();
}

class _StudyMateShellState extends State<StudyMateShell> {
  int _tab = 0;
  bool _showAuth = false;
  String _calendarMode = 'Month';
  String _taskFilter = 'All';
  final String _studentName = 'Maya';
  final _courses = MockData.courses;
  final _tasks = MockData.tasks;
  final _notes = MockData.notes;
  final _events = MockData.events;
  final _notifications = MockData.notifications;

  void _toast(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2)));

  String _courseName(String? id) => _courses.where((course) => course.id == id).map((course) => course.name).firstOrNull ?? 'Personal';

  Future<void> _delete(String kind, String id) async {
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
      title: Text('Delete ${kind.toLowerCase()}?'),
      content: const Text('This action cannot be undone.'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton.tonal(onPressed: () => Navigator.pop(context, true), child: const Text('Delete'))],
    ));
    if (confirmed != true) return;
    setState(() {
      if (kind == 'Course') _courses.removeWhere((value) => value.id == id);
      if (kind == 'Task') _tasks.removeWhere((value) => value.id == id);
      if (kind == 'Note') _notes.removeWhere((value) => value.id == id);
      if (kind == 'Event') _events.removeWhere((value) => value.id == id);
    });
    _toast('$kind deleted');
  }

  Future<void> _openForm(String kind, {Object? existing}) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EntityForm(kind: kind, courses: _courses, existing: existing),
    );
    if (result == null) return;
    setState(() {
      final id = (existing is Course) ? existing.id : (existing is StudyTask) ? existing.id : (existing is StudyNote) ? existing.id : (existing is StudyEvent) ? existing.id : DateTime.now().microsecondsSinceEpoch.toString();
      switch (kind) {
        case 'Course':
          final item = existing as Course?;
          final value = Course(id: id, name: result['name'], code: result['code'], professor: result['professor'], room: result['room'], type: CourseType.values[result['type']], day: result['day'], start: result['start'], end: result['end'], semester: result['semester'], color: result['color']);
          if (item == null) _courses.add(value); else { item.name = value.name; item.code = value.code; item.professor = value.professor; item.room = value.room; item.type = value.type; item.day = value.day; item.start = value.start; item.end = value.end; item.semester = value.semester; item.color = value.color; }
        case 'Task':
          final item = existing as StudyTask?;
          final value = StudyTask(id: id, title: result['title'], courseId: result['courseId'], deadline: result['deadline'], status: TaskStatus.values[result['status']], priority: Priority.values[result['priority']], progress: result['progress'], reminder: result['reminder']);
          if (item == null) _tasks.add(value); else { item.title = value.title; item.courseId = value.courseId; item.deadline = value.deadline; item.status = value.status; item.priority = value.priority; item.progress = value.progress; item.reminder = value.reminder; }
        case 'Note':
          final item = existing as StudyNote?;
          final value = StudyNote(id: id, title: result['title'], body: result['body'], courseId: result['courseId'], updatedAt: DateTime.now());
          if (item == null) _notes.insert(0, value); else { item.title = value.title; item.body = value.body; item.courseId = value.courseId; item.updatedAt = value.updatedAt; }
        case 'Event':
          final item = existing as StudyEvent?;
          final value = StudyEvent(id: id, title: result['title'], description: result['description'], dateTime: result['dateTime'], type: EventType.values[result['type']], location: result['location'], courseId: result['courseId'], reminder: result['reminder']);
          if (item == null) _events.add(value); else { item.title = value.title; item.description = value.description; item.dateTime = value.dateTime; item.type = value.type; item.location = value.location; item.courseId = value.courseId; item.reminder = value.reminder; }
      }
    });
    _toast(existing == null ? '$kind added' : '$kind updated');
  }

  void _quickCreate() => showModalBottomSheet<void>(context: context, useSafeArea: true, builder: (context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Create something', style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 14),
      Wrap(spacing: 10, runSpacing: 10, children: [
        _QuickAction(label: 'Task', icon: Icons.check_circle_outline, onTap: () { Navigator.pop(context); _openForm('Task'); }),
        _QuickAction(label: 'Course', icon: Icons.menu_book_outlined, onTap: () { Navigator.pop(context); _openForm('Course'); }),
        _QuickAction(label: 'Note', icon: Icons.sticky_note_2_outlined, onTap: () { Navigator.pop(context); _openForm('Note'); }),
        _QuickAction(label: 'Event', icon: Icons.event_outlined, onTap: () { Navigator.pop(context); _openForm('Event'); }),
      ]),
    ]),
  ));

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      DashboardScreen(studentName: _studentName, courses: _courses, tasks: _tasks, events: _events, notifications: _notifications, courseName: _courseName, onNotifications: () => setState(() => _tab = 4), onTasks: () => setState(() => _tab = 2), onCreate: _openForm),
      CoursesScreen(courses: _courses, onAdd: () => _openForm('Course'), onEdit: (course) => _openForm('Course', existing: course), onDelete: (course) => _delete('Course', course.id)),
      TasksScreen(tasks: _tasks, courseName: _courseName, filter: _taskFilter, onFilter: (value) => setState(() => _taskFilter = value), onAdd: () => _openForm('Task'), onEdit: (task) => _openForm('Task', existing: task), onDelete: (task) => _delete('Task', task.id), onToggle: (task) => setState(() { task.status = task.status == TaskStatus.completed ? TaskStatus.todo : TaskStatus.completed; task.progress = task.status == TaskStatus.completed ? 100 : 0; })),
      CalendarScreen(events: _events, mode: _calendarMode, onMode: (value) => setState(() => _calendarMode = value), onAdd: () => _openForm('Event'), onEdit: (event) => _openForm('Event', existing: event), onDelete: (event) => _delete('Event', event.id)),
      ProfileScreen(name: _studentName, coursesCount: _courses.length, tasksCount: _tasks.length, onSignOut: () => setState(() => _showAuth = true)),
    ];
    return Scaffold(
      body: SafeArea(child: _showAuth
        ? AuthScreen(onDone: () => setState(() { _showAuth = false; _tab = 0; _toast('Welcome back, $_studentName!'); }))
        : IndexedStack(index: _tab, children: pages)),
      floatingActionButton: _showAuth || _tab == 4 ? null : FloatingActionButton.extended(onPressed: _quickCreate, backgroundColor: const Color(0xFF006D77), foregroundColor: Colors.white, icon: const Icon(Icons.add_rounded), label: const Text('Create')),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: _showAuth ? null : NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (value) => setState(() => _tab = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book_rounded), label: 'Courses'),
          NavigationDestination(icon: Icon(Icons.task_alt_outlined), selectedIcon: Icon(Icons.task_alt_rounded), label: 'Tasks'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month_rounded), label: 'Calendar'),
          NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.label, required this.icon, required this.onTap});
  final String label; final IconData icon; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ActionChip(avatar: Icon(icon, size: 18, color: const Color(0xFF006D77)), label: Text(label), onPressed: onTap, side: BorderSide.none, backgroundColor: const Color(0xFFEDF6F9));
}
