import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';

import '../../data/models/document_models.dart';
import '../../data/models/study_models.dart';
import '../../data/services/studymate_api.dart';
import '../../state/study_controller.dart';
import '../insights/ai_consent.dart';

const _maxUploadBytes = 20 * 1024 * 1024;
const _months = [
  'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
  'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
];

/// Copie locale des PDF déjà ouverts : relecture sans réseau.
class PdfCache {
  PdfCache._();

  static Future<File> fileFor(String documentId) async {
    final dir = Directory(p.join((await getApplicationSupportDirectory()).path, 'course_pdfs'));
    await dir.create(recursive: true);
    return File(p.join(dir.path, '$documentId.pdf'));
  }

  static Future<void> evict(String documentId) async {
    try {
      final file = await fileFor(documentId);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}

/// Section « Documents PDF » du détail d'un cours.
class CourseDocumentsSection extends StatefulWidget {
  const CourseDocumentsSection({super.key, required this.controller, required this.course});

  final StudyController controller;
  final StudyCourse course;

  @override
  State<CourseDocumentsSection> createState() => _CourseDocumentsSectionState();
}

class _CourseDocumentsSectionState extends State<CourseDocumentsSection> {
  List<CourseDocument>? _documents;
  String? _error;
  double? _uploadProgress;
  String? _uploadingName;
  final _busy = <String>{};

  StudyMateApi get _api => widget.controller.api;
  bool get _isLocalCourse => widget.course.id.startsWith('local-');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_isLocalCourse) {
      setState(() => _documents = const []);
      return;
    }
    setState(() => _error = null);
    try {
      final docs = await _api.listCourseDocuments(widget.course.id);
      if (mounted) setState(() => _documents = docs);
    } on StudyMateApiException catch (error) {
      if (mounted) {
        setState(() => _error = error.isNetworkError
            ? 'Hors ligne : les PDF s’afficheront au retour du réseau.'
            : error.message);
      }
    }
  }

  void _snack(String message, {SnackBarAction? action}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), action: action));
  }

  Future<void> _pickAndUpload() async {
    if (_isLocalCourse) {
      _snack('Ce cours n’est pas encore synchronisé : réessaie une fois en ligne.');
      return;
    }
    final file = await FilePicker.pickFile(
      dialogTitle: 'Choisir un PDF de cours',
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    if (file == null || !mounted) return;
    final bytes = await file.xFile.readAsBytes();
    if (bytes.length > _maxUploadBytes) {
      _snack('Ce PDF dépasse 20 Mo.');
      return;
    }
    setState(() {
      _uploadProgress = 0;
      _uploadingName = file.name;
    });
    try {
      final doc = await _api.uploadCourseDocument(
        courseId: widget.course.id,
        bytes: bytes,
        filename: file.name,
        onProgress: (value) {
          if (mounted) setState(() => _uploadProgress = value);
        },
      );
      // Le fichier envoyé est déjà sur le téléphone : on le garde en cache.
      try {
        await (await PdfCache.fileFor(doc.id)).writeAsBytes(bytes, flush: true);
      } catch (_) {}
      if (!mounted) return;
      setState(() => _documents = [doc, ...?_documents]);
      _snack(
        doc.hasText
            ? '« ${doc.title} » ajouté (${doc.pageCount ?? '?'} pages).'
            : '« ${doc.title} » ajouté. PDF scanné : l’IA ne pourra pas en lire le texte.',
      );
    } on StudyMateApiException catch (error) {
      _snack(error.isNetworkError ? 'Pas de connexion : le PDF n’a pas été envoyé.' : error.message);
    } finally {
      if (mounted) {
        setState(() {
          _uploadProgress = null;
          _uploadingName = null;
        });
      }
    }
  }

  void _open(CourseDocument doc) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PdfReaderPage(
          controller: widget.controller,
          document: doc,
          course: widget.course,
        ),
      ),
    );
  }

  Future<void> _rename(CourseDocument doc) async {
    final title = await showDialog<String>(
      context: context,
      builder: (context) => _RenameDialog(initial: doc.title),
    );
    if (title == null || title == doc.title) return;
    try {
      final updated = await _api.renameDocument(doc.id, title);
      if (!mounted) return;
      setState(() {
        _documents = [for (final d in _documents ?? const <CourseDocument>[]) d.id == doc.id ? updated : d];
      });
    } on StudyMateApiException catch (error) {
      _snack(error.message);
    }
  }

  Future<void> _delete(CourseDocument doc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_outline_rounded),
        title: const Text('Supprimer ce PDF ?'),
        content: Text('« ${doc.title} » sera supprimé du cours. Les flashcards déjà créées sont conservées.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _busy.add(doc.id));
    try {
      await _api.deleteDocument(doc.id);
      await PdfCache.evict(doc.id);
      if (!mounted) return;
      setState(() => _documents = [...?_documents]..removeWhere((d) => d.id == doc.id));
      _snack('PDF supprimé.');
    } on StudyMateApiException catch (error) {
      _snack(error.message);
    } finally {
      if (mounted) setState(() => _busy.remove(doc.id));
    }
  }

  Future<void> _flashcards(CourseDocument doc) async {
    setState(() => _busy.add(doc.id));
    try {
      final message = await generateFlashcardsFromPdf(
        context,
        controller: widget.controller,
        document: doc,
        course: widget.course,
      );
      if (message != null) _snack(message);
    } finally {
      if (mounted) setState(() => _busy.remove(doc.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final docs = _documents;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.picture_as_pdf_rounded, color: colors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Documents PDF${docs == null || docs.isEmpty ? '' : ' (${docs.length})'}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                TextButton.icon(
                  onPressed: _uploadProgress != null ? null : _pickAndUpload,
                  icon: const Icon(Icons.upload_file_rounded),
                  label: const Text('Ajouter'),
                ),
              ],
            ),
            if (_uploadProgress case final progress?) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Envoi de ${_uploadingName ?? 'PDF'}…',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: progress >= 1 ? null : progress,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      progress >= 1 ? 'Analyse…' : '${(progress * 100).round()} %',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 4),
            if (_error != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.cloud_off_rounded),
                title: Text(_error!, style: Theme.of(context).textTheme.bodySmall),
                trailing: IconButton(
                  tooltip: 'Réessayer',
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              )
            else if (docs == null)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (docs.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 4, 8, 8),
                child: Text(
                  'Ajoute les supports de ce cours (PDF, 20 Mo max.) : tu pourras les lire ici, '
                  'même hors ligne une fois ouverts, et en tirer des flashcards avec l’IA.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                ),
              )
            else
              for (final doc in docs)
                _DocumentTile(
                  document: doc,
                  busy: _busy.contains(doc.id),
                  onOpen: () => _open(doc),
                  onFlashcards: () => _flashcards(doc),
                  onRename: () => _rename(doc),
                  onDelete: () => _delete(doc),
                ),
          ],
        ),
      ),
    );
  }
}

