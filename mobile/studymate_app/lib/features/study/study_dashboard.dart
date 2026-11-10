import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/local/usage_tracker.dart';
import '../../data/models/study_models.dart';
import '../../data/services/studymate_api.dart';
import '../../state/study_controller.dart';
import 'quiz_page.dart';

const _dayLetters = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

String _duration(int seconds) {
  final minutes = seconds ~/ 60;
  if (minutes < 1) return seconds == 0 ? '0 min' : '< 1 min';
  if (minutes < 60) return '$minutes min';
  final rest = minutes % 60;
  return rest == 0 ? '${minutes ~/ 60} h' : '${minutes ~/ 60} h ${rest.toString().padLeft(2, '0')}';
}

String _pct(double? ratio) => ratio == null ? '—' : '${(ratio * 100).round()} %';

/// Tableau de bord des révisions : temps passé dans l'app, quiz, maîtrise
/// des flashcards, parcours par cours, notes et toutes les données.
class StudyDashboardSection extends StatefulWidget {
  const StudyDashboardSection({
    super.key,
    required this.controller,
    required this.onRefresh,
    required this.onOpenEvaluations,
  });

  final StudyController controller;
  final Future<void> Function() onRefresh;
  final VoidCallback onOpenEvaluations;

  @override
  State<StudyDashboardSection> createState() => _StudyDashboardSectionState();
}

class _StudyDashboardSectionState extends State<StudyDashboardSection> {
  List<({DateTime day, int seconds})> _usage = const [];
  int _streak = 0;
  List<QuizResult> _quizzes = const [];
  Map<String, StudyFlashcardDeckProgress> _progress = const {};
  bool _loading = true;
  bool _offline = false;

  StudyController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    var usage = const <({DateTime day, int seconds})>[];
    var streak = 0;
    var quizzes = const <QuizResult>[];
    try {
      usage = await UsageTracker.instance.lastDays(7);
      streak = await UsageTracker.instance.streak();
      quizzes = await UsageTracker.instance.quizHistory(limit: 5);
    } catch (_) {
      // Statistiques locales indisponibles : le reste du tableau s'affiche.
    }
    final progress = <String, StudyFlashcardDeckProgress>{};
    var offline = false;
    try {
      final results = await Future.wait([
        for (final deck in _c.flashcardDecks) _c.getFlashcardDeckProgress(deck.id),
      ]);
      for (final item in results) {
        progress[item.deckId] = item;
      }
    } on StudyMateApiException catch (_) {
      offline = true;
    }
    if (!mounted) return;
    setState(() {
      _usage = usage;
      _streak = streak;
      _quizzes = quizzes;
      _progress = progress;
      _offline = offline;
      _loading = false;
    });
  }

  Future<void> _refresh() async {
    await widget.onRefresh();
    await _load();
  }

  Future<void> _startQuiz() async {
    final decks = _c.flashcardDecks;
    final choice = await showModalBottomSheet<Object>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Text('Quiz sur quel jeu ?', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.all_inclusive_rounded),
              title: const Text('Tous mes jeux'),
              onTap: () => Navigator.pop(context, 'all'),
            ),
            for (final deck in decks)
              ListTile(
                leading: const Icon(Icons.style_rounded),
                title: Text(deck.title),
                subtitle: _progress[deck.id] == null
                    ? null
                    : Text('${_progress[deck.id]!.totalCards} cartes'),
                onTap: () => Navigator.pop(context, deck),
              ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => QuizPage(
          controller: _c,
          deck: choice is StudyFlashcardDeck ? choice : null,
        ),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) => RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          children: [
            _TimeCard(usage: _usage, streak: _streak, loading: _loading),
            const SizedBox(height: 16),
            _QuizCard(quizzes: _quizzes, onStart: _c.flashcardDecks.isEmpty ? null : _startQuiz),
            const SizedBox(height: 16),
            _FlashcardsCard(decks: _c.flashcardDecks, progress: _progress, offline: _offline),
            const SizedBox(height: 16),
            _CoursePathCard(controller: _c, progress: _progress),
            const SizedBox(height: 16),
            _GradesCard(
              summary: _c.evaluationSummary,
              count: _c.evaluations.length,
              onOpen: widget.onOpenEvaluations,
            ),
            const SizedBox(height: 16),
            _AllDataCard(controller: _c, progress: _progress, quizCount: _quizzes.length),
          ],
        ),
      ),
    );
  }
}

// ── Cartes ──────────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.child,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
                  if (trailing != null) trailing!,
                ],
              ),
              const SizedBox(height: 14),
              child,
            ],
          ),
        ),
      );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          Text(
            label,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
          ),
        ],
      );
}

/// Barre de progression mono-teinte, valeur écrite à côté (jamais la couleur seule).
class _Bar extends StatelessWidget {
  const _Bar({required this.label, required this.ratio, required this.caption});

