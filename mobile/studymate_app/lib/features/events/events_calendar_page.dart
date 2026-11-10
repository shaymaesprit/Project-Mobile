import 'package:flutter/material.dart';

import '../../data/models/event_models.dart';
import '../../data/services/studymate_api.dart';
import '../../state/study_controller.dart';
import 'event_detail_page.dart';
import 'event_form_page.dart';
import 'event_helpers.dart';
import 'events_controller.dart';
import 'notifications_center_page.dart';

enum _CalendarView { month, week, day }

/// Page « Agenda » : calendrier unifié (événements, cours, échéances de tâches)
/// en vues mois / semaine / jour, avec création rapide par phrase (IA).
class EventsCalendarPage extends StatefulWidget {
  const EventsCalendarPage({
    super.key,
    required this.studyController,
    required this.events,
  });

  final StudyController studyController;
  final EventsController events;

  @override
  State<EventsCalendarPage> createState() => _EventsCalendarPageState();
}

class _EventsCalendarPageState extends State<EventsCalendarPage> {
  _CalendarView _view = _CalendarView.month;
  DateTime _focused = startOfDay(DateTime.now());
  DateTime _selected = startOfDay(DateTime.now());

  EventsController get _events => widget.events;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Plage affichée : la grille complète du mois, la semaine ou le jour.
  (DateTime, DateTime) get _range {
    switch (_view) {
      case _CalendarView.month:
        final first = DateTime(_focused.year, _focused.month, 1);
        final gridStart = startOfWeek(first);
        return (gridStart, gridStart.add(const Duration(days: 42)));
      case _CalendarView.week:
        final start = startOfWeek(_focused);
        return (start, start.add(const Duration(days: 7)));
      case _CalendarView.day:
        final start = startOfDay(_focused);
        return (start, start.add(const Duration(days: 1)));
    }
  }

  Future<void> _load() {
    final (from, to) = _range;
    return _events.loadRange(from, to);
  }

  void _shift(int direction) {
    setState(() {
      switch (_view) {
        case _CalendarView.month:
          _focused = DateTime(_focused.year, _focused.month + direction, 1);
          _selected = _focused;
        case _CalendarView.week:
          _focused = _focused.add(Duration(days: 7 * direction));
          _selected = _focused;
        case _CalendarView.day:
          _focused = _focused.add(Duration(days: direction));
          _selected = _focused;
      }
    });
    _load();
  }

  void _goToday() {
    setState(() {
      _focused = startOfDay(DateTime.now());
      _selected = _focused;
    });
    _load();
  }

  String get _title => switch (_view) {
        _CalendarView.month => '${monthName(_focused)} ${_focused.year}',
        _CalendarView.week => () {
            final start = startOfWeek(_focused);
            final end = start.add(const Duration(days: 6));
            return '${start.day} ${monthName(start)} – ${end.day} ${monthName(end)}';
          }(),
        _CalendarView.day => formatDate(_focused),
      };

  Future<void> _openForm({EventDraft? draft, DateTime? day}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EventFormPage(
          studyController: widget.studyController,
          events: _events,
          draft: draft,
          initialDate: day ?? _selected,
        ),
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _openDetail(CalendarItem item) async {
    if (!item.isEvent) {
      final message = item.kind == 'course'
          ? 'Cours récurrent : modifie-le depuis l’onglet Cours.'
          : 'Échéance de tâche : modifie-la depuis l’onglet Tâches.';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EventDetailPage(
          studyController: widget.studyController,
          events: _events,
          eventId: item.id,
        ),
      ),
    );
    if (changed == true) _load();
  }

