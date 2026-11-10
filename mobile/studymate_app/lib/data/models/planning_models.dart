// Modèles : agenda hebdomadaire, planificateur de tâches, partage par QR
// code et enrichissement Wikipédia.

DateTime _date(Object? value) => DateTime.parse(value as String).toLocal();

DateTime? _dateOrNull(Object? value) => value is String && value.isNotEmpty
    ? DateTime.parse(value).toLocal()
    : null;

/// Date « calendrier » (YYYY-MM-DD) sans décalage de fuseau.
DateTime _day(Object? value) {
  final parts = (value as String).split('-').map(int.parse).toList();
  return DateTime(parts[0], parts[1], parts[2]);
}

List<Map<String, dynamic>> _list(Object? value) => [
      for (final item in (value as List<dynamic>? ?? const []))
        Map<String, dynamic>.from(item as Map),
    ];

class Holiday {
  const Holiday(
      {required this.date, required this.name, required this.localName});

  final DateTime date;
  final String name;
  final String localName;

  /// Le nom local (souvent en arabe) n'est pas toujours lisible : on préfère
  /// le nom anglais/français si disponible.
  String get label => name.isNotEmpty ? name : localName;

  factory Holiday.fromJson(Map<String, dynamic> json) => Holiday(
        date: _day(json['date']),
        name: json['name'] as String? ?? '',
        localName: json['local_name'] as String? ?? '',
      );
}

class AgendaItem {
  const AgendaItem({
    required this.kind,
    required this.id,
    required this.title,
    required this.startsAt,
    required this.endsAt,
    this.room,
  });

  final String kind; // course | event
  final String id;
  final String title;
  final DateTime startsAt;
  final DateTime endsAt;
  final String? room;

  bool get isCourse => kind == 'course';

  factory AgendaItem.fromJson(Map<String, dynamic> json) => AgendaItem(
        kind: json['kind'] as String,
        id: json['id'] as String,
        title: json['title'] as String,
        startsAt: _date(json['starts_at']),
        endsAt: _date(json['ends_at']),
        room: json['room'] as String?,
      );
}

class TimeWindow {
  const TimeWindow(
      {required this.startsAt, required this.endsAt, required this.minutes});

  final DateTime startsAt;
  final DateTime endsAt;
  final int minutes;

  factory TimeWindow.fromJson(Map<String, dynamic> json) => TimeWindow(
        startsAt: _date(json['starts_at']),
        endsAt: _date(json['ends_at']),
        minutes: (json['minutes'] as num).toInt(),
      );
}

class AgendaDay {
  const AgendaDay({
    required this.date,
    required this.holiday,
    required this.items,
    required this.cancelled,
    required this.freeSlots,
    required this.conflicts,
  });

  final DateTime date;
  final Holiday? holiday;
  final List<AgendaItem> items;
  final List<AgendaItem> cancelled;
  final List<TimeWindow> freeSlots;
  final List<List<AgendaItem>> conflicts;

  factory AgendaDay.fromJson(Map<String, dynamic> json) => AgendaDay(
        date: _day(json['date']),
        holiday: json['holiday'] is Map
            ? Holiday.fromJson(
                Map<String, dynamic>.from(json['holiday'] as Map))
            : null,
        items: _list(json['items']).map(AgendaItem.fromJson).toList(),
        cancelled: _list(json['cancelled']).map(AgendaItem.fromJson).toList(),
        freeSlots: _list(json['free_slots']).map(TimeWindow.fromJson).toList(),
        conflicts: [
          for (final pair in (json['conflicts'] as List<dynamic>? ?? const []))
            _list(pair).map(AgendaItem.fromJson).toList(),
        ],
      );
}

class CourseHours {
  const CourseHours(
      {required this.courseId, required this.title, required this.hours});

  final String courseId;
  final String title;
  final double hours;

  factory CourseHours.fromJson(Map<String, dynamic> json) => CourseHours(
        courseId: json['course_id'] as String,
        title: json['title'] as String,
        hours: (json['hours'] as num).toDouble(),
      );
}

class WeekAgenda {
  const WeekAgenda({
    required this.weekStart,
    required this.days,
    required this.courseHours,
    required this.freeHours,
    required this.byCourse,
  });

