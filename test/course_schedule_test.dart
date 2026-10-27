import 'package:flutter_test/flutter_test.dart';
import 'package:studymate/domain/course_schedule.dart';
import 'package:studymate/models/study_models.dart';

Course _course({
  String id = 'course-1',
  String day = 'Monday',
  String start = '09:00',
  String end = '10:00',
}) =>
    Course(
      id: id,
      name: 'Algorithms',
      code: 'CS101',
      professor: 'Prof. Test',
      room: 'A1',
      type: CourseType.lecture,
      day: day,
      start: start,
      end: end,
      semester: 'Fall 2026',
      color: 0xFF006D77,
    );

void main() {
  group('findCourseConflict', () {
    final courses = [_course()];

    test('detects overlapping course intervals', () {
      expect(
        findCourseConflict(courses,
            day: 'Monday', start: '09:30', end: '10:30')?.course.id,
        'course-1',
      );
    });

    test('allows courses that only touch at an endpoint', () {
      expect(
        findCourseConflict(courses,
            day: 'Monday', start: '10:00', end: '11:00'),
        isNull,
      );
    });

    test('ignores a course on a different day', () {
      expect(
        findCourseConflict(courses,
            day: 'Tuesday', start: '09:00', end: '10:00'),
        isNull,
      );
    });

    test('excludes the course being edited', () {
      expect(
        findCourseConflict(courses,
            day: 'Monday',
            start: '09:00',
            end: '10:00',
            excludingId: 'course-1'),
        isNull,
      );
    });

    test('rejects invalid and reversed time ranges', () {
      expect(
        () => findCourseConflict(courses,
            day: 'Monday', start: '9:00', end: '10:00'),
        throwsFormatException,
      );
      expect(
        () => findCourseConflict(courses,
            day: 'Monday', start: '10:00', end: '09:00'),
        throwsFormatException,
      );
    });
  });

  test('finds gaps between classes in a requested study window', () {
    final courses = [
      _course(start: '09:00', end: '10:00'),
      _course(id: 'course-2', start: '11:00', end: '12:30'),
    ];

    expect(
      findFreeStudySlots(courses,
          day: 'Monday',
          start: '08:00',
          end: '13:00',
          minimumDurationMinutes: 45)
          .map((slot) => '${slot.start}-${slot.end}')
          .toList(),
      ['08:00-09:00', '10:00-11:00', '12:30-13:00'],
    );
  });
}