enum _DocAction { flashcards, rename, delete }

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({
    required this.document,
    required this.busy,
    required this.onOpen,
    required this.onFlashcards,
    required this.onRename,
    required this.onDelete,
  });

  final CourseDocument document;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback onFlashcards;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final date = document.createdAt;
    final meta = [
      if (document.pageCount != null) '${document.pageCount} page${document.pageCount == 1 ? '' : 's'}',
      if (document.sizeLabel.isNotEmpty) document.sizeLabel,
      '${date.day} ${_months[date.month - 1]}',
    ].join(' · ');
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 0, right: 0),
      onTap: busy ? null : onOpen,
      leading: Container(
        width: 42,
        height: 48,
        decoration: BoxDecoration(
          color: colors.errorContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          'PDF',
          style: TextStyle(color: colors.onErrorContainer, fontWeight: FontWeight.w900, fontSize: 12),
        ),
      ),
      title: Text(document.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(document.hasText ? meta : '$meta · scanné (sans texte)'),
      trailing: busy
          ? const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          : PopupMenuButton<_DocAction>(
              tooltip: 'Actions',
              onSelected: (action) => switch (action) {
                _DocAction.flashcards => onFlashcards(),
                _DocAction.rename => onRename(),
                _DocAction.delete => onDelete(),
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: _DocAction.flashcards,
                  enabled: document.hasText,
                  child: const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.auto_awesome_rounded),
                    title: Text('Créer des flashcards (IA)'),
                  ),
                ),
                const PopupMenuItem(
                  value: _DocAction.rename,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.drive_file_rename_outline_rounded),
                    title: Text('Renommer'),
                  ),
                ),
                const PopupMenuItem(
                  value: _DocAction.delete,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.delete_outline_rounded),
                    title: Text('Supprimer'),
                  ),
                ),
              ],
            ),
    );
  }
}

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initial});

  final String initial;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isNotEmpty) Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Renommer le PDF'),
        content: TextField(
          controller: _controller,
          autofocus: true,
          maxLength: 240,
          decoration: const InputDecoration(labelText: 'Titre'),
          onSubmitted: (_) => _submit(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          FilledButton(onPressed: _submit, child: const Text('Renommer')),
        ],
      );
}