  final DateTime weekStart;
  final List<AgendaDay> days;
  final double courseHours;
  final double freeHours;
  final List<CourseHours> byCourse;

  int get conflictCount =>
      days.fold(0, (sum, day) => sum + day.conflicts.length);
  List<Holiday> get holidays => [
        for (final day in days)
          if (day.holiday != null) day.holiday!,
      ];

  factory WeekAgenda.fromJson(Map<String, dynamic> json) {
    final stats = Map<String, dynamic>.from(json['stats'] as Map);
    return WeekAgenda(
      weekStart: _day(json['week_start']),
      days: _list(json['days']).map(AgendaDay.fromJson).toList(),
      courseHours: (stats['course_hours'] as num).toDouble(),
      freeHours: (stats['free_hours'] as num).toDouble(),
      byCourse: _list(stats['by_course']).map(CourseHours.fromJson).toList(),
    );
  }
}

class PlannedTask {
  const PlannedTask({
    required this.taskId,
    required this.title,
    required this.priority,
    required this.deadline,
    required this.score,
    required this.reasons,
    required this.estimatedMinutes,
    required this.plannedMinutes,
    required this.status,
    required this.sessions,
  });

  final String taskId;
  final String title;
  final String priority;
  final DateTime? deadline;
  final double score;
  final List<String> reasons;
  final int estimatedMinutes;
  final int plannedMinutes;
  final String status; // planned | partial | unplanned | overdue
  final List<TimeWindow> sessions;

  factory PlannedTask.fromJson(Map<String, dynamic> json) => PlannedTask(
        taskId: json['task_id'] as String,
        title: json['title'] as String,
        priority: json['priority'] as String? ?? 'medium',
        deadline: _dateOrNull(json['deadline']),
        score: (json['score'] as num).toDouble(),
        reasons: [
          for (final r in (json['reasons'] as List<dynamic>? ?? const [])) '$r'
        ],
        estimatedMinutes: (json['estimated_minutes'] as num).toInt(),
        plannedMinutes: (json['planned_minutes'] as num).toInt(),
        status: json['status'] as String,
        sessions: _list(json['sessions']).map(TimeWindow.fromJson).toList(),
      );
}

class TaskPlan {
  const TaskPlan({
    required this.generatedAt,
    required this.days,
    required this.holidays,
    required this.freeMinutes,
    required this.items,
  });

  final DateTime generatedAt;
  final int days;
  final List<Holiday> holidays;
  final int freeMinutes;
  final List<PlannedTask> items;

  factory TaskPlan.fromJson(Map<String, dynamic> json) => TaskPlan(
        generatedAt: _date(json['generated_at']),
        days: (json['days'] as num).toInt(),
        holidays: _list(json['holidays']).map(Holiday.fromJson).toList(),
        freeMinutes: (json['free_minutes'] as num).toInt(),
        items: _list(json['items']).map(PlannedTask.fromJson).toList(),
      );
}

class TaskBreakdownStep {
  const TaskBreakdownStep({required this.title, required this.minutes});

  final String title;
  final int minutes;

  factory TaskBreakdownStep.fromJson(Map<String, dynamic> json) =>
      TaskBreakdownStep(
        title: json['title'] as String,
        minutes: (json['minutes'] as num).toInt(),
      );
}

class TimetableShare {
  const TimetableShare({
    required this.id,
    required this.qrUrl,
    required this.link,
    required this.expiresAt,
  });

  final String id;
  final String? qrUrl;
  final String link;
  final DateTime expiresAt;

  factory TimetableShare.fromJson(Map<String, dynamic> json) => TimetableShare(
        id: json['id'] as String,
        qrUrl: json['qr_url'] as String?,
        link: json['link'] as String,
        expiresAt: _date(json['expires_at']),
      );
}

class WikipediaResult {
  const WikipediaResult({
    required this.title,
    required this.extract,
    required this.url,
    this.description,
    this.thumbnail,
  });

  final String title;
  final String? description;
  final String extract;
  final String url;
  final String? thumbnail;

  factory WikipediaResult.fromJson(Map<String, dynamic> json) =>
      WikipediaResult(
        title: json['title'] as String,
        description: json['description'] as String?,
        extract: json['extract'] as String,
        url: json['url'] as String,
        thumbnail: json['thumbnail'] as String?,
      );
}
