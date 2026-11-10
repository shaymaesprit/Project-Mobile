import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/local/usage_tracker.dart';
import '../../data/models/study_models.dart';
import '../../data/services/studymate_api.dart';
import '../../state/study_controller.dart';

/// Nombre minimal de cartes (réponses distinctes) pour faire un QCM à 4 choix.
const quizMinCards = 4;
const _maxQuestions = 10;

class _Question {
  _Question(this.card, this.options);

  final StudyFlashcard card;
  final List<String> options;
  String? picked;

  bool get answered => picked != null;
  bool get correct => picked == card.answer.trim();
}

/// Petit quiz (QCM) généré à partir des flashcards d'un jeu — ou de tous.
///
/// * Chaque réponse est enregistrée comme révision (répétition espacée).
/// * La note finale est sauvegardée comme évaluation « Quiz » et dans
///   l'historique local du tableau de bord.
class QuizPage extends StatefulWidget {
  const QuizPage({super.key, required this.controller, this.deck});

  final StudyController controller;

  /// `null` : toutes les cartes de tous les jeux.
  final StudyFlashcardDeck? deck;

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  final _random = Random();
  List<_Question> _questions = const [];
  int _index = 0;
  bool _loading = true;
  String? _error;
  bool _saved = false;

  String get _title => widget.deck?.title ?? 'Tous mes jeux';

  @override
  void initState() {
    super.initState();
    _build();
  }

  Future<void> _build() async {
    try {
      final decks = widget.deck == null
          ? widget.controller.flashcardDecks
          : [widget.deck!];
      final cards = <StudyFlashcard>[
        for (final deck in decks) ...await widget.controller.getFlashcards(deck.id),
      ];
      final answers = {for (final c in cards) c.answer.trim()}.toList();
      if (answers.length < quizMinCards) {
        setState(() {
          _loading = false;
          _error = 'Il faut au moins $quizMinCards cartes aux réponses '
              'différentes pour un quiz. Génère plus de cartes avec l’IA.';
        });
        return;
      }
      // Les cartes « dues » d'abord, puis le hasard.
      final now = DateTime.now();
      cards.shuffle(_random);
      cards.sort((a, b) {
        final aDue = a.dueAt == null || a.dueAt!.isBefore(now) ? 0 : 1;
        final bDue = b.dueAt == null || b.dueAt!.isBefore(now) ? 0 : 1;
        return aDue - bDue;
      });
      final questions = <_Question>[];
      for (final card in cards.take(_maxQuestions)) {
        final distractors = (answers.where((a) => a != card.answer.trim()).toList()
              ..shuffle(_random))
            .take(3);
        final options = [card.answer.trim(), ...distractors]..shuffle(_random);
        questions.add(_Question(card, options));
      }
      setState(() {
        _questions = questions;
        _loading = false;
      });
    } on StudyMateApiException catch (error) {
      setState(() {
        _loading = false;
        _error = error.message;
      });
    }
  }

  Future<void> _answer(String option) async {
    final question = _questions[_index];
    if (question.answered) return;
    setState(() => question.picked = option);
    try {
      await widget.controller.reviewFlashcard(
        flashcard: question.card,
        isCorrect: question.correct,
      );
    } on StudyMateApiException catch (_) {
      // Hors ligne : le quiz continue, la révision n'est simplement pas comptée.
    }
  }

  Future<void> _next() async {
    if (_index < _questions.length - 1) {
      setState(() => _index++);
      return;
    }
    setState(() => _index = _questions.length); // écran de résultat
    await _saveResult();
  }

  Future<void> _saveResult() async {
    if (_saved) return;
    _saved = true;
    final score = _questions.where((q) => q.correct).length;
    await UsageTracker.instance.saveQuiz(
      QuizResult(title: _title, score: score, total: _questions.length, at: DateTime.now()),
    );
    try {
      await widget.controller.addEvaluation(
        title: 'Quiz · $_title',
        evaluationType: 'quiz',
        score: score.toDouble(),
        maxScore: _questions.length.toDouble(),
        courseId: widget.deck?.courseId,
        scheduledAt: DateTime.now(),
      );
    } on StudyMateApiException catch (_) {
      // Le résultat reste dans l'historique local même hors ligne.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Quiz · $_title')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Text(_error!, textAlign: TextAlign.center),
                  ),
                )
              : _index >= _questions.length
                  ? _ResultView(
                      questions: _questions,
                      onRestart: () {
                        setState(() {
                          _loading = true;
                          _index = 0;
                          _saved = false;
                        });
                        _build();
                      },
                    )
                  : _QuestionView(
                      question: _questions[_index],
                      index: _index,
                      total: _questions.length,
                      onAnswer: _answer,
                      onNext: _next,
                    ),
    );
  }
}

