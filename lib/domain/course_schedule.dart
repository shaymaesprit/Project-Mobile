import '../models/study_models.dart';

class CourseTime {
  const CourseTime(this.hour, this.minute);

  final int hour;
  final int minute;

  int get minutesSinceMidnight => hour * 60 + minute;

  static CourseTime parse(String value) {
    final match = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$').firstMatch(value);
    if (match == null) {
      throw FormatException('Time must use HH:mm format.', value);
    }
    return CourseTime(int.parse(match[1]!), int.parse(match[2]!));
  }
}

class CourseConflict {
  const CourseConflict(this.course);

  final Course course;
}

CourseConflict? findCourseConflict(
  Iterable<Course> courses, {
  required String day,
  required String start,
  required String end,
  String? excludingId,
}) {
  final startMinutes = CourseTime.parse(start).minutesSinceMidnight;
  final endMinutes = CourseTime.parse(end).minutesSinceMidnight;
  if (startMinutes >= endMinutes) {
    throw const FormatException('End time must be later than start time.');
  }

  for (final course in courses) {
    if (course.id == excludingId || course.day != day) continue;
    final existingStart = CourseTime.parse(course.start).minutesSinceMidnight;
    final existingEnd = CourseTime.parse(course.end).minutesSinceMidnight;
    if (startMinutes < existingEnd && existingStart < endMinutes) {
      return CourseConflict(course);
    }
  }
  return null;
}

class StudySlot {
  const StudySlot({required this.day, required this.start, required this.end});

  final String day;
  final String start;
  final String end;
}

List<StudySlot> findFreeStudySlots(
  Iterable<Course> courses, {
  required String day,
  required String start,
  required String end,
  int minimumDurationMinutes = 30,
}) {
  final dayStart = CourseTime.parse(start).minutesSinceMidnight;
  final dayEnd = CourseTime.parse(end).minutesSinceMidnight;
  if (dayStart >= dayEnd || minimumDurationMinutes <= 0) {
    throw const FormatException('Invalid study slot boundaries.');
  }

  final occupied = courses
      .where((course) => course.day == day)
      .map((course) => (
            CourseTime.parse(course.start).minutesSinceMidnight,
            CourseTime.parse(course.end).minutesSinceMidnight,
          ))
      .toList()
    ..sort((a, b) => a.$1.compareTo(b.$1));

  final result = <StudySlot>[];
  var cursor = dayStart;
  for (final (courseStart, courseEnd) in occupied) {
    final boundedStart = courseStart.clamp(dayStart, dayEnd);
    final boundedEnd = courseEnd.clamp(dayStart, dayEnd);
    if (boundedStart - cursor >= minimumDurationMinutes) {
      result.add(StudySlot(
        day: day,
        start: _formatMinutes(cursor),
        end: _formatMinutes(boundedStart),
      ));
    }
    if (boundedEnd > cursor) cursor = boundedEnd;
    if (cursor >= dayEnd) break;
  }
  if (dayEnd - cursor >= minimumDurationMinutes) {
    result.add(StudySlot(
      day: day,
      start: _formatMinutes(cursor),
      end: _formatMinutes(dayEnd),
    ));
  }
  return result;
}

String _formatMinutes(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
