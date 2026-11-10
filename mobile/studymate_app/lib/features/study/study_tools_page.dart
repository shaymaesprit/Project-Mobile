import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/study_models.dart';
import '../../data/services/studymate_api.dart';
import '../../state/study_controller.dart';
import 'flashcard_generate_page.dart';
import 'study_dashboard.dart';

class StudyToolsPage extends StatefulWidget {
  const StudyToolsPage({
    super.key,
    required this.controller,
    required this.onRefresh,
  });

  final StudyController controller;
  final Future<void> Function() onRefresh;

  @override
  State<StudyToolsPage> createState() => _StudyToolsPageState();
}

class _StudyToolsPageState extends State<StudyToolsPage> {
  bool _showFlashcards = true;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Révisions et résultats',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 12),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: true,
                      icon: Icon(Icons.style_outlined),
                      label: Text('Flashcards'),
                    ),
                    ButtonSegment(
                      value: false,
                      icon: Icon(Icons.dashboard_rounded),
                      label: Text('Tableau de bord'),
                    ),
                  ],
                  selected: {_showFlashcards},
                  onSelectionChanged: (selection) =>
                      setState(() => _showFlashcards = selection.first),
                ),
              ],
            ),
          ),
          Expanded(
            child: _showFlashcards
                ? _FlashcardDecksSection(
                    controller: widget.controller,
                    onRefresh: widget.onRefresh,
                  )
                : StudyDashboardSection(
                    controller: widget.controller,
                    onRefresh: widget.onRefresh,
                    onOpenEvaluations: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => EvaluationsPage(
                          controller: widget.controller,
                          onRefresh: widget.onRefresh,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      );
}

class _FlashcardDecksSection extends StatelessWidget {
  const _FlashcardDecksSection({
    required this.controller,
    required this.onRefresh,
  });

  final StudyController controller;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Mes jeux de cartes',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _openGenerator(context),
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: const Text('Générer avec l’IA'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (controller.flashcardDecks.isEmpty)
              const _StudyEmptyCard(
                icon: Icons.auto_awesome_outlined,
                title: 'Aucun jeu de flashcards',
                message: 'Choisis une note ou colle un texte : l’IA crée '
                    'les questions et les réponses pour toi.',
              )
            else
              for (final deck in controller.flashcardDecks) ...[
                Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          Theme.of(context).colorScheme.secondaryContainer,
                      child: const Icon(Icons.style_rounded),
                    ),
                    title: Row(
                      children: [
                        Flexible(
                          child: Text(
                            deck.title,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (deck.source == 'ai_generated') ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.auto_awesome_rounded,
                            size: 16,
                            color: AppPalette.violet,
                          ),
                        ],
                      ],
                    ),
                    subtitle: Text(
                      [
                        _courseName(controller, deck.courseId) ?? 'Sans cours',
                        if (deck.description?.isNotEmpty == true)
                          deck.description!,
                      ].join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: PopupMenuButton<_DeckAction>(
                      onSelected: (action) {
                        if (action == _DeckAction.edit) {
                          _openDeckForm(context, deck: deck);
                        } else {
                          _deleteDeck(context, controller, deck);
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: _DeckAction.edit,
                          child: Text('Modifier'),
                        ),
                        PopupMenuItem(
                          value: _DeckAction.delete,
                          child: Text('Supprimer'),
                        ),
                      ],
                    ),
                    onTap: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => FlashcardDeckPage(
                          controller: controller,
                          deck: deck,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
          ],
        ),
      );

  Future<void> _openGenerator(BuildContext context) async {
    final deck = await Navigator.of(context).push<StudyFlashcardDeck>(
      MaterialPageRoute(
        builder: (_) => FlashcardGeneratePage(controller: controller),
      ),
    );
    if (deck == null || !context.mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => FlashcardDeckPage(controller: controller, deck: deck),
      ),
    );
  }

  Future<void> _openDeckForm(
    BuildContext context, {
    StudyFlashcardDeck? deck,
  }) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => FlashcardDeckFormPage(
          controller: controller,
          deck: deck,
        ),
      ),
    );
  }
}

enum _DeckAction { edit, delete }

