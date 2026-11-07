import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../data/models/study_models.dart';
import 'widgets/widgets.dart';

class CreativeDashboard extends StatelessWidget {
  const CreativeDashboard({
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
    required this.onNotesTab,
    required this.onStudyTab,
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
  final VoidCallback onNotesTab;
  final VoidCallback onStudyTab;

  @override
  Widget build(BuildContext context) {
    final pendingTasks = tasks.where((t) => !t.isCompleted).toList();
    final urgentTasks = pendingTasks.take(2).toList();

    return CustomScrollView(
      slivers: [
        // Hero Header
        SliverToBoxAdapter(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.secondary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _getGreeting(),
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 16,
                                ),
                              ).animate().fadeIn().slideX(begin: -0.2, end: 0),
                              const SizedBox(height: 4),
                              Text(
                                userName.isNotEmpty ? userName : 'Champion',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                                  .animate(delay: 100.ms)
                                  .fadeIn()
                                  .slideX(begin: -0.2, end: 0),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.spa_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        )
                            .animate(onPlay: (controller) => controller.repeat())
                            .rotate(duration: 3000.ms),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Quick Stats Row
                    Row(
                      children: [
                        Expanded(
                          child: _QuickStat(
                            value: '$completedTasks/$totalTasks',
                            label: 'Terminées',
                            icon: Icons.check_circle_outline,
                            delay: 200.ms,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _QuickStat(
                            value: '${courses.length}',
                            label: 'Cours actifs',
                            icon: Icons.school_outlined,
                            delay: 300.ms,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _QuickStat(
                            value: '${pendingTasks.length}',
                            label: 'À faire',
                            icon: Icons.pending_actions,
                            delay: 400.ms,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Content
        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Streak Card
              StreakCard(
                streakDays: _calculateStreak(),
                weekProgress: _getWeekProgress(),
              ),
              const SizedBox(height: 20),

              // Metrics
              Row(
                children: [
                  Expanded(
                    child: MetricIndicator(
                      icon: Icons.timer_outlined,
                      label: 'Temps d\'étude',
                      value: '4.2h',
                      trend: '+12%',
                      color: const Color(0xFF4CAF50),
                      delay: 500.ms,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: MetricIndicator(
                      icon: Icons.bolt_rounded,
                      label: 'Productivité',
                      value: '87%',
                      trend: '+5%',
                      color: const Color(0xFFFF9800),
                      delay: 600.ms,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Quick Actions Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.flash_on_rounded,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Actions rapides',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ).animate(delay: 700.ms).fadeIn().slideX(begin: -0.2, end: 0),
              const SizedBox(height: 16),

              // Action Cards
              FloatingActionCard(
                icon: Icons.book_rounded,
                title: 'Mes Cours',
                subtitle: '${courses.length} cours ce semestre',
                onTap: onCoursesTap,
                color: const Color(0xFF6750A4),
                delay: 800.ms,
              ),
              const SizedBox(height: 12),
              FloatingActionCard(
                icon: Icons.assignment_outlined,
                title: 'Tâches Urgentes',
                subtitle: '${urgentTasks.length} tâches à terminer',
                onTap: onTasksTap,
                color: const Color(0xFFE91E63),
                delay: 900.ms,
              ),
              const SizedBox(height: 12),
              FloatingActionCard(
                icon: Icons.note_add_rounded,
                title: 'Mes Notes',
                subtitle: 'Organise tes idées',
                onTap: onNotesTab,
                color: const Color(0xFF00BCD4),
                delay: 1000.ms,
              ),
              const SizedBox(height: 12),
              FloatingActionCard(
                icon: Icons.psychology_rounded,
                title: 'Outils d\'étude',
                subtitle: 'Flashcards, quiz et plus',
                onTap: onStudyTab,
                color: const Color(0xFF9C27B0),
                delay: 1100.ms,
              ),
              const SizedBox(height: 24),

              // Urgent Tasks Section
              if (urgentTasks.isNotEmpty) ...[
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.red,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Priorités du jour',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ).animate(delay: 1200.ms).fadeIn().slideX(begin: -0.2, end: 0),
                const SizedBox(height: 16),
                ...urgentTasks.asMap().entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ModernTaskCard(
                          title: entry.value.title,
                          description: entry.value.description,
                          isCompleted: entry.value.isCompleted,
                          priority: entry.value.priority,
                          onChanged: (value) =>
                              onToggleTask(entry.value, value),
                          delay: (1300 + entry.key * 100).ms,
                        ),
                      ),
                    ),
              ],

              const SizedBox(height: 24),

              // Motivational Card
              _MotivationalCard(delay: 1500.ms),
              const SizedBox(height: 80),
            ]),
          ),
        ),
      ],
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return '☀️ Bonjour';
    if (hour < 18) return '🌤️ Bon après-midi';
    return '🌙 Bonsoir';
  }

  int _calculateStreak() {
    // TODO: Calculate from real data
    return 7;
  }

  List<bool> _getWeekProgress() {
    // TODO: Get from real data
    return [true, true, true, true, true, false, false];
  }
}

class _QuickStat extends StatelessWidget {
  const _QuickStat({
    required this.value,
    required this.label,
    required this.icon,
    required this.delay,
  });

  final String value;
  final String label;
  final IconData icon;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ).animate(delay: delay).fadeIn(duration: 400.ms).scale(
          begin: const Offset(0.8, 0.8),
          duration: 400.ms,
        );
  }
}

class _MotivationalCard extends StatelessWidget {
  const _MotivationalCard({required this.delay});

  final Duration delay;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667eea).withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.format_quote_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Citation du jour',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '"Le succès c\'est d\'aller d\'échec en échec sans perdre son enthousiasme."',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '- Winston Churchill',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate(delay: delay).fadeIn(duration: 600.ms).slideY(
          begin: 0.2,
          end: 0,
          duration: 600.ms,
        );
  }
}
