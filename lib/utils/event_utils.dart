import 'package:flutter/material.dart';
import '../models/study_models.dart';

const Color calendarPrimary = Color(0xFF006D77);
const Color calendarMuted = Color(0xFF64748B);
const Color calendarDanger = Color(0xFFEF4444);

const _months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
const _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

String monthName(int month) => _months[month - 1];
String monthShort(int month) => _months[month - 1].substring(0, 3);
String weekdayName(int weekday) => _weekdays[weekday - 1];
String weekdayShort(int weekday) => _weekdays[weekday - 1].substring(0, 3);

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
bool isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
DateTime startOfWeek(DateTime d) => DateTime(d.year, d.month, d.day - (d.weekday - 1));

String formatTime(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
String formatDate(DateTime d) => '${weekdayShort(d.weekday)}, ${d.day} ${monthShort(d.month)} ${d.year}';

String formatRelative(DateTime t, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(t);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inDays < 7) return '${diff.inDays} days ago';
  return '${t.day} ${monthShort(t.month)} ${t.year}';
}

String eventTimeRange(StudyEvent e) {
  final end = e.endDateTime;
  return end == null ? formatTime(e.dateTime) : '${formatTime(e.dateTime)} – ${formatTime(end)}';
}

extension EventTypeUi on EventType {
  String get label => switch (this) {
        EventType.exam => 'Exam',
        EventType.deadline => 'Deadline',
        EventType.course => 'Course',
        EventType.personal => 'Personal',
        EventType.other => 'Other',
      };

  String get pluralLabel => switch (this) {
        EventType.exam => 'Exams',
        EventType.deadline => 'Deadlines',
        EventType.course => 'Courses',
        EventType.personal => 'Personal',
        EventType.other => 'Other',
      };

  // Same palette as the original calendar list, so the visual identity is unchanged.
  Color get color => switch (this) {
        EventType.exam => const Color(0xFFEF4444),
        EventType.deadline => const Color(0xFFF59E0B),
        EventType.course => const Color(0xFF006D77),
        EventType.personal => const Color(0xFF10B981),
        EventType.other => const Color(0xFF83C5BE),
      };

  IconData get icon => switch (this) {
        EventType.exam => Icons.school_outlined,
        EventType.deadline => Icons.flag_outlined,
        EventType.course => Icons.menu_book_outlined,
        EventType.personal => Icons.person_outline_rounded,
        EventType.other => Icons.event_outlined,
      };
}

extension EventStatusUi on EventStatus {
  String get label => switch (this) {
        EventStatus.planned => 'Planned',
        EventStatus.done => 'Done',
        EventStatus.cancelled => 'Cancelled',
      };

  Color get color => switch (this) {
        EventStatus.planned => calendarPrimary,
        EventStatus.done => const Color(0xFF10B981),
        EventStatus.cancelled => const Color(0xFF94A3B8),
      };
}

class ReminderPreset {
  const ReminderPreset(this.label, this.before);
  final String label;
  final Duration before;
}

const reminderPresets = <ReminderPreset>[
  ReminderPreset('1 day before', Duration(days: 1)),
  ReminderPreset('12 hours before', Duration(hours: 12)),
  ReminderPreset('2 hours before', Duration(hours: 2)),
  ReminderPreset('30 minutes before', Duration(minutes: 30)),
];

String reminderLabel(StudyEvent e) {
  if (!e.reminder) return 'No reminder';
  final at = e.reminderAt;
  if (at == null) return 'Reminder on';
  final diff = e.dateTime.difference(at);
  for (final preset in reminderPresets) {
    if (preset.before == diff) return preset.label;
  }
  return 'Custom reminder';
}

List<StudyEvent> eventsForDay(List<StudyEvent> events, DateTime day, {EventType? type}) {
  return events.where((e) => isSameDay(e.dateTime, day) && (type == null || e.type == type)).toList()
    ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
}

/// Returns a user-facing error message, or null when the dates are consistent.
String? validateEventTimes({required DateTime start, DateTime? end, required bool reminderEnabled, DateTime? reminderAt, DateTime? now}) {
  final clock = now ?? DateTime.now();
  if (end != null && !end.isAfter(start)) return 'The end time must be after the start time.';
  if (reminderEnabled) {
    if (reminderAt == null) return 'Choose when you want to be reminded.';
    if (!reminderAt.isBefore(start)) return 'The reminder must be set before the event starts.';
    if (start.isAfter(clock) && reminderAt.isBefore(clock)) return 'This reminder time has already passed. Pick a later one.';
  }
  return null;
}

class NotificationStyle {
  const NotificationStyle(this.color, this.icon);
  final Color color;
  final IconData icon;
}

/// Maps the free-text notification category to a colour and icon (English or French labels).
NotificationStyle notificationStyle(String category) {
  final c = category.toLowerCase();
  if (c.contains('exam')) return const NotificationStyle(Color(0xFFEF4444), Icons.school_outlined);
  if (c.contains('deadline')) return const NotificationStyle(Color(0xFFF59E0B), Icons.flag_outlined);
  if (c.contains('remind') || c.contains('rappel')) return const NotificationStyle(calendarPrimary, Icons.alarm_rounded);
  if (c.contains('system') || c.contains('système')) return const NotificationStyle(Color(0xFF64748B), Icons.info_outline_rounded);
  return const NotificationStyle(calendarPrimary, Icons.notifications_active_outlined);
}