Future<void> _deleteDeck(
  BuildContext context,
  StudyController controller,
  StudyFlashcardDeck deck,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Supprimer ce jeu ?'),
      content: Text(
        '« ${deck.title} » et toutes ses cartes seront supprimées.',
      ),
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
  if (confirmed == true && context.mounted) {
    await _runStudyAction(
      context,
      () => controller.deleteFlashcardDeck(deck),
    );
  }
}

class FlashcardDeckFormPage extends StatefulWidget {
  const FlashcardDeckFormPage({
    super.key,
    required this.controller,
    this.deck,
  });

  final StudyController controller;
  final StudyFlashcardDeck? deck;

  @override
  State<FlashcardDeckFormPage> createState() => _FlashcardDeckFormPageState();
}

class _FlashcardDeckFormPageState extends State<FlashcardDeckFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  String? _courseId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.deck?.title);
    _descriptionController =
        TextEditingController(text: widget.deck?.description);
    _courseId = widget.deck?.courseId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(
            widget.deck == null ? 'Nouveau jeu' : 'Modifier le jeu',
          ),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextFormField(
                controller: _titleController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nom du jeu *',
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Le nom du jeu est obligatoire.'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _descriptionController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Description',
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String?>(
                initialValue: _courseId,
                decoration: const InputDecoration(
                  labelText: 'Cours associé',
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Aucun cours'),
                  ),
                  for (final course in widget.controller.courses)
                    DropdownMenuItem<String?>(
                      value: course.id,
                      child: Text(course.title),
                    ),
                ],
                onChanged: (value) => setState(() => _courseId = value),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: const Icon(Icons.check_rounded),
                label:
                    Text(widget.deck == null ? 'Créer le jeu' : 'Enregistrer'),
              ),
            ],
          ),
        ),
      );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final description = _descriptionController.text.trim();
      final deck = widget.deck;
      if (deck == null) {
        await widget.controller.addFlashcardDeck(
          title: _titleController.text.trim(),
          description: description.isEmpty ? null : description,
          courseId: _courseId,
        );
      } else {
        await widget.controller.updateFlashcardDeck(
          deck: deck,
          title: _titleController.text.trim(),
          description: description.isEmpty ? null : description,
          courseId: _courseId,
        );
      }
      if (mounted) Navigator.pop(context);
    } on StudyMateApiException catch (error) {
      if (mounted) _showStudyError(context, error.message);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

class FlashcardDeckPage extends StatefulWidget {
  const FlashcardDeckPage({
    super.key,
    required this.controller,
    required this.deck,
  });

  final StudyController controller;
  final StudyFlashcardDeck deck;

  @override
  State<FlashcardDeckPage> createState() => _FlashcardDeckPageState();
}

class _FlashcardDeckPageState extends State<FlashcardDeckPage> {
  List<StudyFlashcard> _cards = const [];
  StudyFlashcardDeckProgress? _progress;
  String? _error;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.deck.title)),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _generateMore,
          icon: const Icon(Icons.auto_awesome_rounded),
          label: const Text('Générer avec l’IA'),
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
            children: [
              if (_progress case final progress?)
                _DeckProgressCard(progress: progress),
              if (_progress case final progress?
                  when progress.totalCards > 0) ...[
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: () => _reviewCards(),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Commencer la révision'),
                ),
              ],
              if (_error case final error?)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    error,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_cards.isEmpty)
                const _StudyEmptyCard(
                  icon: Icons.style_outlined,
                  title: 'Ce jeu est vide',
                  message: 'Touche « Générer avec l’IA » pour créer des '
                      'cartes à partir d’une note ou d’un texte.',
                )
              else
                for (final card in _cards) ...[
                  _FlashcardTile(
                    card: card,
                    onEdit: () => _openCardForm(card: card),
                    onDelete: () => _deleteCard(card),
                  ),
                  const SizedBox(height: 8),
                ],
            ],
          ),
        ),
      );

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        widget.controller.getFlashcards(widget.deck.id),
        widget.controller.getFlashcardDeckProgress(widget.deck.id),
      ]);
      if (!mounted) return;
      setState(() {
        _cards = results[0] as List<StudyFlashcard>;
        _progress = results[1] as StudyFlashcardDeckProgress;
      });
    } on StudyMateApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _generateMore() async {
    final deck = await Navigator.of(context).push<StudyFlashcardDeck>(
      MaterialPageRoute(
        builder: (_) => FlashcardGeneratePage(
          controller: widget.controller,
          deck: widget.deck,
        ),
      ),
    );
    if (deck != null && mounted) await _load();
  }

  Future<void> _openCardForm({StudyFlashcard? card}) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => FlashcardFormPage(
          controller: widget.controller,
          deckId: widget.deck.id,
          flashcard: card,
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _deleteCard(StudyFlashcard card) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer cette carte ?'),
        content: const Text('La progression de cette carte sera supprimée.'),
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
    if (confirmed == true && mounted) {
      await _runStudyAction(
        context,
        () => widget.controller.deleteFlashcard(card),
      );
      if (mounted) await _load();
    }
  }

  Future<void> _reviewCards() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => FlashcardReviewPage(
          controller: widget.controller,
          deck: widget.deck,
          cards: _cards,
        ),
      ),
    );
    if (mounted) await _load();
  }
}

