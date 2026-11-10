import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/study_models.dart';

/// En-tête de l'accueil : salutation selon l'heure, anneau de progression
/// animé et statistiques sur un fond dégradé qui suit la journée.
class DashboardHero extends StatelessWidget {
  const DashboardHero({
    super.key,
    required this.name,
    required this.dateLabel,
    required this.completed,
    required this.total,
    required this.courseCount,
    required this.noteCount,
  });

  final String? name;
  final String dateLabel;
  final int completed;
  final int total;
  final int courseCount;
  final int noteCount;

  static String greetingFor(int hour) {
    if (hour >= 5 && hour < 12) return 'Bonjour';
    if (hour >= 12 && hour < 18) return 'Bon après-midi';
    return 'Bonsoir';
  }

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final progress = total == 0 ? 0.0 : completed / total;
    final firstName = name?.trim().split(' ').first;
    final mood = total == 0
        ? 'Ajoute ta première tâche pour lancer ta journée.'
        : progress >= 1
            ? 'Tout est fait. Bravo, profite de ta pause !'
            : progress >= 0.5
                ? 'Plus que ${total - completed} — tu y es presque.'
                : '${total - completed} tâches t’attendent. On s’y met ?';

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
      decoration: BoxDecoration(
        gradient: AppGradients.forHour(hour),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: AppPalette.violet.withValues(alpha: 0.30),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -50,
            top: -60,
            child: _halo(170),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _GlassPill(
                          icon: Icons.calendar_today_rounded,
                          label: dateLabel,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          firstName == null || firstName.isEmpty
                              ? '${greetingFor(hour)} 👋'
                              : '${greetingFor(hour)}, $firstName 👋',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 25,
                            height: 1.15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          mood,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.88),
                            fontSize: 13.5,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ProgressRing(progress: progress, size: 88),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _HeroStat(
                      icon: Icons.task_alt_rounded,
                      value: '$completed/$total',
                      label: 'tâches',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _HeroStat(
                      icon: Icons.school_rounded,
                      value: '$courseCount',
                      label: 'cours',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _HeroStat(
                      icon: Icons.auto_stories_rounded,
                      value: '$noteCount',
                      label: 'notes',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _halo(double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              Colors.white.withValues(alpha: 0.30),
              Colors.white.withValues(alpha: 0),
            ],
          ),
        ),
      );
}

/// Anneau de progression qui se remplit en douceur.
class ProgressRing extends StatelessWidget {
  const ProgressRing({super.key, required this.progress, this.size = 80});

  final double progress;
  final double size;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: progress.clamp(0, 1)),
        duration: const Duration(milliseconds: 1100),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) => SizedBox.square(
          dimension: size,
          child: CustomPaint(
            painter: _RingPainter(value),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${(value * 100).round()}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'fait',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value);

  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 9.0;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);
    canvas.drawArc(
      arcRect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = Colors.white.withValues(alpha: 0.22),
    );
    if (value <= 0) return;
    canvas.drawArc(
      arcRect,
      -math.pi / 2,
      math.pi * 2 * value,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = const SweepGradient(
          colors: [Colors.white, Color(0xFFB9FFF0), Colors.white],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.value != value;
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _GlassPill extends StatelessWidget {
  const _GlassPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 13),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      );
}

/// Raccourci coloré (Agenda, Réviser, etc.).
class QuickAction extends StatelessWidget {
  const QuickAction({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: color.withValues(alpha: isDark ? 0.16 : 0.10),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mise en avant de la prochaine tâche à faire.
class FocusTaskCard extends StatelessWidget {
  const FocusTaskCard({
    super.key,
    required this.task,
    required this.remaining,
    required this.onDone,
  });

  final StudyTask task;
  final int remaining;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final deadline = task.deadline;
    final dueLabel = deadline == null ? null : _dueLabel(deadline);
    final urgent =
        deadline != null && deadline.difference(DateTime.now()).inHours < 48;
    final accent = urgent ? AppPalette.coral : AppPalette.indigo;

    return Card(
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 6, color: accent),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.bolt_rounded, color: accent, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          'FOCUS DU MOMENT',
                          style: TextStyle(
                            color: accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                        const Spacer(),
                        if (remaining > 1)
                          Text(
                            '+${remaining - 1} ensuite',
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      task.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _Tag(
                          label: 'Priorité ${_priority(task.priority)}',
                          color: _priorityColor(task.priority),
                        ),
                        if (dueLabel != null) ...[
                          const SizedBox(width: 6),
                          _Tag(
                            label: dueLabel,
                            color: urgent ? AppPalette.coral : AppPalette.sky,
                            icon: Icons.schedule_rounded,
                          ),
                        ],
                        const Spacer(),
                        FilledButton.tonalIcon(
                          onPressed: onDone,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: const Icon(Icons.check_rounded, size: 18),
                          label: const Text('Fait'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _dueLabel(DateTime deadline) {
    final today = DateUtils.dateOnly(DateTime.now());
    final days = DateUtils.dateOnly(deadline).difference(today).inDays;
    if (days < 0) return 'En retard';
    if (days == 0) return 'Aujourd’hui';
    if (days == 1) return 'Demain';
    return 'Dans $days j';
  }

  static String _priority(String value) => switch (value) {
        'high' => 'haute',
        'low' => 'basse',
        _ => 'moyenne',
      };

  static Color _priorityColor(String value) => switch (value) {
        'high' => AppPalette.coral,
        'low' => AppPalette.mint,
        _ => AppPalette.amber,
      };
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 3),
            ],
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
}

/// Carte de cours compacte pour le carrousel de l'accueil.
class CourseTile extends StatelessWidget {
  const CourseTile({super.key, required this.course, required this.onTap});

  final StudyCourse course;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = AppPalette.accentFor(course.id);
    final colors = Theme.of(context).colorScheme;
    final meta = [
      if (course.room?.isNotEmpty == true) course.room!,
      if (course.professor?.isNotEmpty == true) course.professor!,
    ].join(' · ');

    return SizedBox(
      width: 190,
      child: Card(
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [color, color.withValues(alpha: 0.7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.menu_book_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const Spacer(),
                    if (course.code?.isNotEmpty == true)
                      Text(
                        course.code!,
                        style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                Text(
                  course.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  meta.isEmpty ? 'Cours' : meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Conseil du jour : change chaque jour.
class DailyTipCard extends StatelessWidget {
  const DailyTipCard({super.key});

  static const _tips = [
    (
      'Méthode Pomodoro',
      'Révise 25 minutes, puis accorde-toi 5 minutes de pause.'
    ),
    (
      'Rappel actif',
      'Ferme ton cours et récite-le : c’est 2× plus efficace que relire.'
    ),
    (
      'Répétition espacée',
      'Revois tes fiches à J+1, J+3 puis J+7 pour tout retenir.'
    ),
    (
      'Une chose à la fois',
      'Range ton téléphone loin de toi pendant tes sessions.'
    ),
    ('Explique-le', 'Si tu peux l’expliquer simplement, tu l’as compris.'),
    (
      'Petit départ',
      'Commence par la tâche la plus courte pour lancer ta dynamique.'
    ),
    (
      'Sommeil',
      'Une bonne nuit consolide ce que tu as appris dans la journée.'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year)).inDays;
    final (title, body) = _tips[dayOfYear % _tips.length];
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppPalette.mint,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.lightbulb_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CONSEIL DU JOUR · $title',
                  style: TextStyle(
                    color: colors.onSecondaryContainer,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  body,
                  style: TextStyle(
                    color: colors.onSecondaryContainer,
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
