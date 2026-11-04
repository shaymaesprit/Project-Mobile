import 'package:flutter_test/flutter_test.dart';
import 'package:studymate/data/models/study_models.dart';

void main() {
  test('parses course schedule fields from the API response', () {
    final course = StudyCourse.fromJson({
      'id': 'course-1',
      'title': 'Biology',
      'code': 'BIO-101',
      'professor': 'Dr Curie',
      'room': 'B12',
      'weekday': 0,
      'start_time': '09:00:00',
      'end_time': '10:30:00',
    });

    expect(course.id, 'course-1');
    expect(course.title, 'Biology');
    expect(course.weekday, 0);
    expect(course.startTime, '09:00:00');
    expect(course.endTime, '10:30:00');
  });

  test('parses an unscheduled course without a schedule', () {
    final course = StudyCourse.fromJson({
      'id': 'course-2',
      'title': 'History',
      'code': null,
      'professor': null,
      'room': null,
      'weekday': null,
      'start_time': null,
      'end_time': null,
    });

    expect(course.weekday, isNull);
    expect(course.startTime, isNull);
    expect(course.endTime, isNull);
  });
}
