import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/planning_models.dart';
import '../../data/services/studymate_api.dart';

const _weekdays = [
  'Lundi',
  'Mardi',
  'Mercredi',
  'Jeudi',
  'Vendredi',
  'Samedi',
  'Dimanche'
];
const _months = [
  'janv.',
  'févr.',
  'mars',
  'avr.',
  'mai',
  'juin',
  'juil.',
  'août',
  'sept.',
  'oct.',
  'nov.',
  'déc.',
];

String _hm(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

String _dayLabel(DateTime day) => '${day.day} ${_months[day.month - 1]}';

DateTime _monday(DateTime value) {
  final day = DateTime(value.year, value.month, value.day);
  return day.subtract(Duration(days: day.weekday - 1));
}

/// Emploi du temps réel de la semaine : cours, événements, jours fériés
/// (API Nager.Date), conflits, créneaux libres, et partage par QR code.
class TimetablePage extends StatefulWidget {
  const TimetablePage({super.key, required this.api});

  final StudyMateApi api;

  @override
  State<TimetablePage> createState() => _TimetablePageState();
}

class _TimetablePageState extends State<TimetablePage> {
  DateTime _weekStart = _monday(DateTime.now());
  WeekAgenda? _agenda;
  String? _error;
  bool _loading = true;

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
      final agenda = await widget.api.getWeekAgenda(_weekStart);
      if (mounted) setState(() => _agenda = agenda);
    } on StudyMateApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _shiftWeek(int weeks) {
    setState(() => _weekStart = _weekStart.add(Duration(days: 7 * weeks)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final agenda = _agenda;
    final weekEnd = _weekStart.add(const Duration(days: 6));
    final isCurrentWeek = _monday(DateTime.now()) == _weekStart;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emploi du temps'),
        actions: [
          IconButton(
            tooltip: 'Partager par QR code',
            icon: const Icon(Icons.qr_code_2_rounded),
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => _ShareSheet(api: widget.api),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
          children: [
            Row(
              children: [
                IconButton.filledTonal(
                  tooltip: 'Semaine précédente',
                  onPressed: () => _shiftWeek(-1),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '${_dayLabel(_weekStart)} – ${_dayLabel(weekEnd)}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (!isCurrentWeek)
                        TextButton(
                          onPressed: () {
                            setState(
                                () => _weekStart = _monday(DateTime.now()));
                            _load();
                          },
                          child: const Text('Revenir à cette semaine'),
                        )
                      else
                        Text(
                          'Cette semaine',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Semaine suivante',
                  onPressed: () => _shiftWeek(1),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (_loading && agenda == null)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null && agenda == null)
              _ErrorCard(message: _error!, onRetry: _load)
            else if (agenda != null) ...[
              _WeekSummary(agenda: agenda),
              const SizedBox(height: 16),
              for (final day in agenda.days) ...[
                _DayCard(day: day),
                const SizedBox(height: 12),
              ],
              Text(
                'Jours fériés : API publique Nager.Date. Les cours tombant un '
                'jour férié sont considérés comme annulés.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WeekSummary extends StatelessWidget {
  const _WeekSummary({required this.agenda});

  final WeekAgenda agenda;

  @override
  Widget build(BuildContext context) {
    String hours(double value) => value == value.roundToDouble()
        ? '${value.toInt()} h'
        : '${value.toStringAsFixed(1)} h';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppGradients.brand,
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Stat(
                  icon: Icons.school_rounded,
                  value: hours(agenda.courseHours),
                  label: 'de cours'),
              _Stat(
                  icon: Icons.self_improvement_rounded,
                  value: hours(agenda.freeHours),
                  label: 'libres'),
              _Stat(
                icon: Icons.warning_amber_rounded,
                value: '${agenda.conflictCount}',
                label: agenda.conflictCount > 1 ? 'conflits' : 'conflit',
              ),
            ],
          ),
          if (agenda.holidays.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              '🎉 Férié : ${agenda.holidays.map((h) => '${h.label} (${_dayLabel(h.date)})').join(', ')}',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ],
          if (agenda.byCourse.isNotEmpty) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: SizedBox(
                height: 10,
                child: Row(
                  children: [
                    for (final course in agenda.byCourse)
                      Expanded(
                        flex: (course.hours * 10).round().clamp(1, 1000),
                        child: ColoredBox(
                            color: AppPalette.accentFor(course.courseId)),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 4,
              children: [
                for (final course in agenda.byCourse)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppPalette.accentFor(course.courseId),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${course.title} · ${hours(course.hours)}',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800),
            ),
            Text(label,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85), fontSize: 12)),
          ],
        ),
      );
}

class _DayCard extends StatelessWidget {
  const _DayCard({required this.day});

  final AgendaDay day;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final today = DateTime.now();
    final isToday = day.date.year == today.year &&
        day.date.month == today.month &&
        day.date.day == today.day;
    final conflictIds = {
      for (final pair in day.conflicts)
        for (final item in pair) item.id,
    };

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        side: BorderSide(
          color: isToday ? colors.primary : colors.outlineVariant,
          width: isToday ? 1.6 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  _weekdays[day.date.weekday - 1],
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(width: 8),
                Text(_dayLabel(day.date),
                    style: TextStyle(color: colors.onSurfaceVariant)),
                const Spacer(),
                if (isToday)
                  _Badge(label: 'Aujourd’hui', color: colors.primary),
              ],
            ),
            if (day.holiday case final holiday?) ...[
              const SizedBox(height: 8),
              _Badge(
                label: '🎉 Jour férié · ${holiday.label}',
                color: AppPalette.amber,
              ),
            ],
            if (day.conflicts.isNotEmpty) ...[
              const SizedBox(height: 10),
              for (final pair in day.conflicts)
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppPalette.coral.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: AppPalette.coral, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Conflit : « ${pair.first.title} » et « ${pair.last.title} »',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 10),
            if (day.items.isEmpty && day.cancelled.isEmpty)
              Text(
                day.holiday != null
                    ? 'Profite de ta journée !'
                    : 'Aucun cours ni événement.',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            for (final item in day.items)
              _AgendaTile(
                  item: item, inConflict: conflictIds.contains(item.id)),
            for (final item in day.cancelled)
              _AgendaTile(item: item, cancelled: true),
            if (day.freeSlots.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final slot in day.freeSlots)
                    _Badge(
                      label: 'Libre ${_hm(slot.startsAt)}–${_hm(slot.endsAt)}',
                      color: AppPalette.mint,
                      icon: Icons.event_available_rounded,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AgendaTile extends StatelessWidget {
  const _AgendaTile(
      {required this.item, this.inConflict = false, this.cancelled = false});

  final AgendaItem item;
  final bool inConflict;
  final bool cancelled;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = cancelled
        ? colors.outline
        : item.isCourse
            ? AppPalette.accentFor(item.id)
            : AppPalette.sky;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_hm(item.startsAt),
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(_hm(item.endsAt),
                    style: TextStyle(
                        color: colors.onSurfaceVariant, fontSize: 12)),
              ],
            ),
          ),
          Container(
            width: 4,
            height: 38,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
                color: accent, borderRadius: BorderRadius.circular(4)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    decoration: cancelled ? TextDecoration.lineThrough : null,
                    color: cancelled ? colors.onSurfaceVariant : null,
                  ),
                ),
                Text(
                  [
                    if (cancelled)
                      'Annulé (férié)'
                    else if (item.isCourse)
                      'Cours'
                    else
                      'Événement',
                    if (item.room?.isNotEmpty == true) item.room!,
                  ].join(' · '),
                  style:
                      TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
                ),
              ],
            ),
          ),
          if (inConflict)
            const Icon(Icons.warning_amber_rounded,
                color: AppPalette.coral, size: 18),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                    color: color, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(Icons.cloud_off_rounded,
                  color: Theme.of(context).colorScheme.error, size: 34),
              const SizedBox(height: 10),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 10),
              FilledButton.tonal(
                  onPressed: onRetry, child: const Text('Réessayer')),
            ],
          ),
        ),
      );
}

