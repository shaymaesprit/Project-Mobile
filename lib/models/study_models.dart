enum TaskStatus { todo, inProgress, completed }
enum Priority { low, medium, high }
enum CourseType { lecture, td, tp }
enum EventType { exam, deadline, course, personal, other }

class Course {
  Course({required this.id, required this.name, required this.code, required this.professor, required this.room, required this.type, required this.day, required this.start, required this.end, required this.semester, required this.color});
  final String id;
  String name;
  String code;
  String professor;
  String room;
  CourseType type;
  String day;
  String start;
  String end;
  String semester;
  int color;
}

class StudyTask {
  StudyTask({required this.id, required this.title, required this.courseId, required this.deadline, required this.status, required this.priority, required this.progress, this.reminder = false});
  final String id;
  String title;
  String? courseId;
  DateTime deadline;
  TaskStatus status;
  Priority priority;
  int progress;
  bool reminder;
}

class StudyNote {
  StudyNote({required this.id, required this.title, required this.body, this.courseId, required this.updatedAt});
  final String id;
  String title;
  String body;
  String? courseId;
  DateTime updatedAt;
}

class StudyEvent {
  StudyEvent({required this.id, required this.title, required this.description, required this.dateTime, required this.type, this.location = '', this.courseId, this.reminder = false});
  final String id;
  String title;
  String description;
  DateTime dateTime;
  EventType type;
  String location;
  String? courseId;
  bool reminder;
}

class StudyNotification {
  StudyNotification({required this.id, required this.title, required this.message, required this.dateTime, required this.category, this.read = false});
  final String id;
  String title;
  String message;
  DateTime dateTime;
  String category;
  bool read;
}
