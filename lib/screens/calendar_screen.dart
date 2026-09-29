import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/study_models.dart';
import '../utils/event_utils.dart';
import '../widgets/event_card.dart';

/// Academic calendar: month / week / day views, type filters and navigation.
/// Loading, error and empty states are handled here so a real backend can be plugged in later.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({
    super.key,
    required this.events,
    required this.mode,
    required this.onMode,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onOpen,
    required this.courseName,
    this.unreadCount = 0,
    this.onNotifications,
    this.loading = false,
    this.error,
    this.onRetry,
  });
  final List<StudyEvent> events;
  final String mode;
  final void Function(String) onMode;
  final void Function(DateTime day) onAdd;
  final void Function(StudyEvent) onEdit;
  final void Function(StudyEvent) onDelete;
  final void Function(StudyEvent) onOpen;
  final String Function(String?) courseName;
  final int unreadCount;
  final VoidCallback? onNotifications;
  final bool loading;
  final String? error;
  final VoidCallback? onRetry;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  static const _modes = ['Day', 'Week', 'Month'];
  DateTime _focused = dateOnly(DateTime.now());
  EventType? _filter;

  List<StudyEvent> _forDay(DateTime day) => eventsForDay(widget.events, day, type: _filter);

  void _shift(int direction) {
    setState(() {
      switch (widget.mode) {
        case 'Month':
          final lastDay = DateTime(_focused.year, _focused.month + direction + 1, 0).day;
          _focused = DateTime(_focused.year, _focused.month + direction, math.min(_focused.day, lastDay));
        case 'Week':
          _focused = DateTime(_focused.year, _focused.month, _focused.day + 7 * direction);
        default:
          _focused = DateTime(_focused.year, _focused.month, _focused.day + direction);
      }
    });
  }

  String get _label {
    switch (widget.mode) {
      case 'Day':
        return '${weekdayName(_focused.weekday)}, ${_focused.day} ${monthShort(_focused.month)} ${_focused.year}';
      case 'Week':
        final s = startOfWeek(_focused);
        final e = DateTime(s.year, s.month, s.day + 6);
        return s.month == e.month
            ? '${s.day} – ${e.day} ${monthShort(e.month)} ${e.year}'
            : '${s.day} ${monthShort(s.month)} – ${e.day} ${monthShort(e.month)} ${e.year}';
      default:
        return '${monthName(_focused.month)} ${_focused.year}';
    }
  }

  String _count(int n) => n == 0 ? 'No events' : (n == 1 ? '1 event' : '$n events');

  Widget _card(StudyEvent e, {bool compact = false}) => EventCard(
        event: e,
        courseName: widget.courseName,
        onTap: () => widget.onOpen(e),
        onEdit: () => widget.onEdit(e),
        onDelete: () => widget.onDelete(e),
        compact: compact,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Calendar', style: Theme.of(context).textTheme.titleLarge),
              Row(children: [
                IconButton(
                  tooltip: 'Notifications',
                  onPressed: widget.onNotifications,
                  icon: Badge(isLabelVisible: widget.unreadCount > 0, label: Text('${widget.unreadCount}'), child: const Icon(Icons.notifications_none_rounded)),
                ),
                IconButton(tooltip: 'Add event', onPressed: () => widget.onAdd(_focused), icon: const Icon(Icons.add_rounded)),
              ]),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              IconButton(tooltip: 'Previous', onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left_rounded)),
              Expanded(child: Text(_label, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium)),
              TextButton(onPressed: () => setState(() => _focused = dateOnly(DateTime.now())), child: const Text('Today')),
              IconButton(tooltip: 'Next', onPressed: () => _shift(1), icon: const Icon(Icons.chevron_right_rounded)),
            ]),
            const SizedBox(height: 4),
            ToggleButtons(
              isSelected: _modes.map((value) => value == widget.mode).toList(),
              constraints: const BoxConstraints(minWidth: 88, minHeight: 38),
              borderRadius: BorderRadius.circular(12),
              onPressed: (index) => widget.onMode(_modes[index]),
              children: _modes.map((value) => Text(value)).toList(),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 38,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                _TypeChip(label: 'All', color: calendarPrimary, selected: _filter == null, onTap: () => setState(() => _filter = null)),
                for (final type in EventType.values)
                  _TypeChip(label: type.pluralLabel, color: type.color, selected: _filter == type, onTap: () => setState(() => _filter = type)),
              ]),
            ),
            const SizedBox(height: 10),
            Expanded(child: _body()),
          ]),
        ),
      ),
    );
  }

  Widget _body() {
    if (widget.loading) return const Center(child: CircularProgressIndicator());
    if (widget.error != null) return _ErrorState(message: widget.error!, onRetry: widget.onRetry);
    switch (widget.mode) {
      case 'Day':
        return _dayView();
      case 'Week':
        return _weekView();
      default:
        return _monthView();
    }
  }

  // ---------------------------------------------------------------- month
  Widget _monthView() {
    final first = DateTime(_focused.year, _focused.month, 1);
    final daysInMonth = DateTime(_focused.year, _focused.month + 1, 0).day;
    final lead = first.weekday - 1;
    final rows = ((lead + daysInMonth) / 7).ceil();
    final selectedEvents = _forDay(_focused);
    return ListView(padding: const EdgeInsets.only(bottom: 110), children: [
      Row(children: [
        for (var i = 1; i <= 7; i++)
          Expanded(child: Center(child: Text(weekdayShort(i), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: calendarMuted)))),
      ]),
      const SizedBox(height: 4),
      for (var r = 0; r < rows; r++)
        Row(children: [for (var c = 0; c < 7; c++) Expanded(child: _dayCell(r * 7 + c - lead + 1, daysInMonth))]),
      const SizedBox(height: 16),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(formatDate(_focused), style: Theme.of(context).textTheme.titleMedium),
        Text(_count(selectedEvents.length), style: const TextStyle(color: calendarMuted)),
      ]),
      const SizedBox(height: 10),
      if (selectedEvents.isEmpty)
        _EmptyState(title: 'No events planned', hint: 'Nothing scheduled for this day.', actionLabel: 'Add event', onAction: () => widget.onAdd(_focused))
      else
        for (final e in selectedEvents) Padding(padding: const EdgeInsets.only(bottom: 10), child: _card(e)),
    ]);
  }

  Widget _dayCell(int number, int daysInMonth) {
    if (number < 1 || number > daysInMonth) return const SizedBox(height: 54);
    final date = DateTime(_focused.year, _focused.month, number);
    final selected = isSameDay(date, _focused);
    final today = isSameDay(date, DateTime.now());
    final types = _forDay(date).map((e) => e.type).toSet().take(3).toList();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _focused = date),
      child: Container(
        height: 50,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: selected ? calendarPrimary : null,
          borderRadius: BorderRadius.circular(14),
          border: today && !selected ? Border.all(color: calendarPrimary, width: 1.5) : null,
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('$number', style: TextStyle(fontWeight: today || selected ? FontWeight.w700 : FontWeight.w500, color: selected ? Colors.white : const Color(0xFF1E293B))),
          const SizedBox(height: 4),
          SizedBox(
            height: 6,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              for (final t in types)
                Container(width: 6, height: 6, margin: const EdgeInsets.symmetric(horizontal: 1.5), decoration: BoxDecoration(shape: BoxShape.circle, color: selected ? Colors.white : t.color)),
            ]),
          ),
        ]),
      ),
    );
  }

  // ----------------------------------------------------------------- week
  Widget _weekView() {
    final start = startOfWeek(_focused);
    return ListView(padding: const EdgeInsets.only(bottom: 110), children: [
      for (var i = 0; i < 7; i++) _weekDay(DateTime(start.year, start.month, start.day + i)),
    ]);
  }

  Widget _weekDay(DateTime day) {
    final events = _forDay(day);
    final today = isSameDay(day, DateTime.now());
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            setState(() => _focused = day);
            widget.onMode('Day');
          },
          child: Row(children: [
            Container(
              width: 46,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(color: today ? calendarPrimary : const Color(0xFFEDF6F9), borderRadius: BorderRadius.circular(14)),
              child: Column(children: [
                Text(weekdayShort(day.weekday), style: TextStyle(fontSize: 11, color: today ? Colors.white70 : calendarMuted)),
                Text('${day.day}', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: today ? Colors.white : const Color(0xFF1E293B))),
              ]),
            ),
            const SizedBox(width: 12),
            Text(_count(events.length), style: const TextStyle(color: calendarMuted)),
            const Spacer(),
            const Icon(Icons.chevron_right_rounded, color: calendarMuted),
          ]),
        ),
        for (final e in events)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 46, child: Padding(padding: const EdgeInsets.only(top: 14), child: Text(formatTime(e.dateTime), textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: calendarMuted)))),
              const SizedBox(width: 12),
              Expanded(child: _card(e, compact: true)),
            ]),
          ),
      ]),
    );
  }

  // ------------------------------------------------------------------ day
  Widget _dayView() {
    final events = _forDay(_focused);
    if (events.isEmpty) {
      return ListView(children: [
        _EmptyState(title: 'No events planned', hint: 'Your day is free.', actionLabel: 'Add event', onAction: () => widget.onAdd(_focused)),
      ]);
    }
    final firstHour = math.min(7, events.first.dateTime.hour);
    final lastHour = events.map((e) => e.dateTime.hour).fold<int>(20, math.max);
    final now = DateTime.now();
    return ListView(padding: const EdgeInsets.only(bottom: 110), children: [
      Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_count(events.length), style: const TextStyle(color: calendarMuted))),
      for (var h = firstHour; h <= lastHour; h++)
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 48,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${h.toString().padLeft(2, '0')}:00',
                style: TextStyle(fontSize: 12, fontWeight: isSameDay(_focused, now) && now.hour == h ? FontWeight.w700 : FontWeight.w400, color: isSameDay(_focused, now) && now.hour == h ? calendarPrimary : calendarMuted),
              ),
            ),
          ),
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 56),
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFE2E8F0)))),
              child: Column(children: [
                for (final e in events.where((e) => e.dateTime.hour == h)) Padding(padding: const EdgeInsets.only(bottom: 6), child: _card(e)),
              ]),
            ),
          ),
        ]),
    ]);
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.label, required this.color, required this.selected, required this.onTap});
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          showCheckmark: false,
          selectedColor: color.withOpacity(0.18),
          side: BorderSide(color: selected ? color : const Color(0xFFE2E8F0)),
          labelStyle: TextStyle(fontWeight: FontWeight.w600, color: selected ? color : calendarMuted),
          onSelected: (_) => onTap(),
        ),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.hint, this.actionLabel, this.onAction});
  final String title;
  final String hint;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Column(children: [
          const Icon(Icons.event_busy_outlined, size: 48, color: Color(0xFF94A3B8)),
          const SizedBox(height: 10),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(hint, style: const TextStyle(color: calendarMuted)),
          if (actionLabel != null) ...[
            const SizedBox(height: 14),
            FilledButton.tonalIcon(onPressed: onAction, icon: const Icon(Icons.add_rounded), label: Text(actionLabel!)),
          ],
        ]),
      );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_off_rounded, size: 48, color: Color(0xFF94A3B8)),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: calendarMuted)),
          if (onRetry != null) ...[
            const SizedBox(height: 14),
            FilledButton.tonal(onPressed: onRetry, child: const Text('Retry')),
          ],
        ]),
      );
}
