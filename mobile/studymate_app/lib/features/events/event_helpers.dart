import 'package:flutter/material.dart';

const _weekdayNames = [
  'Lundi',
  'Mardi',
  'Mercredi',
  'Jeudi',
  'Vendredi',
  'Samedi',
  'Dimanche',
];
const _monthNames = [
  'janvier',
  'février',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'août',
  'septembre',
  'octobre',
  'novembre',
  'décembre',
];

String weekdayName(DateTime day) => _weekdayNames[day.weekday - 1];
String monthName(DateTime day) => _monthNames[day.month - 1];

String two(int value) => value.toString().padLeft(2, '0');
String formatTime(DateTime value) => '${two(value.hour)}:${two(value.minute)}';
String formatDate(DateTime value) =>
    '${weekdayName(value)} ${value.day} ${monthName(value)}';
String formatDateTime(DateTime value) =>
    '${formatDate(value)} · ${formatTime(value)}';

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

DateTime startOfDay(DateTime value) =>
    DateTime(value.year, value.month, value.day);

/// Lundi de la semaine de [value] (heure locale, minuit).
DateTime startOfWeek(DateTime value) {
  final day = startOfDay(value);
  return day.subtract(Duration(days: day.weekday - 1));
}

/// Couleur associée à une catégorie d'événement.
Color categoryColor(String category) => switch (category) {
      'exam' => const Color(0xFFD64545),
      'deadline' => const Color(0xFFE08A1E),
      'class' => const Color(0xFF3D7BD9),
      'study' => const Color(0xFF7A5BD6),
      'personal' => const Color(0xFF2E9E6B),
      _ => const Color(0xFF7C8794),
    };

IconData categoryIcon(String category) => switch (category) {
      'exam' => Icons.assignment_outlined,
      'deadline' => Icons.flag_outlined,
      'class' => Icons.school_outlined,
      'study' => Icons.menu_book_outlined,
      'personal' => Icons.person_outline,
      _ => Icons.event_outlined,
    };

IconData notificationIcon(String type) => switch (type) {
      'exam' => Icons.assignment_outlined,
      'deadline' => Icons.flag_outlined,
      'reminder' => Icons.alarm_outlined,
      _ => Icons.notifications_outlined,
    };

String relativeTime(DateTime value) {
  final diff = DateTime.now().difference(value);
  if (diff.inMinutes < 1) return 'À l’instant';
  if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'Il y a ${diff.inHours} h';
  if (diff.inDays < 7) return 'Il y a ${diff.inDays} j';
  return '${value.day}/${value.month}/${value.year}';
}


/// Bandeau « Hors ligne – données enregistrées le … » affiché quand l'API est
/// injoignable et que l'écran montre les données SQLite.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, required this.lastSyncedAt});

  final DateTime? lastSyncedAt;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final saved = lastSyncedAt;
    final text = saved == null
        ? 'Hors ligne – aucune donnée enregistrée'
        : 'Hors ligne – données enregistrées le '
            '${two(saved.day)}/${two(saved.month)}/${saved.year} '
            'à ${formatTime(saved)}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Material(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.cloud_off_outlined,
                  size: 18, color: scheme.onTertiaryContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    color: scheme.onTertiaryContainer,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