/// Feuille de partage : crée un lien public temporaire et affiche son QR code
/// (image générée par l'API QR Server).
class _ShareSheet extends StatefulWidget {
  const _ShareSheet({required this.api});

  final StudyMateApi api;

  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  TimetableShare? _share;
  String? _error;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _loadOrCreate();
  }

  Future<void> _loadOrCreate() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final existing = await widget.api.getTimetableShares();
      final share = existing.isNotEmpty
          ? existing.first
          : await widget.api.createTimetableShare();
      if (mounted) setState(() => _share = share);
    } on StudyMateApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _revoke() async {
    final share = _share;
    if (share == null) return;
    setState(() => _busy = true);
    try {
      await widget.api.revokeTimetableShare(share.id);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lien de partage désactivé.')),
      );
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
    final share = _share;
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Partager mon emploi du temps',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              'Scanne ce code avec un téléphone connecté au même réseau : il '
              'ouvre une page avec tes cours (sans tes tâches ni tes notes).',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 18),
            if (_busy && share == null)
              const SizedBox(
                  height: 240,
                  child: Center(child: CircularProgressIndicator()))
            else if (_error != null && share == null)
              Text(_error!, style: TextStyle(color: colors.error))
            else if (share != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colors.outlineVariant),
                ),
                child: share.qrUrl == null
                    ? const SizedBox.square(
                        dimension: 220, child: Icon(Icons.qr_code_2, size: 120))
                    : Image.network(
                        share.qrUrl!,
                        width: 220,
                        height: 220,
                        loadingBuilder: (context, child, progress) =>
                            progress == null
                                ? child
                                : const SizedBox.square(
                                    dimension: 220,
                                    child: Center(
                                        child: CircularProgressIndicator()),
                                  ),
                        errorBuilder: (_, __, ___) => const SizedBox.square(
                          dimension: 220,
                          child: Center(
                              child: Text('QR indisponible\n(pas d’Internet ?)',
                                  textAlign: TextAlign.center)),
                        ),
                      ),
              ),
              const SizedBox(height: 10),
              Text(
                'Valable jusqu’au ${share.expiresAt.day}/${share.expiresAt.month} '
                'à ${_hm(share.expiresAt)}',
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _revoke,
                      icon: const Icon(Icons.link_off_rounded),
                      label: const Text('Désactiver'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                            ClipboardData(text: share.link));
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Lien copié.')),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded),
                      label: const Text('Copier'),
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
}