  /// Recherche SQL (LIKE) dans la base locale, utilisable sans réseau.
  Future<void> _search() async {
    final picked = await showSearch<CalendarItem?>(
      context: context,
      delegate: _EventSearchDelegate(_events),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _focused = startOfDay(picked.startsAt);
      _selected = _focused;
    });
    await _load();
    if (mounted) _openDetail(picked);
  }

  Future<void> _quickAdd() async {
    final draft = await showModalBottomSheet<EventDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _QuickAddSheet(api: _events.api),
    );
    if (draft != null && mounted) _openForm(draft: draft);
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => NotificationsCenterPage(
          studyController: widget.studyController,
          events: _events,
        ),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agenda'),
        actions: [
          IconButton(
            tooltip: 'Rechercher (hors ligne possible)',
            onPressed: _search,
            icon: const Icon(Icons.search_rounded),
          ),
          IconButton(
            tooltip: 'Ajouter avec une phrase (IA)',
            onPressed: _quickAdd,
            icon: const Icon(Icons.auto_awesome_outlined),
          ),
          ListenableBuilder(
            listenable: _events,
            builder: (context, _) => IconButton(
              tooltip: 'Notifications',
              onPressed: _openNotifications,
              icon: Badge(
                isLabelVisible: _events.unreadCount > 0,
                label: Text('${_events.unreadCount}'),
                child: const Icon(Icons.notifications_outlined),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add-event',
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nouvel événement'),
      ),
      body: ListenableBuilder(
        listenable: _events,
        builder: (context, _) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: SegmentedButton<_CalendarView>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: _CalendarView.month, label: Text('Mois')),
                  ButtonSegment(
                      value: _CalendarView.week, label: Text('Semaine')),
                  ButtonSegment(value: _CalendarView.day, label: Text('Jour')),
                ],
                selected: {_view},
                onSelectionChanged: (value) {
                  setState(() => _view = value.first);
                  _load();
                },
              ),
            ),
            _header(),
            if (_events.isLoading) const LinearProgressIndicator(minHeight: 2),
            if (_events.isOffline)
              OfflineBanner(lastSyncedAt: _events.lastSyncedAt),
            if (_events.errorMessage != null) _errorBanner(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: switch (_view) {
                  _CalendarView.month => _monthView(),
                  _CalendarView.week => _weekView(),
                  _CalendarView.day => _dayList(_focused),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Précédent',
              onPressed: () => _shift(-1),
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              child: Text(
                _title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            TextButton(onPressed: _goToday, child: const Text('Aujourd’hui')),
            IconButton(
              tooltip: 'Suivant',
              onPressed: () => _shift(1),
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
      );

  Widget _errorBanner() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        child: Material(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Text(
              _events.errorMessage!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
                fontSize: 12,
              ),
            ),
          ),
        ),
      );

  // ----- Mois -----------------------------------------------------------
  Widget _monthView() {
    final (gridStart, _) = _range;
    final today = startOfDay(DateTime.now());
    final colors = Theme.of(context).colorScheme;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              for (final label in const ['L', 'M', 'M', 'J', 'V', 'S', 'D'])
                Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: [
              for (var week = 0; week < 6; week++)
                Row(
                  children: [
                    for (var d = 0; d < 7; d++)
                      Expanded(
                        child: _dayCell(
                          gridStart.add(Duration(days: week * 7 + d)),
                          today,
                          colors,
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
        const Divider(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            formatDate(_selected),
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        ..._tilesFor(_selected),
      ],
    );
  }

  Widget _dayCell(DateTime day, DateTime today, ColorScheme colors) {
    final inMonth = day.month == _focused.month;
    final isSelected = sameDay(day, _selected);
    final isToday = sameDay(day, today);
    final categories = _events
        .itemsOn(day)
        .where((item) => !item.isCancelled)
        .map((item) => item.category)
        .toSet()
        .take(3)
        .toList();
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => setState(() => _selected = day),
      child: Container(
        height: 52,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isSelected ? colors.primaryContainer : null,
          border: isToday ? Border.all(color: colors.primary, width: 1.4) : null,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${day.day}',
              style: TextStyle(
                fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                color: inMonth ? null : colors.onSurface.withValues(alpha: 0.35),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 6,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final category in categories)
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      decoration: BoxDecoration(
                        color: categoryColor(category),
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ----- Semaine / Jour -------------------------------------------------
  Widget _weekView() {
    final start = startOfWeek(_focused);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        for (var i = 0; i < 7; i++) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
            child: Text(
              formatDate(start.add(Duration(days: i))),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: sameDay(start.add(Duration(days: i)), DateTime.now())
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
            ),
          ),
          ..._tilesFor(start.add(Duration(days: i))),
        ],
      ],
    );
  }

  Widget _dayList(DateTime day) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 96),
        children: _tilesFor(day),
      );

  List<Widget> _tilesFor(DateTime day) {
    final items = _events.itemsOn(day);
    if (items.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
          child: Text(
            'Rien de prévu',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ];
    }
    return [for (final item in items) _tile(item)];
  }

  Widget _tile(CalendarItem item) {
    final color = categoryColor(item.category);
    final end = item.endsAt;
    final time = end == null
        ? formatTime(item.startsAt)
        : '${formatTime(item.startsAt)} – ${formatTime(end)}';
    final muted = item.isCancelled || item.isDone;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        onTap: () => _openDetail(item),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(categoryIcon(item.category), color: color, size: 20),
        ),
        title: Text(
          item.title,
          style: TextStyle(
            decoration: muted ? TextDecoration.lineThrough : null,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          [
            time,
            if (item.location != null && item.location!.isNotEmpty)
              item.location!,
          ].join(' · '),
        ),
        trailing: Text(
          item.kindLabel,
          style: TextStyle(color: color, fontSize: 12),
        ),
      ),
    );
  }
}