  final String label;
  final double ratio;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              Text(_pct(ratio), style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio.clamp(0, 1),
              minHeight: 8,
              color: colors.primary,
              backgroundColor: colors.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 4),
          Text(caption, style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12)),
        ],
      ),
    );
  }
}

class _TimeCard extends StatefulWidget {
  const _TimeCard({required this.usage, required this.streak, required this.loading});

  final List<({DateTime day, int seconds})> usage;
  final int streak;
  final bool loading;

  @override
  State<_TimeCard> createState() => _TimeCardState();
}

class _TimeCardState extends State<_TimeCard> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final usage = widget.usage;
    final today = usage.isEmpty ? 0 : usage.last.seconds;
    final week = usage.fold<int>(0, (sum, d) => sum + d.seconds);
    final maxSeconds = usage.fold<int>(60, (m, d) => d.seconds > m ? d.seconds : m);
    final selected = _selected ?? (usage.isEmpty ? null : usage.length - 1);
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppGradients.brand,
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.timer_outlined, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Temps passé dans StudyMate',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _WhiteStat(value: _duration(today), label: 'aujourd’hui')),
              Expanded(child: _WhiteStat(value: _duration(week), label: 'cette semaine')),
              Expanded(
                child: _WhiteStat(
                  value: '${widget.streak} j',
                  label: widget.streak > 1 ? 'jours d’affilée 🔥' : 'série en cours',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (usage.isNotEmpty) ...[
            SizedBox(
              height: 110,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < usage.length; i++)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque, // cible plus large que la barre
                        onTap: () => setState(() => _selected = i),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (selected == i)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  _duration(usage[i].seconds),
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800),
                                ),
                              ),
                            // La barre occupe la place restante : jamais de
                            // débordement, quelle que soit la taille du texte.
                            Expanded(
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: FractionallySizedBox(
                                  heightFactor:
                                      (usage[i].seconds / maxSeconds).clamp(0.04, 1.0).toDouble(),
                                  child: Container(
                                    width: 14,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: selected == i ? 1 : 0.55),
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _dayLetters[usage[i].day.weekday - 1],
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: selected == i ? 1 : 0.75),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Touchez une barre pour voir le détail · mesuré sur ce téléphone',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11),
            ),
          ] else if (widget.loading)
            LinearProgressIndicator(color: colors.onPrimary),
        ],
      ),
    );
  }
}

class _WhiteStat extends StatelessWidget {
  const _WhiteStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11.5)),
        ],
      );
}

class _QuizCard extends StatelessWidget {
  const _QuizCard({required this.quizzes, required this.onStart});

