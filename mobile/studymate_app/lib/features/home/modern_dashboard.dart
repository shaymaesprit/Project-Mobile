import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../data/models/study_models.dart';
import 'widgets/widgets.dart';

class ModernDashboard extends StatelessWidget {
  const ModernDashboard({
    super.key,
    required this.userName,
    required this.totalTasks,
    required this.completedTasks,
    required this.courses,
    required this.tasks,
    required this.onCoursesTap,
    required this.onTasksTap,
    required this.onAddCourse,
    required this.onAddTask,
    required this.onToggleTask,
  });

  final String userName;
  final int totalTasks;
  final int completedTasks;
  final List<StudyCourse> courses;
  final List<StudyTask> tasks;
  final VoidCallback onCoursesTap;
  final VoidCallback onTasksTap;
  final VoidCallback onAddCourse;
  final VoidCallback onAddTask;
  final void Function(StudyTask, bool) onToggleTask;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final greeting = _getGreeting(now.hour);
    final previewTasks = tasks.where((t) => !t.isCompleted).take(3).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 100),
      children: [
        // Greeting with animation
        Row(
          children: [
            Text(
              _getEmoji(now.hour),
              style: const TextStyle(fontSize: 32),
            ).animate().scale(delay: 100.ms, duration: 600.ms),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    greeting,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                  ).animate().fadeIn().slideX(begin: -0.2, end: 0),
                  Text(
                    userName.isNotEmpty ? userName : 'Étudiant·e',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  )
                      .animate(delay: 100.ms)
                      .fadeIn()
                      .slideX(begin: -0.2, end: 0),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Modern Progress Card
        ModernProgressCard(
          totalTasks: totalTasks,
          completedTasks: completedTasks,
          totalCourses: courses.length,
        ),
        const SizedBox(height: 24),

        // Quick Stats
        Row(
          children: [
            Expanded(
              child: AnimatedStatCard(
                icon: Icons.schedule_rounded,
                value: _getStudyTime(),
                label: 'Temps d\'étude',
                color: const Color(0xFF6750A4),
                delay: 600.ms,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AnimatedStatCard(
                icon: Icons.trending_up_rounded,
                value: _getProductivity(),
                label: 'Productivité',
                color: const Color(0xFF00A86B),
                delay: 700.ms,
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),

        // Courses Section
        _SectionHeader(
          icon: Icons.school_rounded,
          title: 'Mes cours',
          actionLabel: 'Tout voir',
          onActionPressed: onCoursesTap,
        ).animate(delay: 800.ms).fadeIn().slideX(begin: -0.2, end: 0),
        const SizedBox(height: 12),

        if (courses.isEmpty)
          _EmptyStateCard(
            icon: Icons.school_outlined,
            title: 'Aucun cours',
            subtitle: 'Ajoute tes premiers cours',
            actionLabel: 'Ajouter un cours',
            onAction: onAddCourse,
            delay: 900.ms,
          )
        else
          ...courses.take(2).toList().asMap().entries.map(
                (entry) => AnimatedCourseCard(
                  title: entry.value.title,
                  code: entry.value.code,
                  professor: entry.value.professor,
                  room: entry.value.room,
                  onTap: onCoursesTap,
                  delay: (900 + entry.key * 100).ms,
                ),
              ),

        const SizedBox(height: 28),

        // Tasks Section
        _SectionHeader(
          icon: Icons.checklist_rounded,
          title: 'Tâches à faire',
          actionLabel: 'Tout voir',
          onActionPressed: onTasksTap,
        ).animate(delay: 1100.ms).fadeIn().slideX(begin: -0.2, end: 0),
        const SizedBox(height: 12),

        if (previewTasks.isEmpty)
          _EmptyStateCard(
            icon: Icons.task_alt_rounded,
            title: 'Aucune tâche',
            subtitle: 'Commence par créer une tâche',
            actionLabel: 'Ajouter une tâche',
            onAction: onAddTask,
            delay: 1200.ms,
          )
        else
          ...previewTasks.asMap().entries.map(
                (entry) => ModernTaskCard(
                  title: entry.value.title,
                  description: entry.value.description,
                  isCompleted: entry.value.isCompleted,
                  priority: entry.value.priority,
                  onChanged: (value) => onToggleTask(entry.value, value),
                  delay: (1200 + entry.key * 100).ms,
                ),
              ),

        const SizedBox(height: 28),

        // Motivational Quote Card
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.tertiaryContainer,
                Theme.of(context).colorScheme.secondaryContainer,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.format_quote_rounded,
                color: Theme.of(context).colorScheme.tertiary,
                size: 32,
              ),
              const SizedBox(height: 12),
              Text(
                _getMotivationalQuote(),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onTertiaryContainer,
                      height: 1.4,
                    ),
              ),
            ],
          ),
        )
            .animate(delay: 1500.ms)
            .fadeIn(duration: 600.ms)
            .slideY(begin: 0.2, end: 0, duration: 600.ms),
      ],
    );
  }

  String _getGreeting(int hour) {
    if (hour < 12) return 'Bonjour';
    if (hour < 18) return 'Bon après-midi';
    return 'Bonsoir';
  }

  String _getEmoji(int hour) {
    if (hour < 12) return '🌅';
    if (hour < 18) return '☀️';
    return '🌙';
  }

  String _getStudyTime() {
    return '2.5h'; // Placeholder - integrate with real data
  }

  String _getProductivity() {
    if (totalTasks == 0) return '0%';
    return '${((completedTasks / totalTasks) * 100).toInt()}%';
  }

  String _getMotivationalQuote() {
    final quotes = [
      'Un petit pas aujourd\'hui, une grande réussite demain.',
      'Chaque effort compte, continue comme ça !',
      'La constance est la clé du succès.',
      'Tu progresses chaque jour, félicitations !',
      'Crois en toi et en tes capacités.',
    ];
    return quotes[DateTime.now().day % quotes.length];
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.actionLabel,
    required this.onActionPressed,
  });

  final IconData icon;
  final String title;
  final String actionLabel;
  final VoidCallback onActionPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary, size: 24),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        TextButton(
          onPressed: onActionPressed,
          child: Text(actionLabel),
        ),
      ],
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
    required this.delay,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 40,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add_rounded),
              label: Text(actionLabel),
            ),
          ],
        ),
      ),
    ).animate(delay: delay).fadeIn(duration: 400.ms).scale(
          begin: const Offset(0.9, 0.9),
          end: const Offset(1, 1),
          duration: 400.ms,
        );
  }
}