/// Feuille de saisie « une phrase → un événement » (assistant IA).
class _QuickAddSheet extends StatefulWidget {
  const _QuickAddSheet({required this.api});

  final StudyMateApi api;

  @override
  State<_QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends State<_QuickAddSheet> {
  final _text = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _text.text.trim();
    if (text.length < 3) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final draft = await widget.api.parseEventText(text);
      if (mounted) Navigator.pop(context, draft);
    } on StudyMateApiException catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Décris ton événement',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Exemple : « examen de BD lundi à 14h en salle B12 ». '
            'Tu pourras tout vérifier avant d’enregistrer.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _text,
            autofocus: true,
            maxLength: 500,
            minLines: 2,
            maxLines: 4,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Rendu du rapport vendredi avant 18h…',
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _busy ? null : _submit,
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome_outlined),
              label: Text(_busy ? 'Analyse…' : 'Pré-remplir le formulaire'),
            ),
          ),
        ],
      ),
    );
  }
}


/// Délégué de recherche : interroge SQLite (titre, lieu, catégorie).
class _EventSearchDelegate extends SearchDelegate<CalendarItem?> {
  _EventSearchDelegate(this.events)
      : super(searchFieldLabel: 'Rechercher un événement…');

  final EventsController events;

  @override
  List<Widget> buildActions(BuildContext context) => [
        if (query.isNotEmpty)
          IconButton(
            tooltip: 'Effacer',
            onPressed: () => query = '',
            icon: const Icon(Icons.clear_rounded),
          ),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
        tooltip: 'Retour',
        onPressed: () => close(context, null),
        icon: const Icon(Icons.arrow_back_rounded),
      );

  @override
  Widget buildResults(BuildContext context) => _results();

  @override
  Widget buildSuggestions(BuildContext context) => _results();

  Widget _results() {
    if (query.trim().isEmpty) {
      return const Center(child: Text('Tape un titre, un lieu ou un type.'));
    }
    return FutureBuilder<List<CalendarItem>>(
      future: events.search(query),
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <CalendarItem>[];
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (items.isEmpty) {
          return const Center(child: Text('Aucun résultat.'));
        }
        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final item = items[index];
            return ListTile(
              leading: Icon(item.isEvent
                  ? Icons.event_rounded
                  : item.kind == 'course'
                      ? Icons.school_outlined
                      : Icons.task_alt_rounded),
              title: Text(item.title),
              subtitle: Text(
                '${item.kindLabel} · ${formatDateTime(item.startsAt)}'
                '${item.location == null ? '' : ' · ${item.location}'}',
              ),
              onTap: () => close(context, item),
            );
          },
        );
      },
    );
  }
}
