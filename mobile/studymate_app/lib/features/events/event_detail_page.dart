import 'package:flutter/material.dart';

import '../../data/models/event_models.dart';
import '../../data/services/studymate_api.dart';
import '../../state/study_controller.dart';
import 'event_form_page.dart';
import 'event_helpers.dart';
import 'event_map_preview.dart';
import 'events_controller.dart';

/// Détail d'un événement : infos, rappels, actions (terminer, modifier, supprimer).
class EventDetailPage extends StatefulWidget {
  const EventDetailPage({
    super.key,
    required this.studyController,
    required this.events,
    required this.eventId,
  });

  final StudyController studyController;
  final EventsController events;
  final String eventId;

  @override
  State<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends State<EventDetailPage> {
  StudyEvent? _event;
  String? _error;
  bool _loading = true;
  bool _changed = false;

  StudyMateApi get _api => widget.events.api;

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
      final event = await _api.getEvent(widget.eventId);
      if (mounted) setState(() => _event = event);
    } on StudyMateApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EventFormPage(
          studyController: widget.studyController,
          events: widget.events,
          event: _event,
        ),
      ),
    );
    if (saved != true || !mounted) return;
    _changed = true;
    try {
      await _api.getEvent(widget.eventId);
      await _load();
    } on StudyMateApiException {
      // L'événement a été supprimé depuis le formulaire.
      if (mounted) Navigator.pop(context, true);
    }
  }

  Future<void> _setStatus(String status) async {
    final event = _event;
    if (event == null) return;
    try {
      final updated = await _api.updateEvent(
        StudyEvent(
          id: event.id,
          title: event.title,
          eventType: event.eventType,
          startsAt: event.startsAt,
          endsAt: event.endsAt,
          description: event.description,
          courseId: event.courseId,
          location: event.location,
          latitude: event.latitude,
          longitude: event.longitude,
          status: status,
          reminderOffsets: event.reminderOffsets,
        ),
        force: true,
      );
      _changed = true;
      if (mounted) setState(() => _event = updated);
    } on StudyMateApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer cet événement ?'),
        content: const Text('Cette action est définitive.'),
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
      await _api.deleteEvent(widget.eventId);
      if (mounted) Navigator.pop(context, true);
    } on StudyMateApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = _event;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Événement'),
          actions: [
            if (event != null) ...[
              IconButton(
                tooltip: 'Modifier',
                onPressed: _edit,
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: 'Supprimer',
                onPressed: _delete,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : event == null
                ? _errorView()
                : _content(event),
      ),
    );
  }

  Widget _errorView() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error ?? 'Événement introuvable.'),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _load, child: const Text('Réessayer')),
            ],
          ),
        ),
      );

  Widget _content(StudyEvent event) {
    final color = categoryColor(event.eventType);
    final courseTitle = widget.studyController.courses
        .where((course) => course.id == event.courseId)
        .map((course) => course.title)
        .firstOrNull;
    final end = event.endsAt;
    final when = end == null
        ? formatDateTime(event.startsAt)
        : sameDay(event.startsAt, end)
            ? '${formatDate(event.startsAt)} · '
                '${formatTime(event.startsAt)} – ${formatTime(end)}'
            : '${formatDateTime(event.startsAt)}\n→ ${formatDateTime(end)}';
    final muted = event.status != 'planned';
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(categoryIcon(event.eventType), color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          decoration:
                              muted ? TextDecoration.lineThrough : null,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    children: [
                      Chip(
                        visualDensity: VisualDensity.compact,
                        label: Text(event.typeLabel),
                      ),
                      Chip(
                        visualDensity: VisualDensity.compact,
                        label: Text(event.statusLabel),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _info(Icons.schedule_outlined, when),
        if (event.location != null && event.location!.isNotEmpty)
          _info(
            Icons.place_outlined,
            event.location!,
          ),
        if (event.latitude != null && event.longitude != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: EventMapPreview(
              latitude: event.latitude!,
              longitude: event.longitude!,
            ),
          ),
        if (courseTitle != null) _info(Icons.school_outlined, courseTitle),
        _info(
          Icons.alarm_outlined,
          event.reminderOffsets.isEmpty
              ? 'Aucun rappel'
              : event.reminderOffsets
                  .map((minutes) => reminderChoices[minutes] ?? '$minutes min')
                  .join(', '),
          subtitle: event.reminderOffsets.isEmpty ? null : 'avant le début',
        ),
        if (event.description != null && event.description!.isNotEmpty) ...[
          const Divider(height: 28),
          Text(event.description!),
        ],
        const SizedBox(height: 24),
        if (event.status == 'planned')
          FilledButton.icon(
            onPressed: () => _setStatus('done'),
            icon: const Icon(Icons.check_circle_outline_rounded),
            label: const Text('Marquer comme terminé'),
          )
        else
          OutlinedButton.icon(
            onPressed: () => _setStatus('planned'),
            icon: const Icon(Icons.restore_rounded),
            label: const Text('Remettre au planning'),
          ),
        if (event.status == 'planned') ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _setStatus('cancelled'),
            icon: const Icon(Icons.event_busy_outlined),
            label: const Text('Annuler l’événement'),
          ),
        ],
      ],
    );
  }

  Widget _info(IconData icon, String text, {String? subtitle}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(text),
                  if (subtitle != null)
                    Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      );
}
