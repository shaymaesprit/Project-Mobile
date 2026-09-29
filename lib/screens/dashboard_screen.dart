import 'package:flutter/material.dart';
import '../models/study_models.dart';
import '../widgets/study_widgets.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.studentName,
    required this.courses,
    required this.tasks,
    required this.events,
    required this.notifications,
    required this.courseName,
    required this.onNotifications,
    required this.onTasks,
    required this.onCreate,
  });

  final String studentName;
  final List<Course> courses;
  final List<StudyTask> tasks;
  final List<StudyEvent> events;
  final List<StudyNotification> notifications;
  final String Function(String?) courseName;
  final VoidCallback onNotifications;
  final VoidCallback onTasks;
  final void Function(String kind, {Object? existing}) onCreate;

  @override
  Widget build(BuildContext context) {
    final todayCourses = courses.where((course) => course.day == 'Monday').toList();
    final upcomingTasks = tasks.where((task) => task.status != TaskStatus.completed).toList();
    final nextExam = events.where((event) => event.type == EventType.exam).isNotEmpty
        ? events.firstWhere((event) => event.type == EventType.exam)
        : null;
    final totalCourses = courses.length;
    final pending = tasks.where((task) => task.status != TaskStatus.completed).length;
    final completed = tasks.where((task) => task.status == TaskStatus.completed).length;
    final upcomingExams = events.where((event) => event.type == EventType.exam).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Good morning', style: TextStyle(color: Color(0xFF64748B))),
                  SizedBox(height: 4),
                ],
              ),
              Stack(
                children: [
                  IconButton(
                    onPressed: onNotifications,
                    icon: const Icon(Icons.notifications_none_rounded, size: 28),
                  ),
                  Positioned(
                    right: 12,
                    top: 12,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Text(studentName, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 18),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Today', style: Theme.of(context).textTheme.titleMedium),
                    const Text('Mon 18 Nov', style: TextStyle(color: Color(0xFF64748B))),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: StatCard(label: 'Courses', value: '$totalCourses', accent: const Color(0xFF006D77))),
                    const SizedBox(width: 12),
                    Expanded(child: StatCard(label: 'Pending', value: '$pending', accent: const Color(0xFFF59E0B))),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: StatCard(label: 'Completed', value: '$completed', accent: const Color(0xFF10B981))),
                    const SizedBox(width: 12),
                    Expanded(child: StatCard(label: 'Exams', value: '$upcomingExams', accent: const Color(0xFF83C5BE))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Quick actions', style: Theme.of(context).textTheme.titleMedium),
              IconButton(onPressed: () => onCreate('Task'), icon: const Icon(Icons.add_rounded)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _ActionButton(icon: Icons.menu_book_rounded, label: 'Courses', onTap: () => onCreate('Course'))),
              const SizedBox(width: 12),
              Expanded(child: _ActionButton(icon: Icons.task_alt_rounded, label: 'Tasks', onTap: onTasks)),
              const SizedBox(width: 12),
              Expanded(child: _ActionButton(icon: Icons.event_note_rounded, label: 'Event', onTap: () => onCreate('Event'))),
            ],
          ),
          const SizedBox(height: 22),
          SectionHeader(title: 'Today’s courses', trailing: 'View all'),
          const SizedBox(height: 10),
          if (todayCourses.isEmpty)
            const _EmptyState(title: 'No classes today', subtitle: 'Your timetable is clear for this day.')
          else
            ...todayCourses.map(
              (course) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Color(course.color),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(course.name, style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 4),
                          Text('${course.start} - ${course.end} • ${course.room}', style: const TextStyle(color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: Color(0xFF64748B)),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 18),
          SectionHeader(title: 'Upcoming tasks', trailing: 'See all'),
          const SizedBox(height: 10),
          if (upcomingTasks.isEmpty)
            const _EmptyState(title: 'No pending tasks', subtitle: 'All set for now.')
          else
            ...upcomingTasks.take(2).map(
              (task) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(task.title, style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 4),
                          Text('${courseName(task.courseId)} • ${task.deadline.day}/${task.deadline.month}', style: const TextStyle(color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDF6F9),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        task.priority.name.toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFF006D77),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 18),
          SectionHeader(title: 'Next exam', trailing: 'Open calendar'),
          const SizedBox(height: 10),
          if (nextExam == null)
            const _EmptyState(title: 'No upcoming exam', subtitle: 'Enjoy the break and keep preparing.')
          else
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFEDF6F9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF83C5BE)),
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(
                      color: Color(0xFF006D77),
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                    ),
                    child: const Icon(Icons.event_available_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(nextExam.title, style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(
                          '${nextExam.description} • ${nextExam.dateTime.day}/${nextExam.dateTime.month}/${nextExam.dateTime.year}',
                          style: const TextStyle(color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 18),
          SectionHeader(title: 'Recent notifications', trailing: 'View all'),
          const SizedBox(height: 10),
          ...notifications.take(3).map((notification) => NotificationTile(notification: notification)),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, size: 28, color: const Color(0xFF006D77)),
            const SizedBox(height: 8),
            Text(label, style: Theme.of(context).textTheme.labelLarge),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined, size: 28, color: Color(0xFF006D77)),
          const SizedBox(height: 8),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}