/// Crée un jeu « titre du PDF » dans le cours et y fait générer des cartes.
/// Renvoie le message à afficher (ou `null` si l'étudiant a annulé).
Future<String?> generateFlashcardsFromPdf(
  BuildContext context, {
  required StudyController controller,
  required CourseDocument document,
  required StudyCourse course,
}) async {
  if (!document.hasText) {
    return 'Ce PDF est scanné : il ne contient pas de texte que l’IA peut lire.';
  }
  try {
    final allowed = await ensureAiConsent(
      context,
      controller.api,
      purpose: 'Pour créer tes flashcards, StudyMate envoie le texte de ce PDF à '
          'l’assistant IA. Le fichier lui-même reste sur ton serveur StudyMate.',
    );
    if (!allowed) return null;
    final deck = await controller.addFlashcardDeck(
      title: document.title.length > 200 ? document.title.substring(0, 200) : document.title,
      description: 'Flashcards générées depuis le PDF « ${document.title} ».',
      courseId: course.id,
    );
    final result = await controller.generateFlashcards(
      deck: deck,
      documentId: document.id,
      maxCards: 12,
    );
    final count = result.cards.length;
    return '$count flashcard${count > 1 ? 's' : ''} créée${count > 1 ? 's' : ''} '
        'dans « ${deck.title} » (onglet Réviser).';
  } on StudyMateApiException catch (error) {
    return error.isNetworkError ? 'Pas de connexion : réessaie plus tard.' : error.message;
  }
}

/// Lecture d'un PDF de cours dans l'app (téléchargé une fois, puis en cache).
class PdfReaderPage extends StatefulWidget {
  const PdfReaderPage({
    super.key,
    required this.controller,
    required this.document,
    required this.course,
  });

  final StudyController controller;
  final CourseDocument document;
  final StudyCourse course;

  @override
  State<PdfReaderPage> createState() => _PdfReaderPageState();
}

class _PdfReaderPageState extends State<PdfReaderPage> {
  PdfControllerPinch? _viewer;
  String? _path;
  String? _error;
  double? _progress;
  int _page = 1;
  int _pages = 0;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _pages = widget.document.pageCount ?? 0;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _progress = 0;
    });
    try {
      final file = await PdfCache.fileFor(widget.document.id);
      if (!await file.exists() || await file.length() == 0) {
        final bytes = await widget.controller.api.downloadDocument(
          widget.document.id,
          onProgress: (value) {
            if (mounted) setState(() => _progress = value);
          },
        );
        await file.writeAsBytes(bytes, flush: true);
      }
      if (!mounted) return;
      _viewer?.dispose();
      setState(() {
        _path = file.path;
        _viewer = PdfControllerPinch(document: PdfDocument.openFile(file.path));
      });
    } on StudyMateApiException catch (error) {
      if (mounted) {
        setState(() => _error = error.isNetworkError
            ? 'Hors ligne : ce PDF n’a pas encore été ouvert sur ce téléphone.'
            : error.message);
      }
    } on FileSystemException {
      if (mounted) setState(() => _error = 'Impossible d’enregistrer le PDF sur le téléphone.');
    } finally {
      if (mounted) setState(() => _progress = null);
    }
  }

  @override
  void dispose() {
    _viewer?.dispose();
    super.dispose();
  }

  Future<void> _flashcards() async {
    setState(() => _generating = true);
    final message = await generateFlashcardsFromPdf(
      context,
      controller: widget.controller,
      document: widget.document,
      course: widget.course,
    );
    if (!mounted) return;
    setState(() => _generating = false);
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final path = _path;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.document.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(
              widget.course.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
        actions: [
          if (widget.document.hasText)
            IconButton(
              tooltip: 'Créer des flashcards (IA)',
              onPressed: _generating ? null : _flashcards,
              icon: _generating
                  ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.auto_awesome_rounded),
            ),
        ],
      ),
      body: switch ((path, _error)) {
        (_, final String error) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_rounded, size: 44),
                  const SizedBox(height: 12),
                  Text(error, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Réessayer'),
                  ),
                ],
              ),
            ),
          ),
        (final String _, _) when _viewer != null => Stack(
            children: [
              PdfViewPinch(
                controller: _viewer!,
                backgroundDecoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                onDocumentLoaded: (document) {
                  if (mounted) setState(() => _pages = document.pagesCount);
                },
                onPageChanged: (page) {
                  if (mounted) setState(() => _page = page);
                },
                onDocumentError: (_) {
                  // Fichier en cache abîmé : on le supprime pour le retélécharger.
                  PdfCache.evict(widget.document.id);
                  if (mounted) {
                    setState(() {
                      _path = null;
                      _error = 'Ce PDF n’a pas pu être affiché. Réessaie pour le retélécharger.';
                    });
                  }
                },
              ),
              if (_pages > 0)
                Positioned(
                  bottom: 16,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        child: Text(
                          'Page $_page / $_pages',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        _ => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 180,
                  child: LinearProgressIndicator(
                    value: (_progress ?? 0) > 0 ? _progress : null,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  (_progress ?? 0) > 0
                      ? 'Téléchargement… ${((_progress ?? 0) * 100).round()} %'
                      : 'Ouverture du PDF…',
                ),
              ],
            ),
          ),
      },
    );
  }
}