class _QuestionView extends StatelessWidget {
  const _QuestionView({
    required this.question,
    required this.index,
    required this.total,
    required this.onAnswer,
    required this.onNext,
  });

  final _Question question;
  final int index;
  final int total;
  final ValueChanged<String> onAnswer;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Row(
          children: [
            Text(
              'Question ${index + 1} / $total',
              style: TextStyle(color: colors.onSurfaceVariant, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            Text(
              '${(index / total * 100).round()} %',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(value: index / total, minHeight: 6),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: AppGradients.brand,
            borderRadius: BorderRadius.circular(AppTheme.radius),
          ),
          child: Text(
            question.card.question,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 18),
        for (final option in question.options) ...[
          _OptionTile(
            label: option,
            state: !question.answered
                ? _OptionState.idle
                : option == question.card.answer.trim()
                    ? _OptionState.correct
                    : option == question.picked
                        ? _OptionState.wrong
                        : _OptionState.dimmed,
            onTap: () => onAnswer(option),
          ),
          const SizedBox(height: 10),
        ],
        if (question.answered) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                question.correct ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: question.correct ? AppPalette.mint : AppPalette.coral,
              ),
              const SizedBox(width: 8),
              Text(
                question.correct ? 'Bonne réponse !' : 'Pas tout à fait.',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: onNext,
            child: Text(index == total - 1 ? 'Voir mon résultat' : 'Question suivante'),
          ),
        ],
      ],
    );
  }
}

enum _OptionState { idle, correct, wrong, dimmed }

class _OptionTile extends StatelessWidget {
  const _OptionTile({required this.label, required this.state, required this.onTap});

  final String label;
  final _OptionState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (border, fill, icon) = switch (state) {
      _OptionState.correct => (AppPalette.mint, AppPalette.mint.withValues(alpha: 0.12), Icons.check_rounded),
      _OptionState.wrong => (AppPalette.coral, AppPalette.coral.withValues(alpha: 0.12), Icons.close_rounded),
      _OptionState.dimmed => (colors.outlineVariant, colors.surface, null),
      _OptionState.idle => (colors.outlineVariant, colors.surface, null),
    };
    return Material(
      color: fill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: border, width: state == _OptionState.idle ? 1 : 1.8),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: state == _OptionState.idle ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    height: 1.3,
                    color: state == _OptionState.dimmed ? colors.onSurfaceVariant : null,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (icon != null) ...[
                const SizedBox(width: 8),
                Icon(icon, color: border),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({required this.questions, required this.onRestart});

  final List<_Question> questions;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final score = questions.where((q) => q.correct).length;
    final ratio = score / questions.length;
    final (emoji, message) = ratio >= 0.8
        ? ('🏆', 'Excellent, tu maîtrises ce sujet !')
        : ratio >= 0.5
            ? ('💪', 'Bien joué, encore un petit effort.')
            : ('📚', 'Revois ces cartes, tu vas progresser vite.');
    final missed = questions.where((q) => !q.correct).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: AppGradients.brand,
            borderRadius: BorderRadius.circular(AppTheme.radius),
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 44)),
              const SizedBox(height: 8),
              Text(
                '$score / ${questions.length}',
                style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900),
              ),
              Text(
                '${(ratio * 100).round()} % de bonnes réponses',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
              ),
              const SizedBox(height: 8),
              Text(message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Note enregistrée dans tes évaluations (type « Quiz ») et tes cartes '
          'ont été mises à jour pour la répétition espacée.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        if (missed.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('À revoir', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final q in missed)
            Card(
              child: ListTile(
                title: Text(q.card.question, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('✔ ${q.card.answer}'),
                ),
              ),
            ),
        ],
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Terminer'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: onRestart,
                icon: const Icon(Icons.replay_rounded),
                label: const Text('Rejouer'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