  final List<QuizResult> quizzes;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final average = quizzes.isEmpty
        ? null
        : quizzes.fold<double>(0, (sum, q) => sum + q.ratio) / quizzes.length;
    return _Section(
      icon: Icons.quiz_rounded,
      title: 'Quiz',
      trailing: average == null ? null : Text('moy. ${_pct(average)}',
          style: TextStyle(color: colors.onSurfaceVariant, fontWeight: FontWeight.w700)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            onStart == null
                ? 'Génère d’abord un jeu de flashcards pour pouvoir faire un quiz.'
                : 'Un QCM de 10 questions tiré de tes flashcards. La note rejoint tes évaluations.',
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onStart,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Lancer un quiz'),
          ),
          if (quizzes.isNotEmpty) ...[
            const SizedBox(height: 14),
            for (final quiz in quizzes)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      quiz.ratio >= 0.5 ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
                      size: 18,
                      color: quiz.ratio >= 0.5 ? AppPalette.mint : AppPalette.coral,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(quiz.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    Text('${quiz.score}/${quiz.total}', style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(width: 8),
                    Text(
                      '${quiz.at.day}/${quiz.at.month}',
                      style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _FlashcardsCard extends StatelessWidget {
  const _FlashcardsCard({required this.decks, required this.progress, required this.offline});

  final List<StudyFlashcardDeck> decks;
  final Map<String, StudyFlashcardDeckProgress> progress;
  final bool offline;

  @override
  Widget build(BuildContext context) {
    final all = progress.values.toList();
    final cards = all.fold<int>(0, (s, p) => s + p.totalCards);
    final mastered = all.fold<int>(0, (s, p) => s + p.masteredCards);
    final correct = all.fold<int>(0, (s, p) => s + p.correctAnswers);
    final reviews = all.fold<int>(0, (s, p) => s + p.totalReviews);
    return _Section(
      icon: Icons.style_rounded,
      title: 'Notes des flashcards',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (offline)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text('Hors ligne : statistiques des cartes indisponibles.',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
          Row(
            children: [
              Expanded(child: _Stat(value: '$cards', label: 'cartes')),
              Expanded(child: _Stat(value: '$mastered', label: 'maîtrisées')),
              Expanded(child: _Stat(value: reviews == 0 ? '—' : _pct(correct / reviews), label: 'réussite')),
            ],
          ),
          const SizedBox(height: 16),
          if (decks.isEmpty)
            const Text('Aucun jeu pour le moment.')
          else
            for (final deck in decks)
              if (progress[deck.id] case final p?)
                _Bar(
                  label: deck.title,
                  ratio: p.totalCards == 0 ? 0 : p.masteredCards / p.totalCards,
                  caption: '${p.masteredCards}/${p.totalCards} maîtrisées · '
                      '${p.totalReviews} révisions · réussite ${_pct(p.accuracyRate)}',
                ),
        ],
      ),
    );
  }
}

class _CoursePathCard extends StatelessWidget {
  const _CoursePathCard({required this.controller, required this.progress});

  final StudyController controller;
  final Map<String, StudyFlashcardDeckProgress> progress;

  @override
  Widget build(BuildContext context) {
    final courses = controller.courses;
    final averages = {
      for (final a in controller.evaluationSummary?.courseAverages ?? const <StudyCourseEvaluationAverage>[])
        if (a.courseId != null) a.courseId!: a.averagePercentage,
    };
    return _Section(
      icon: Icons.route_rounded,
      title: 'Parcours de cours',
      child: courses.isEmpty
          ? const Text('Ajoute tes cours pour suivre ta progression.')
          : Column(
              children: [
                for (final course in courses) _row(course, averages[course.id]),
                Text(
                  'Progression = moyenne des tâches terminées et des cartes maîtrisées du cours.',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11.5),
                ),
              ],
            ),
    );
  }

  Widget _row(StudyCourse course, double? average) {
    final tasks = controller.tasks.where((t) => t.courseId == course.id).toList();
    final done = tasks.where((t) => t.isCompleted).length;
    final decks = controller.flashcardDecks.where((d) => d.courseId == course.id);
    var cards = 0;
    var mastered = 0;
    for (final deck in decks) {
      final p = progress[deck.id];
      if (p == null) continue;
      cards += p.totalCards;
      mastered += p.masteredCards;
    }
    final notes = controller.notes.where((n) => n.courseId == course.id).length;
    final parts = <double>[
      if (tasks.isNotEmpty) done / tasks.length,
      if (cards > 0) mastered / cards,
    ];
    final ratio = parts.isEmpty ? 0.0 : parts.reduce((a, b) => a + b) / parts.length;
    return _Bar(
      label: course.title,
      ratio: ratio,
      caption: [
        '$done/${tasks.length} tâches',
        if (cards > 0) '$mastered/$cards cartes',
        '$notes notes',
        if (average != null) 'moyenne ${average.round()} %',
      ].join(' · '),
    );
  }
}

class _GradesCard extends StatelessWidget {
  const _GradesCard({required this.summary, required this.count, required this.onOpen});

  final StudyEvaluationSummary? summary;
  final int count;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final average = summary?.averagePercentage;
    return _Section(
      icon: Icons.grade_rounded,
      title: 'Mes notes',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: _Stat(value: average == null ? '—' : '${average.round()} %', label: 'moyenne générale')),
              Expanded(child: _Stat(value: '${summary?.gradedCount ?? 0}', label: 'notes')),
              Expanded(child: _Stat(value: '$count', label: 'évaluations')),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onOpen,
            icon: const Icon(Icons.edit_note_rounded),
            label: const Text('Gérer mes examens et devoirs'),
          ),
        ],
      ),
    );
  }
}

class _AllDataCard extends StatelessWidget {
  const _AllDataCard({required this.controller, required this.progress, required this.quizCount});

  final StudyController controller;
  final Map<String, StudyFlashcardDeckProgress> progress;
  final int quizCount;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final cards = progress.values.fold<int>(0, (s, p) => s + p.totalCards);
    final tiles = [
      (Icons.school_rounded, '${c.courses.length}', 'cours'),
      (Icons.task_alt_rounded, '${c.completedTaskCount}/${c.tasks.length}', 'tâches faites'),
      (Icons.description_rounded, '${c.notes.length}', 'notes'),
      (Icons.style_rounded, '${c.flashcardDecks.length}', 'jeux'),
      (Icons.layers_rounded, '$cards', 'flashcards'),
      (Icons.grade_rounded, '${c.evaluations.length}', 'évaluations'),
      (Icons.quiz_rounded, '$quizCount', 'quiz récents'),
      (Icons.cloud_upload_rounded, '${c.pendingChanges}', 'en attente'),
    ];
    return _Section(
      icon: Icons.dataset_rounded,
      title: 'Toutes mes données',
      child: GridView(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 10,
          crossAxisSpacing: 8,
          // Hauteur fixe : tient même avec une grande taille de police.
          mainAxisExtent: 96,
        ),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (final (icon, value, label) in tiles)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 4),
                  FittedBox(
                    child: Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10.5, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
