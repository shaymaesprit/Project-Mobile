import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/study_models.dart';
import '../../data/services/studymate_api.dart';
import '../../state/study_controller.dart';
import '../insights/ai_consent.dart';

enum _Source { note, text }

/// Génère un jeu de flashcards avec l'IA à partir d'une note ou d'un texte.
///
/// Sans [deck], un nouveau jeu est créé puis rempli. Avec [deck], les cartes
/// sont ajoutées à ce jeu. Renvoie le jeu rempli, ou `null` si annulé.
class FlashcardGeneratePage extends StatefulWidget {
  const FlashcardGeneratePage({
    super.key,
    required this.controller,
    this.deck,
  });

  final StudyController controller;
  final StudyFlashcardDeck? deck;

  @override
  State<FlashcardGeneratePage> createState() => _FlashcardGeneratePageState();
}

class _FlashcardGeneratePageState extends State<FlashcardGeneratePage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _textController = TextEditingController();
  late _Source _source =
      widget.controller.notes.isEmpty ? _Source.text : _Source.note;
  String? _noteId;
  String? _courseId;
  double _cardCount = 8;
  bool _generating = false;
  String? _error;

  bool get _isNewDeck => widget.deck == null;

  @override
  void initState() {
    super.initState();
    final notes = widget.controller.notes;
    if (notes.isNotEmpty) {
      _noteId = notes.first.id;
      _titleController.text = notes.first.title;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final notes = widget.controller.notes;
    final courses = widget.controller.courses;

    return Scaffold(
      appBar: AppBar(
        title:
            Text(_isNewDeck ? 'Générer avec l’IA' : 'Générer plus de cartes'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _Banner(deckTitle: widget.deck?.title),
            const SizedBox(height: 22),
            Text('Source', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            SegmentedButton<_Source>(
              segments: const [
                ButtonSegment(
                  value: _Source.note,
                  icon: Icon(Icons.description_outlined),
                  label: Text('Une de mes notes'),
                ),
                ButtonSegment(
                  value: _Source.text,
                  icon: Icon(Icons.content_paste_rounded),
                  label: Text('Coller un texte'),
                ),
              ],
              selected: {_source},
              onSelectionChanged: _generating
                  ? null
                  : (value) => setState(() => _source = value.first),
            ),
            const SizedBox(height: 14),
            if (_source == _Source.note)
              notes.isEmpty
                  ? Text(
                      'Tu n’as pas encore de note. Colle plutôt un texte, ou '
                      'crée une note depuis l’onglet Notes.',
                      style: TextStyle(color: colors.onSurfaceVariant),
                    )
                  : DropdownButtonFormField<String>(
                      initialValue: _noteId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Note à transformer',
                        prefixIcon: Icon(Icons.description_outlined),
                      ),
                      items: [
                        for (final note in notes)
                          DropdownMenuItem(
                            value: note.id,
                            child: Text(
                              note.title,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      validator: (value) =>
                          value == null ? 'Choisis une note.' : null,
                      onChanged: _generating
                          ? null
                          : (value) => setState(() {
                                _noteId = value;
                                final note = notes
                                    .where((n) => n.id == value)
                                    .firstOrNull;
                                if (note != null) {
                                  _titleController.text = note.title;
                                }
                              }),
                    )
            else
              TextFormField(
                controller: _textController,
                enabled: !_generating,
                minLines: 6,
                maxLines: 12,
                maxLength: 20000,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Ton cours, un résumé, un extrait…',
                  alignLabelWithHint: true,
                ),
                validator: (value) => (value ?? '').trim().length < 40
                    ? 'Colle au moins quelques phrases (40 caractères).'
                    : null,
              ),
            if (_isNewDeck) ...[
              const SizedBox(height: 18),
              TextFormField(
                controller: _titleController,
                enabled: !_generating,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nom du jeu',
                  prefixIcon: Icon(Icons.style_outlined),
                ),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Donne un nom à ton jeu.'
                    : null,
              ),
              if (courses.isNotEmpty) ...[
                const SizedBox(height: 14),
                DropdownButtonFormField<String?>(
                  initialValue: _courseId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Cours (facultatif)',
                    prefixIcon: Icon(Icons.school_outlined),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Aucun')),
                    for (final course in courses)
                      DropdownMenuItem(
                        value: course.id,
                        child: Text(
                          course.title,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: _generating
                      ? null
                      : (value) => setState(() => _courseId = value),
                ),
              ],
            ],
            const SizedBox(height: 22),
            Row(
              children: [
                Text(
                  'Nombre de cartes',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                Text(
                  '${_cardCount.round()}',
                  style: TextStyle(
                    color: colors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            Slider(
              value: _cardCount,
              min: 3,
              max: 15,
              divisions: 12,
              label: '${_cardCount.round()}',
              onChanged: _generating
                  ? null
                  : (value) => setState(() => _cardCount = value),
            ),
            if (_error case final error?) ...[
              const SizedBox(height: 6),
              Text(error, style: TextStyle(color: colors.error)),
            ],
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed:
                  _generating || (_source == _Source.note && notes.isEmpty)
                      ? null
                      : _generate,
              icon: _generating
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.auto_awesome_rounded),
              label: Text(
                _generating ? 'L’IA prépare tes cartes…' : 'Générer les cartes',
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Seul le contenu choisi est envoyé à l’IA, jamais tes données '
              'personnelles. Tu pourras corriger chaque carte ensuite.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generate() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _generating = true;
      _error = null;
    });

    final controller = widget.controller;
    StudyFlashcardDeck? createdDeck;
    try {
      if (!await _ensureConsent()) {
        setState(() => _generating = false);
        return;
      }

      var deck = widget.deck;
      if (deck == null) {
        deck = await controller.addFlashcardDeck(
          title: _titleController.text.trim(),
          courseId: _courseId,
        );
        createdDeck = deck;
      }

      final result = await controller.generateFlashcards(
        deck: deck,
        noteId: _source == _Source.note ? _noteId : null,
        text: _source == _Source.text ? _textController.text.trim() : null,
        maxCards: _cardCount.round(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.usedAi
                ? '✨ ${result.cards.length} cartes générées par l’IA.'
                : 'IA momentanément indisponible : ${result.cards.length} '
                    'cartes créées automatiquement à partir du texte.',
          ),
        ),
      );
      Navigator.of(context).pop(deck);
    } on StudyMateApiException catch (error) {
      // Pas de jeu vide orphelin si la génération échoue.
      if (createdDeck != null) {
        try {
          await controller.deleteFlashcardDeck(createdDeck);
        } on StudyMateApiException catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _generating = false;
        _error = error.message;
      });
    }
  }

  Future<bool> _ensureConsent() => ensureAiConsent(
        context,
        widget.controller.api,
        purpose: 'Pour créer tes flashcards, StudyMate envoie le texte de ta '
            'note (et uniquement lui) à un modèle d’IA.',
      );
}

class _Banner extends StatelessWidget {
  const _Banner({this.deckTitle});

  final String? deckTitle;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: AppGradients.brand,
          borderRadius: BorderRadius.circular(AppTheme.radius),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                deckTitle == null
                    ? 'Choisis un contenu : l’IA en tire les questions '
                        'essentielles et leurs réponses.'
                    : 'De nouvelles cartes seront ajoutées à « $deckTitle ».',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      );
}
