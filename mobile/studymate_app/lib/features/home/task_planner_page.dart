import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/planning_models.dart';
import '../../data/services/studymate_api.dart';
import '../../state/study_controller.dart';
import '../insights/ai_consent.dart';

const _days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];

String _hm(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

String _duration(int minutes) {
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0 ? '$hours h' : '$hours h ${rest.toString().padLeft(2, '0')}';
}

/// Planning intelligent : les tâches sont classées par score de priorité et
/// placées automatiquement dans les créneaux libres (hors cours, événements
/// et jours fériés) avant leur échéance.
class TaskPlannerPage extends StatefulWidget {
  const TaskPlannerPage({
    super.key,
    required this.controller,
    required this.onTasksChanged,
  });

  final StudyController controller;
  final Future<void> Function() onTasksChanged;

  @override
  State<TaskPlannerPage> createState() => _TaskPlannerPageState();
}

class _TaskPlannerPageState extends State<TaskPlannerPage> {
  int _days = 7;
  TaskPlan? _plan;
  String? _error;
  bool _loading = true;
  String? _breakingDownId;

  StudyMateApi get _api => widget.controller.api;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final plan = await _api.getTaskPlan(days: _days);
      if (mounted) setState(() => _plan = plan);
    } on StudyMateApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _breakdown(PlannedTask task) async {
    try {
      final allowed = await ensureAiConsent(
        context,
        _api,
        purpose:
            'Pour découper « ${task.title} », StudyMate envoie le titre et '
            'la description de la tâche (et uniquement eux) à un modèle d’IA.',
      );
      if (!allowed || !mounted) return;
      setState(() => _breakingDownId = task.taskId);
      final steps = await _api.breakdownTask(task.taskId, createTasks: true);
      await widget.onTasksChanged();
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        builder: (_) => _StepsSheet(task: task, steps: steps),
      );
      await _load();
    } on StudyMateApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _breakingDownId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    return Scaffold(
      appBar: AppBar(title: const Text('Planning intelligent')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
          children: [
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 3, label: Text('3 jours')),
                ButtonSegment(value: 7, label: Text('7 jours')),
                ButtonSegment(value: 14, label: Text('14 jours')),
              ],
              selected: {_days},
              onSelectionChanged: (value) {
                setState(() => _days = value.first);
                _load();
              },
            ),
            const SizedBox(height: 14),
            if (_loading && plan == null)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null && plan == null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 10),
                      FilledButton.tonal(
                          onPressed: _load, child: const Text('Réessayer')),
                    ],
                  ),
                ),
              )
            else if (plan != null) ...[
              _PlanHeader(plan: plan),
              const SizedBox(height: 16),
              if (plan.items.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Icon(Icons.celebration_rounded,
                            size: 40, color: AppPalette.mint),
                        const SizedBox(height: 10),
                        Text(
                          'Aucune tâche à planifier. Bravo !',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                )
              else
                for (var index = 0; index < plan.items.length; index++) ...[
                  _PlannedTaskCard(
                    rank: index + 1,
                    task: plan.items[index],
                    busy: _breakingDownId == plan.items[index].taskId,
                    onBreakdown: _breakingDownId == null
                        ? () => _breakdown(plan.items[index])
                        : null,
                  ),
                  const SizedBox(height: 10),
                ],
              const SizedBox(height: 6),
              Text(
                'Score = urgence de l’échéance (50) + priorité (25) + coefficient '
                'du cours (15) + difficulté perçue (10). Sessions de 25 à 90 min '
                'entre 8 h et 20 h, avec 10 min de pause.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PlanHeader extends StatelessWidget {
  const _PlanHeader({required this.plan});

  final TaskPlan plan;

  @override
  Widget build(BuildContext context) {
    final planned = plan.items.where((t) => t.status == 'planned').length;
    final late = plan.items.where((t) => t.status == 'overdue').length;
    final blocked = plan.items
        .where((t) => t.status == 'unplanned' || t.status == 'partial')
        .length;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppGradients.forHour(DateTime.now().hour),
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            plan.items.isEmpty
                ? 'Rien à planifier sur ${plan.days} jours.'
                : '$planned/${plan.items.length} tâches casées sur ${plan.days} jours',
            style: const TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            [
              '${_duration(plan.freeMinutes)} encore libres',
              if (late > 0) '$late en retard',
              if (blocked > 0) '$blocked sans assez de place',
            ].join(' · '),
            style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
          ),
          if (plan.holidays.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '🎉 Jours fériés pris en compte : '
              '${plan.holidays.map((h) => '${h.label} (${h.date.day}/${h.date.month})').join(', ')}',
              style: const TextStyle(color: Colors.white, fontSize: 12.5),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlannedTaskCard extends StatelessWidget {
  const _PlannedTaskCard({
    required this.rank,
    required this.task,
    required this.busy,
    required this.onBreakdown,
  });

  final int rank;
  final PlannedTask task;
  final bool busy;
  final VoidCallback? onBreakdown;

  (String, Color, IconData) get _status => switch (task.status) {
        'planned' => (
            'Planifiée',
            AppPalette.mint,
            Icons.event_available_rounded
          ),
        'partial' => ('Partielle', AppPalette.amber, Icons.timelapse_rounded),
        'overdue' => (
            'En retard',
            AppPalette.coral,
            Icons.error_outline_rounded
          ),
        _ => ('Pas de créneau', AppPalette.coral, Icons.event_busy_rounded),
      };

  Color get _scoreColor => task.score >= 70
      ? AppPalette.coral
      : task.score >= 45
          ? AppPalette.amber
          : AppPalette.mint;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (label, statusColor, statusIcon) = _status;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox.square(
                  dimension: 48,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: task.score / 100,
                        strokeWidth: 5,
                        color: _scoreColor,
                        backgroundColor: _scoreColor.withValues(alpha: 0.15),
                      ),
                      Text(
                        task.score.round().toString(),
                        style: TextStyle(
                            fontWeight: FontWeight.w800, color: _scoreColor),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('#$rank',
                          style: TextStyle(
                              color: colors.onSurfaceVariant, fontSize: 12)),
                      Text(task.title,
                          style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        label,
                        style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (task.reasons.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final reason in task.reasons)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(reason, style: const TextStyle(fontSize: 12)),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'Durée estimée ${_duration(task.estimatedMinutes)}'
              '${task.plannedMinutes > 0 ? ' · ${_duration(task.plannedMinutes)} planifiées' : ''}',
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12.5),
            ),
            if (task.sessions.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final session in task.sessions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(Icons.schedule_rounded,
                          size: 16, color: colors.primary),
                      const SizedBox(width: 6),
                      Text(
                        '${_days[session.startsAt.weekday - 1]} ${session.startsAt.day}/'
                        '${session.startsAt.month} · ${_hm(session.startsAt)}–${_hm(session.endsAt)}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _duration(session.minutes),
                        style: TextStyle(
                            color: colors.onSurfaceVariant, fontSize: 12),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onBreakdown,
                icon: busy
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome_rounded, size: 18),
                label: Text(busy ? 'L’IA découpe…' : 'Découper avec l’IA'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepsSheet extends StatelessWidget {
  const _StepsSheet({required this.task, required this.steps});

  final PlannedTask task;
  final List<TaskBreakdownStep> steps;

  @override
  Widget build(BuildContext context) {
    final total = steps.fold<int>(0, (sum, step) => sum + step.minutes);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Plan d’action',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              '${steps.length} sous-tâches ajoutées pour « ${task.title} » · ${_duration(total)} au total',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            for (var index = 0; index < steps.length; index++)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  radius: 15,
                  backgroundColor: AppPalette.violet,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w800),
                  ),
                ),
                title: Text(steps[index].title,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                trailing: Text(_duration(steps[index].minutes)),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Parfait'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
