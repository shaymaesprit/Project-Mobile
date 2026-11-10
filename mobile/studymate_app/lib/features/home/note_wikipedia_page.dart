import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/planning_models.dart';
import '../../data/models/study_models.dart';
import '../../data/services/studymate_api.dart';
import '../../state/study_controller.dart';

/// Complète une note avec le résumé d'un article Wikipédia (API REST
/// Wikimedia). Seul le terme recherché est envoyé ; la source est citée.
class NoteWikipediaPage extends StatefulWidget {
  const NoteWikipediaPage(
      {super.key, required this.controller, required this.note});

  final StudyController controller;
  final StudyNote note;

  @override
  State<NoteWikipediaPage> createState() => _NoteWikipediaPageState();
}

class _NoteWikipediaPageState extends State<NoteWikipediaPage> {
  late final TextEditingController _query =
      TextEditingController(text: widget.note.title);
  List<WikipediaResult>? _results;
  String? _error;
  bool _searching = false;
  String? _addingUrl;

  @override
  void initState() {
    super.initState();
    if (_query.text.trim().length >= 2) _search();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _query.text.trim();
    if (query.length < 2) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final results = await widget.controller.api.searchWikipedia(query);
      if (mounted) setState(() => _results = results);
    } on StudyMateApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _append(WikipediaResult result) async {
    setState(() => _addingUrl = result.url);
    final note = widget.note;
    final addition =
        '📚 Wikipédia — ${result.title}\n${result.extract}\nSource : ${result.url}';
    final content = note.content.trim().isEmpty
        ? addition
        : '${note.content.trimRight()}\n\n$addition';
    try {
      await widget.controller.updateNote(
        StudyNote(
          id: note.id,
          title: note.title,
          content: content,
          courseId: note.courseId,
          updatedAt: DateTime.now(),
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('« ${result.title} » ajouté à ta note.')),
      );
      Navigator.of(context).pop(true);
    } on StudyMateApiException catch (error) {
      if (!mounted) return;
      setState(() => _addingUrl = null);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final results = _results;
    return Scaffold(
      appBar: AppBar(title: const Text('Compléter avec Wikipédia')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          Text(
            'Note : ${widget.note.title}',
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _query,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              labelText: 'Notion à rechercher',
              prefixIcon: const Icon(Icons.travel_explore_rounded),
              suffixIcon: IconButton(
                tooltip: 'Rechercher',
                onPressed: _searching ? null : _search,
                icon: const Icon(Icons.arrow_forward_rounded),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_searching)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Text(_error!, style: TextStyle(color: colors.error))
          else if (results != null && results.isEmpty)
            Text(
              'Aucun article trouvé. Essaie un autre mot-clé.',
              style: TextStyle(color: colors.onSurfaceVariant),
            )
          else if (results != null)
            for (final result in results) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (result.thumbnail != null) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                result.thumbnail!,
                                width: 56,
                                height: 56,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const SizedBox.square(dimension: 56),
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(result.title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium),
                                if (result.description?.isNotEmpty == true)
                                  Text(
                                    result.description!,
                                    style: TextStyle(
                                        color: colors.onSurfaceVariant,
                                        fontSize: 12.5),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(result.extract, style: const TextStyle(height: 1.4)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(Icons.public_rounded,
                              size: 14, color: AppPalette.sky),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Wikipédia · licence CC BY-SA',
                              style: TextStyle(
                                  color: colors.onSurfaceVariant, fontSize: 12),
                            ),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: _addingUrl == null
                                ? () => _append(result)
                                : null,
                            icon: _addingUrl == result.url
                                ? const SizedBox.square(
                                    dimension: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.playlist_add_rounded),
                            label: const Text('Ajouter'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}
