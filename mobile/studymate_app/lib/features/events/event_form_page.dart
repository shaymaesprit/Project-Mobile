import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/models/event_models.dart';
import '../../data/services/studymate_api.dart';
import '../../state/study_controller.dart';
import 'event_helpers.dart';
import 'events_controller.dart';

/// Formulaire d'événement en **page entière** (création et modification).
///
/// * [event] : modification d'un événement existant ;
/// * [draft] : pré-remplissage venant de l'assistant IA ;
/// * [initialDate] : jour proposé pour une création manuelle.
///
/// Retourne `true` au `Navigator.pop` quand quelque chose a été enregistré
/// ou supprimé.
class EventFormPage extends StatefulWidget {
  const EventFormPage({
    super.key,
    required this.studyController,
    required this.events,
    this.event,
    this.draft,
    this.initialDate,
  });

  final StudyController studyController;
  final EventsController events;
  final StudyEvent? event;
  final EventDraft? draft;
  final DateTime? initialDate;

  @override
  State<EventFormPage> createState() => _EventFormPageState();
}

class _EventFormPageState extends State<EventFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _location;

  late String _type;
  late String _status;
  late DateTime _start;
  DateTime? _end;
  String? _courseId;
  double? _latitude;
  double? _longitude;
  late Set<int> _reminders;

  bool _saving = false;
  String? _error;

  // Recherche de lieux (Google Places via le backend).
  Timer? _debounce;
  List<PlaceSuggestion> _suggestions = const [];
  bool _placesDisabled = false;
  final String _sessionToken =
      DateTime.now().microsecondsSinceEpoch.toRadixString(36);

  StudyMateApi get _api => widget.events.api;
  bool get _isEditing => widget.event != null;
  bool get _isDeadline => _type == 'deadline';

  /// Nombre de jours calendaires couverts (1 = même jour).
  int get _spanDays {
    final end = _end;
    if (_isDeadline || end == null) return 1;
    return startOfDay(end).difference(startOfDay(_start)).inDays + 1;
  }

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    final draft = widget.draft;
    _title = TextEditingController(text: event?.title ?? draft?.title ?? '');
    _description = TextEditingController(
      text: event?.description ?? draft?.description ?? '',
    );
    _location = TextEditingController(
      text: event?.location ?? draft?.location ?? '',
    );
    _type = event?.eventType ?? draft?.eventType ?? 'other';
    _status = event?.status ?? 'planned';
    _courseId = event?.courseId;
    _latitude = event?.latitude;
    _longitude = event?.longitude;
    _reminders = {...?event?.reminderOffsets};
    if (event == null && draft == null) _reminders = {60};

    final day = widget.initialDate ?? DateTime.now();
    final fallbackStart = DateTime(day.year, day.month, day.day, 9);
    _start = event?.startsAt ?? draft?.startsAt ?? fallbackStart;
    _end = event?.endsAt ?? draft?.endsAt;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _title.dispose();
    _description.dispose();
    _location.dispose();
    super.dispose();
  }

  // ----- Dates ----------------------------------------------------------
  Future<void> _pickDate({required bool isEnd}) async {
    final current = isEnd ? (_end ?? _start) : _start;
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      final merged = DateTime(
        picked.year,
        picked.month,
        picked.day,
        current.hour,
        current.minute,
      );
      if (isEnd) {
        _end = merged;
      } else {
        final length = _end?.difference(_start);
        _start = merged;
        if (length != null) _end = _start.add(length);
      }
    });
  }

  Future<void> _pickTime({required bool isEnd}) async {
    final current = isEnd ? (_end ?? _start) : _start;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (picked == null) return;
    setState(() {
      final merged = DateTime(
        current.year,
        current.month,
        current.day,
        picked.hour,
        picked.minute,
      );
      if (isEnd) {
        _end = merged;
      } else {
        final length = _end?.difference(_start);
        _start = merged;
        if (length != null) _end = _start.add(length);
      }
    });
  }

  // ----- Lieux ----------------------------------------------------------
  void _onLocationChanged(String value) {
    // Une saisie manuelle invalide les coordonnées précédentes.
    _latitude = null;
    _longitude = null;
    _debounce?.cancel();
    final query = value.trim();
    if (_placesDisabled || query.length < 3) {
      if (_suggestions.isNotEmpty) setState(() => _suggestions = const []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        final results = await _api.autocompletePlaces(
          query,
          sessionToken: _sessionToken,
        );
        if (mounted && _location.text.trim() == query) {
          setState(() => _suggestions = results);
        }
      } on StudyMateApiException {
        // Non configuré ou indisponible : on garde la saisie libre.
        if (mounted) {
          setState(() {
            _placesDisabled = true;
            _suggestions = const [];
          });
        }
      }
    });
  }

  Future<void> _selectPlace(PlaceSuggestion suggestion) async {
    setState(() {
      _location.text = suggestion.name;
      _suggestions = const [];
    });
    if (suggestion.hasCoordinates) {
      setState(() {
        _latitude = suggestion.latitude;
        _longitude = suggestion.longitude;
      });
      return;
    }
    try {
      final details = await _api.getPlaceDetails(suggestion.placeId);
      if (!mounted) return;
      setState(() {
        _latitude = details.latitude;
        _longitude = details.longitude;
      });
    } on StudyMateApiException {
      // Les coordonnées sont un bonus.
    }
  }

  // ----- Enregistrement -------------------------------------------------
  StudyEvent _build() => StudyEvent(
        id: widget.event?.id ?? '',
        title: _title.text.trim(),
        eventType: _type,
        startsAt: _start,
        endsAt: _isDeadline ? null : _end,
        description:
            _description.text.trim().isEmpty ? null : _description.text.trim(),
        courseId: _courseId,
        location: _location.text.trim().isEmpty ? null : _location.text.trim(),
        latitude: _latitude,
        longitude: _longitude,
        status: _status,
        reminderOffsets: _reminders.toList()..sort((a, b) => b.compareTo(a)),
      );

  Future<bool> _confirmConflicts(StudyEvent candidate) async {
    if (candidate.status == 'cancelled' || candidate.eventType == 'deadline') {
      return true;
    }
    final conflicts = await _api.checkEventConflicts(
      startsAt: candidate.startsAt,
      endsAt: candidate.endsAt,
      eventType: candidate.eventType,
      excludeId: widget.event?.id,
    );
    if (conflicts.isEmpty || !mounted) return true;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded),
        title: const Text('Conflit d’horaire'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ce créneau chevauche :'),
            const SizedBox(height: 8),
            for (final item in conflicts.take(5))
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '• ${item.kind == 'course' ? 'Cours' : 'Événement'} '
                  '« ${item.title} » '
                  '(${formatDate(item.startsAt)}, '
                  '${formatTime(item.startsAt)}–${formatTime(item.endsAt)})',
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Modifier l’horaire'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Enregistrer quand même'),
          ),
        ],
      ),
    );
    return proceed == true;
  }

  Future<bool> _confirmMultiDay() async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.date_range_outlined),
        title: Text('Événement sur $_spanDays jours ?'),
        content: const Text(
          'La date de fin est un autre jour que le début : l’événement '
          'apparaîtra chaque jour de cette période dans l’agenda, avec un '
          'point de couleur sur chacun.\n\n'
          'Pour un examen qui a lieu un seul jour, corrige la fin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Corriger'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('C’est voulu'),
          ),
        ],
      ),
    );
    return proceed == true;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isDeadline && _end != null && _end!.isBefore(_start)) {
      setState(() => _error = 'La fin doit être après le début.');
      return;
    }
    if (_spanDays > 1 && !await _confirmMultiDay()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final candidate = _build();
      final proceed = await _confirmConflicts(candidate);
      if (!proceed) {
        if (mounted) setState(() => _saving = false);
        return;
      }
      if (_isEditing) {
        await _api.updateEvent(candidate, force: true);
      } else {
        await _api.createEvent(candidate, force: true);
      }
      if (mounted) Navigator.pop(context, true);
    } on StudyMateApiException catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error.message;
        });
      }
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer cet événement ?'),
        content: Text('« ${widget.event!.title} » sera supprimé définitivement.'),
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
    if (confirmed != true) return;
    try {
      await _api.deleteEvent(widget.event!.id);
      if (mounted) Navigator.pop(context, true);
    } on StudyMateApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  // ----- UI -------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final courses = widget.studyController.courses;
    final courseValue =
        courses.any((course) => course.id == _courseId) ? _courseId : null;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Modifier l’événement' : 'Nouvel événement'),
        actions: [
          if (_isEditing)
            IconButton(
              tooltip: 'Supprimer',
              onPressed: _saving ? null : _delete,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded),
            label: Text(_isEditing ? 'Enregistrer' : 'Créer l’événement'),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            if (widget.draft != null)
              Card(
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.auto_awesome_outlined),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Pré-rempli par l’IA : vérifie la date, l’heure et '
                          'le lieu avant d’enregistrer.',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            TextFormField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 200,
              decoration: const InputDecoration(
                labelText: 'Titre *',
                border: OutlineInputBorder(),
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Le titre est obligatoire'
                  : null,
            ),
            const SizedBox(height: 8),
            _sectionLabel('Type'),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final entry in eventTypeLabels.entries)
                  ChoiceChip(
                    avatar: Icon(
                      categoryIcon(entry.key),
                      size: 16,
                      color: categoryColor(entry.key),
                    ),
                    label: Text(entry.value),
                    selected: _type == entry.key,
                    onSelected: (_) => setState(() => _type = entry.key),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _sectionLabel(_isDeadline ? 'Échéance' : 'Début'),
            _dateTimeRow(
              value: _start,
              onDate: () => _pickDate(isEnd: false),
              onTime: () => _pickTime(isEnd: false),
            ),
            if (!_isDeadline) ...[
              const SizedBox(height: 12),
              _sectionLabel('Fin (facultative)'),
              if (_end == null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () => setState(
                      () => _end = _start.add(const Duration(hours: 1)),
                    ),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Ajouter une heure de fin'),
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: _dateTimeRow(
                        value: _end!,
                        onDate: () => _pickDate(isEnd: true),
                        onTime: () => _pickTime(isEnd: true),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Retirer la fin',
                      onPressed: () => setState(() => _end = null),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              if (_spanDays > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 18,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Cet événement dure $_spanDays jours : il apparaîtra '
                          'chaque jour dans l’agenda. Pour un examen d’un seul '
                          'jour, mets la fin le même jour (ou retire-la).',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _location,
              onChanged: _onLocationChanged,
              maxLength: 200,
              decoration: InputDecoration(
                labelText: 'Lieu',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.place_outlined),
                helperText: _placesDisabled
                    ? 'Recherche de lieux indisponible : saisie libre.'
                    : (_latitude != null ? 'Lieu localisé sur la carte' : null),
              ),
            ),
            if (_suggestions.isNotEmpty)
              Card(
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (final suggestion in _suggestions)
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.place_outlined, size: 20),
                        title: Text(suggestion.name),
                        subtitle: suggestion.address == null
                            ? null
                            : Text(suggestion.address!),
                        onTap: () => _selectPlace(suggestion),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: courseValue,
              decoration: const InputDecoration(
                labelText: 'Cours associé',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.school_outlined),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Aucun'),
                ),
                for (final course in courses)
                  DropdownMenuItem<String?>(
                    value: course.id,
                    child: Text(course.title, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (value) => setState(() => _courseId = value),
            ),
            const SizedBox(height: 16),
            _sectionLabel('Rappels'),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final entry in reminderChoices.entries)
                  FilterChip(
                    label: Text(entry.value),
                    selected: _reminders.contains(entry.key),
                    onSelected: (selected) => setState(() {
                      if (selected) {
                        if (_reminders.length < 5) _reminders.add(entry.key);
                      } else {
                        _reminders.remove(entry.key);
                      }
                    }),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Jusqu’à 5 rappels, envoyés avant le début par notification.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            if (_isEditing) ...[
              const SizedBox(height: 16),
              _sectionLabel('Statut'),
              SegmentedButton<String>(
                showSelectedIcon: false,
                segments: [
                  for (final entry in eventStatusLabels.entries)
                    ButtonSegment(value: entry.key, label: Text(entry.value)),
                ],
                selected: {_status},
                onSelectionChanged: (value) =>
                    setState(() => _status = value.first),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _description,
              maxLines: 4,
              minLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Description',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: Theme.of(context)
              .textTheme
              .labelLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      );

  Widget _dateTimeRow({
    required DateTime value,
    required VoidCallback onDate,
    required VoidCallback onTime,
  }) =>
      Row(
        children: [
          Expanded(
            flex: 3,
            child: OutlinedButton.icon(
              onPressed: onDate,
              icon: const Icon(Icons.calendar_today_outlined, size: 18),
              label: Text(
                '${weekdayName(value).substring(0, 3)} ${value.day} '
                '${monthName(value)} ${value.year}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: OutlinedButton.icon(
              onPressed: onTime,
              icon: const Icon(Icons.schedule_outlined, size: 18),
              label: Text(formatTime(value)),
            ),
          ),
        ],
      );
}
