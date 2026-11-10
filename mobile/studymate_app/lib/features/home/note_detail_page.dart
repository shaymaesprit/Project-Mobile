import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/study_models.dart';
import '../../data/services/studymate_api.dart';
import '../../state/study_controller.dart';
import 'note_wikipedia_page.dart';

const _months = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
  'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
];

enum _NoteAction { copy, wikipedia, delete }

/// Lecture d'une note en entier, avec modification sur place.
class NoteDetailPage extends StatefulWidget {
  const NoteDetailPage({super.key, required this.controller, required this.note});

  final StudyController controller;
  final StudyNote note;

  @override
  State<NoteDetailPage> createState() => _NoteDetailPageState();
}

class _NoteDetailPageState extends State<NoteDetailPage> {
  late StudyNote _note = widget.note;
  bool _editing = false;
  bool _saving = false;
  final _title = TextEditingController();
  final _content = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_sync);
  }

  /// Suit la note dans le contrôleur (synchronisation, id serveur…).
  void _sync() {
    final notes = widget.controller.notes;
    final match = notes.where((n) => n.id == _note.id).firstOrNull ??
        // Une note créée hors ligne change d'id une fois synchronisée.
        notes.where((n) => n.title == _note.title && n.content == _note.content).firstOrNull;
    if (match != null && mounted && !_editing) setState(() => _note = match);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_sync);
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  void _startEditing() {
    _title.text = _note.title;
    _content.text = _note.content;
    setState(() => _editing = true);
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      _snack('Le titre est obligatoire.');
      return;
    }
    final updated = StudyNote(
      id: _note.id,
      title: title,
      content: _content.text.trim(),
      courseId: _note.courseId,
      updatedAt: DateTime.now(),
    );
    setState(() => _saving = true);
    try {
      await widget.controller.updateNote(updated);
      if (!mounted) return;
      setState(() {
        _note = updated;
        _editing = false;
      });
      _snack('Note enregistrée.');
    } on StudyMateApiException catch (error) {
      _snack(error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer cette note ?'),
        content: Text('« ${_note.title} » sera supprimée.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.controller.deleteNote(_note);
      if (mounted) Navigator.pop(context);
    } on StudyMateApiException catch (error) {
      _snack(error.message);
    }
  }

  void _onAction(_NoteAction action) {
    switch (action) {
      case _NoteAction.copy:
        Clipboard.setData(ClipboardData(text: '${_note.title}\n\n${_note.content}'));
        _snack('Note copiée.');
      case _NoteAction.wikipedia:
        Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => NoteWikipediaPage(controller: widget.controller, note: _note),
          ),
        );
      case _NoteAction.delete:
        _delete();
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _confirmDiscard() async {
    if (!_editing ||
        (_title.text.trim() == _note.title && _content.text.trim() == _note.content)) {
      return true;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Abandonner les modifications ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Continuer')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Abandonner')),
        ],
      ),
    );
    return discard == true;
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_editing,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          if (await _confirmDiscard() && mounted) setState(() => _editing = false);
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(_editing ? 'Modifier la note' : 'Note'),
            actions: _editing
                ? [
                    TextButton(
                      onPressed: _saving
                          ? null
                          : () async {
                              if (await _confirmDiscard() && mounted) {
                                setState(() => _editing = false);
                              }
                            },
                      child: const Text('Annuler'),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilledButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Enregistrer'),
                      ),
                    ),
                  ]
                : [
                    IconButton(
                      tooltip: 'Modifier',
                      onPressed: _startEditing,
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    PopupMenuButton<_NoteAction>(
                      tooltip: 'Plus',
                      onSelected: _onAction,
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: _NoteAction.copy,
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.copy_rounded),
                            title: Text('Copier le texte'),
                          ),
                        ),
                        PopupMenuItem(
                          value: _NoteAction.wikipedia,
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.travel_explore_rounded),
                            title: Text('Compléter avec Wikipédia'),
                          ),
                        ),
                        PopupMenuItem(
                          value: _NoteAction.delete,
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.delete_outline_rounded),
                            title: Text('Supprimer'),
                          ),
                        ),
                      ],
                    ),
                  ],
          ),
          body: _editing ? _editor(context) : _reader(context),
        ),
      );

  Widget _reader(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = AppPalette.accentFor(_note.id);
    final course = widget.controller.courses.where((c) => c.id == _note.courseId).firstOrNull;
    final words = _note.content.trim().isEmpty
        ? 0
        : _note.content.trim().split(RegExp(r'\s+')).length;
    final minutes = (words / 200).ceil();
    final updated = _note.updatedAt;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.description_rounded, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SelectableText(
                _note.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (course != null)
              Chip(
                avatar: const Icon(Icons.menu_book_rounded, size: 16),
                label: Text(course.title),
                visualDensity: VisualDensity.compact,
              ),
            if (updated != null)
              Chip(
                avatar: const Icon(Icons.schedule_rounded, size: 16),
                label: Text('Modifiée le ${updated.day} ${_months[updated.month - 1]} ${updated.year}'),
                visualDensity: VisualDensity.compact,
              ),
            if (words > 0)
              Chip(
                avatar: const Icon(Icons.timer_outlined, size: 16),
                label: Text('$words mot${words > 1 ? 's' : ''} · $minutes min de lecture'),
                visualDensity: VisualDensity.compact,
              ),
            if (_note.id.startsWith('local-'))
              const Chip(
                avatar: Icon(Icons.cloud_upload_outlined, size: 16),
                label: Text('En attente de synchronisation'),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
        const SizedBox(height: 20),
        if (_note.content.trim().isEmpty)
          Card(
            child: ListTile(
              leading: const Icon(Icons.edit_note_rounded),
              title: const Text('Cette note est vide'),
              subtitle: const Text('Touchez pour écrire son contenu.'),
              onTap: _startEditing,
            ),
          )
        else
          SelectableText(
            _note.content,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6, color: colors.onSurface),
          ),
      ],
    );
  }

  Widget _editor(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Column(
          children: [
            TextField(
              controller: _title,
              maxLength: 200,
              textCapitalization: TextCapitalization.sentences,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              decoration: const InputDecoration(labelText: 'Titre'),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: TextField(
                controller: _content,
                autofocus: true,
                expands: true,
                maxLines: null,
                textAlignVertical: TextAlignVertical.top,
                textCapitalization: TextCapitalization.sentences,
                keyboardType: TextInputType.multiline,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
                decoration: const InputDecoration(
                  labelText: 'Contenu',
                  alignLabelWithHint: true,
                ),
              ),
            ),
          ],
        ),
      );
}