class _DeckProgressCard extends StatelessWidget {
  const _DeckProgressCard({required this.progress});

  final StudyFlashcardDeckProgress progress;

  @override
  Widget build(BuildContext context) {
    final rate = progress.accuracyRate;
    final completion = progress.totalCards == 0
        ? 0.0
        : progress.reviewedCards / progress.totalCards;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${progress.reviewedCards}/${progress.totalCards} cartes vues',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                Text(
                  rate == null ? '—' : '${rate.toStringAsFixed(0)} %',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(value: completion),
            const SizedBox(height: 8),
            Text(
              '${progress.correctAnswers} bonnes réponses · '
              '${progress.incorrectAnswers} à revoir · '
              '${progress.masteredCards} maîtrisées',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _FlashcardTile extends StatelessWidget {
  const _FlashcardTile({
    required this.card,
    required this.onEdit,
    required this.onDelete,
  });

  final StudyFlashcard card;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Card(
        child: ExpansionTile(
          leading: const Icon(Icons.style_outlined),
          title: Text(card.question),
          subtitle: Text(
            card.repetitions == 0
                ? 'À découvrir'
                : 'Réussites consécutives : ${card.repetitions}',
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(card.answer),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Modifier'),
                ),
                IconButton(
                  tooltip: 'Supprimer',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ],
        ),
      );
}

class FlashcardFormPage extends StatefulWidget {
  const FlashcardFormPage({
    super.key,
    required this.controller,
    required this.deckId,
    this.flashcard,
  });

  final StudyController controller;
  final String deckId;
  final StudyFlashcard? flashcard;

  @override
  State<FlashcardFormPage> createState() => _FlashcardFormPageState();
}

class _FlashcardFormPageState extends State<FlashcardFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _questionController;
  late final TextEditingController _answerController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _questionController =
        TextEditingController(text: widget.flashcard?.question);
    _answerController = TextEditingController(text: widget.flashcard?.answer);
  }

  @override
  void dispose() {
    _questionController.dispose();
    _answerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(
            widget.flashcard == null ? 'Nouvelle carte' : 'Modifier la carte',
          ),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextFormField(
                controller: _questionController,
                minLines: 2,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Question *',
                ),
                validator: _requiredValidator,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _answerController,
                minLines: 3,
                maxLines: 7,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Réponse *',
                ),
                validator: _requiredValidator,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: const Icon(Icons.check_rounded),
                label: Text(widget.flashcard == null
                    ? 'Créer la carte'
                    : 'Enregistrer'),
              ),
            ],
          ),
        ),
      );

  String? _requiredValidator(String? value) =>
      value == null || value.trim().isEmpty
          ? 'Ce champ est obligatoire.'
          : null;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final card = widget.flashcard;
      if (card == null) {
        await widget.controller.addFlashcard(
          deckId: widget.deckId,
          question: _questionController.text.trim(),
          answer: _answerController.text.trim(),
        );
      } else {
        await widget.controller.updateFlashcard(
          StudyFlashcard(
            id: card.id,
            deckId: card.deckId,
            courseId: card.courseId,
            question: _questionController.text.trim(),
            answer: _answerController.text.trim(),
            repetitions: card.repetitions,
            intervalDays: card.intervalDays,
            easeFactor: card.easeFactor,
            dueAt: card.dueAt,
          ),
        );
      }
      if (mounted) Navigator.pop(context);
    } on StudyMateApiException catch (error) {
      if (mounted) _showStudyError(context, error.message);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

class FlashcardReviewPage extends StatefulWidget {
  const FlashcardReviewPage({
    super.key,
    required this.controller,
    required this.deck,
    required this.cards,
  });

  final StudyController controller;
  final StudyFlashcardDeck deck;
  final List<StudyFlashcard> cards;

  @override
  State<FlashcardReviewPage> createState() => _FlashcardReviewPageState();
}

class _FlashcardReviewPageState extends State<FlashcardReviewPage> {
  late final List<StudyFlashcard> _cards;
  int _index = 0;
  bool _showAnswer = false;
  bool _isSaving = false;
  int _correct = 0;
  int _incorrect = 0;

  @override
  void initState() {
    super.initState();
    _cards = List.of(widget.cards);
  }

  @override
  Widget build(BuildContext context) {
    final finished = _index >= _cards.length;
    return Scaffold(
      appBar: AppBar(title: Text('Révision · ${widget.deck.title}')),
      body: finished
          ? _reviewSummary()
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  LinearProgressIndicator(value: (_index + 1) / _cards.length),
                  const SizedBox(height: 10),
                  Text('Carte ${_index + 1} sur ${_cards.length}'),
                  const SizedBox(height: 20),
                  Expanded(
                    child: Card(
                      child: Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _showAnswer
                                ? _cards[_index].answer
                                : _cards[_index].question,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!_showAnswer)
                    FilledButton.icon(
                      onPressed: () => setState(() => _showAnswer = true),
                      icon: const Icon(Icons.visibility_outlined),
                      label: const Text('Afficher la réponse'),
                    )
                  else ...[
                    const Text('Comment évalues-tu ta réponse ?'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isSaving ? null : () => _submit(false),
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('À revoir'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _isSaving ? null : () => _submit(true),
                            icon: const Icon(Icons.check_rounded),
                            label: const Text('Je savais'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _reviewSummary() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.celebration_outlined,
                size: 52,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                'Révision terminée',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text('$_correct bonnes réponses · $_incorrect à revoir'),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Terminé'),
              ),
            ],
          ),
        ),
      );

  Future<void> _submit(bool isCorrect) async {
    setState(() => _isSaving = true);
    try {
      await widget.controller.reviewFlashcard(
        flashcard: _cards[_index],
        isCorrect: isCorrect,
      );
      if (!mounted) return;
      setState(() {
        if (isCorrect) {
          _correct++;
        } else {
          _incorrect++;
        }
        _index++;
        _showAnswer = false;
      });
    } on StudyMateApiException catch (error) {
      if (mounted) _showStudyError(context, error.message);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

/// Liste et saisie des examens / devoirs (ouverte depuis le tableau de bord).
class EvaluationsPage extends StatelessWidget {
  const EvaluationsPage({
    super.key,
    required this.controller,
    required this.onRefresh,
  });

  final StudyController controller;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Mes évaluations')),
        body: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => _EvaluationsSection(
            controller: controller,
            onRefresh: onRefresh,
          ),
        ),
      );
}

class _EvaluationsSection extends StatelessWidget {
  const _EvaluationsSection({
    required this.controller,
    required this.onRefresh,
  });

  final StudyController controller;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final summary = controller.evaluationSummary;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Mes évaluations',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: () => _openEvaluationForm(context, controller),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Ajouter'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (summary != null) ...[
            _EvaluationSummaryCard(summary: summary, controller: controller),
            const SizedBox(height: 10),
          ],
          if (controller.evaluations.isEmpty)
            const _StudyEmptyCard(
              icon: Icons.insights_outlined,
              title: 'Aucune évaluation',
              message: 'Ajoute tes notes pour suivre tes résultats.',
            )
          else
            for (final evaluation in controller.evaluations) ...[
              _EvaluationTile(
                evaluation: evaluation,
                courseName: _courseName(controller, evaluation.courseId),
                onEdit: () =>
                    _openEvaluationForm(context, controller, evaluation),
                onDelete: () =>
                    _deleteEvaluation(context, controller, evaluation),
              ),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}

class _EvaluationSummaryCard extends StatelessWidget {
  const _EvaluationSummaryCard({
    required this.summary,
    required this.controller,
  });

  final StudyEvaluationSummary summary;
  final StudyController controller;

  @override
  Widget build(BuildContext context) {
    final average = summary.averagePercentage;
    final points = summary.trend;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    average == null
                        ? 'Aucune note saisie'
                        : 'Moyenne : ${average.toStringAsFixed(1)} %',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                Text('${summary.gradedCount} notée(s)'),
              ],
            ),
            if (points.length > 1) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 72,
                width: double.infinity,
                child: CustomPaint(
                  painter: _EvaluationTrendPainter(
                    values: points.map((point) => point.percentage).toList(),
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              Text(
                'Évolution des résultats',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (summary.courseAverages.isNotEmpty) ...[
              const Divider(height: 24),
              for (final item in summary.courseAverages)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${_courseName(controller, item.courseId) ?? 'Sans cours'}'
                    ' · ${item.averagePercentage.toStringAsFixed(1)} %'
                    ' (${item.evaluationCount})',
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EvaluationTrendPainter extends CustomPainter {
  const _EvaluationTrendPainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final line = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final fill = Paint()
      ..color = color.withValues(alpha: 0.10)
      ..style = PaintingStyle.fill;
    final path = Path();
    for (var index = 0; index < values.length; index++) {
      final x = size.width * index / (values.length - 1);
      final y = size.height * (1 - values[index].clamp(0, 100) / 100);
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final area = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(area, fill);
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(covariant _EvaluationTrendPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.color != color;
}

class _EvaluationTile extends StatelessWidget {
  const _EvaluationTile({
    required this.evaluation,
    required this.courseName,
    required this.onEdit,
    required this.onDelete,
  });

  final StudyEvaluation evaluation;
  final String? courseName;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final percentage = evaluation.percentage;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.assignment_outlined),
        title: Text(evaluation.title),
        subtitle: Text(
          [
            if (courseName != null) courseName!,
            _evaluationTypeLabel(evaluation.evaluationType),
            if (evaluation.scheduledAt != null)
              _formatStudyDate(evaluation.scheduledAt!),
          ].join(' · '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (percentage != null)
              Text(
                '${evaluation.score!.toStringAsFixed(1)}/'
                '${evaluation.maxScore!.toStringAsFixed(1)}',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            PopupMenuButton<_EvaluationAction>(
              onSelected: (action) =>
                  action == _EvaluationAction.edit ? onEdit() : onDelete(),
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: _EvaluationAction.edit,
                  child: Text('Modifier'),
                ),
                PopupMenuItem(
                  value: _EvaluationAction.delete,
                  child: Text('Supprimer'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _EvaluationAction { edit, delete }

Future<void> _openEvaluationForm(
  BuildContext context,
  StudyController controller, [
  StudyEvaluation? evaluation,
]) async {
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => EvaluationFormPage(
        controller: controller,
        evaluation: evaluation,
      ),
    ),
  );
}

Future<void> _deleteEvaluation(
  BuildContext context,
  StudyController controller,
  StudyEvaluation evaluation,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Supprimer cette évaluation ?'),
      content: Text('« ${evaluation.title} » sera supprimée.'),
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
  if (confirmed == true && context.mounted) {
    await _runStudyAction(
      context,
      () => controller.deleteEvaluation(evaluation),
    );
  }
}

class EvaluationFormPage extends StatefulWidget {
  const EvaluationFormPage({
    super.key,
    required this.controller,
    this.evaluation,
  });

  final StudyController controller;
  final StudyEvaluation? evaluation;

  @override
  State<EvaluationFormPage> createState() => _EvaluationFormPageState();
}

class _EvaluationFormPageState extends State<EvaluationFormPage> {
  static const _types = {
    'exam': 'Examen',
    'quiz': 'Quiz',
    'assignment': 'Devoir',
    'presentation': 'Présentation',
    'other': 'Autre',
  };

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _scoreController;
  late final TextEditingController _maxScoreController;
  late final TextEditingController _notesController;
  late String _type;
  String? _courseId;
  DateTime? _scheduledAt;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final evaluation = widget.evaluation;
    _titleController = TextEditingController(text: evaluation?.title);
    _scoreController =
        TextEditingController(text: evaluation?.score?.toString() ?? '');
    _maxScoreController =
        TextEditingController(text: evaluation?.maxScore?.toString() ?? '');
    _notesController = TextEditingController(text: evaluation?.notes);
    _type = evaluation?.evaluationType ?? 'exam';
    _courseId = evaluation?.courseId;
    _scheduledAt = evaluation?.scheduledAt;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _scoreController.dispose();
    _maxScoreController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(
            widget.evaluation == null
                ? 'Nouvelle évaluation'
                : 'Modifier l’évaluation',
          ),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextFormField(
                controller: _titleController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nom *',
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Le nom est obligatoire.'
                    : null,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(
                  labelText: 'Type',
                ),
                items: [
                  for (final entry in _types.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _type = value);
                },
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String?>(
                initialValue: _courseId,
                decoration: const InputDecoration(
                  labelText: 'Cours associé',
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Aucun cours'),
                  ),
                  for (final course in widget.controller.courses)
                    DropdownMenuItem<String?>(
                      value: course.id,
                      child: Text(course.title),
                    ),
                ],
                onChanged: (value) => setState(() => _courseId = value),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.event_outlined),
                label: Text(
                  _scheduledAt == null
                      ? 'Date de l’évaluation'
                      : _formatStudyDate(_scheduledAt!),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _scoreController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Note obtenue',
                      ),
                      validator: (value) => _validateNumber(value, 'La note'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _maxScoreController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Note maximale',
                      ),
                      validator: (value) =>
                          _validateNumber(value, 'La note maximale'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _notesController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Commentaire',
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: const Icon(Icons.check_rounded),
                label: Text(
                  widget.evaluation == null ? 'Ajouter' : 'Enregistrer',
                ),
              ),
            ],
          ),
        ),
      );

  String? _validateNumber(String? value, String label) {
    if (value == null || value.trim().isEmpty) return null;
    final parsed = double.tryParse(value.replaceAll(',', '.'));
    if (parsed == null || !parsed.isFinite || parsed < 0) {
      return '$label doit être un nombre positif.';
    }
    if (label == 'La note maximale' && parsed == 0) {
      return 'La note maximale doit être supérieure à zéro.';
    }
    return null;
  }

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _scheduledAt ?? today,
      firstDate: DateTime(today.year - 10),
      lastDate: DateTime(today.year + 10),
    );
    if (selected != null) setState(() => _scheduledAt = selected);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final score = _parseOptionalNumber(_scoreController.text);
    final maxScore = _parseOptionalNumber(_maxScoreController.text);
    if ((score == null) != (maxScore == null)) {
      _showStudyError(
        context,
        'Renseigne à la fois la note obtenue et la note maximale.',
      );
      return;
    }
    if (score != null && maxScore != null && score > maxScore) {
      _showStudyError(
          context, 'La note ne peut pas dépasser la note maximale.');
      return;
    }
    setState(() => _isSaving = true);
    try {
      final title = _titleController.text.trim();
      final notes = _notesController.text.trim();
      final evaluation = widget.evaluation;
      if (evaluation == null) {
        await widget.controller.addEvaluation(
          title: title,
          evaluationType: _type,
          courseId: _courseId,
          scheduledAt: _scheduledAt,
          score: score,
          maxScore: maxScore,
          notes: notes.isEmpty ? null : notes,
        );
      } else {
        await widget.controller.updateEvaluation(
          StudyEvaluation(
            id: evaluation.id,
            title: title,
            evaluationType: _type,
            courseId: _courseId,
            scheduledAt: _scheduledAt,
            score: score,
            maxScore: maxScore,
            notes: notes.isEmpty ? null : notes,
            createdAt: evaluation.createdAt,
            updatedAt: DateTime.now(),
          ),
        );
      }
      if (mounted) Navigator.pop(context);
    } on StudyMateApiException catch (error) {
      if (mounted) _showStudyError(context, error.message);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  double? _parseOptionalNumber(String value) =>
      value.trim().isEmpty ? null : double.parse(value.replaceAll(',', '.'));
}

class _StudyEmptyCard extends StatelessWidget {
  const _StudyEmptyCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(
                icon,
                size: 38,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 8),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
}

String? _courseName(StudyController controller, String? courseId) {
  if (courseId == null) return null;
  for (final course in controller.courses) {
    if (course.id == courseId) return course.title;
  }
  return null;
}

String _evaluationTypeLabel(String type) => switch (type) {
      'exam' => 'Examen',
      'quiz' => 'Quiz',
      'assignment' => 'Devoir',
      'presentation' => 'Présentation',
      _ => 'Autre',
    };

String _formatStudyDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/${date.year}';

Future<void> _runStudyAction(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } on StudyMateApiException catch (error) {
    if (context.mounted) _showStudyError(context, error.message);
  }
}

void _showStudyError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}
