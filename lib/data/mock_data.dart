import '../models/study_models.dart';

class MockData {
  static final courses = <Course>[
    Course(id: 'c1', name: 'Data Structures', code: 'CS 204', professor: 'Dr. Amira Haddad', room: 'B-204', type: CourseType.lecture, day: 'Monday', start: '09:00', end: '10:30', semester: 'Fall 2025', color: 0xFF006D77),
    Course(id: 'c2', name: 'Linear Algebra', code: 'MATH 210', professor: 'Prof. Karim Nassar', room: 'A-112', type: CourseType.td, day: 'Monday', start: '11:00', end: '12:30', semester: 'Fall 2025', color: 0xFF7C6EE6),
    Course(id: 'c3', name: 'Human Computer Interaction', code: 'UX 301', professor: 'Dr. Lina Mansour', room: 'Design Lab', type: CourseType.lecture, day: 'Tuesday', start: '10:00', end: '11:30', semester: 'Fall 2025', color: 0xFFF29B62),
    Course(id: 'c4', name: 'Database Systems', code: 'CS 315', professor: 'Dr. Samir Youssef', room: 'C-310', type: CourseType.tp, day: 'Wednesday', start: '13:00', end: '15:00', semester: 'Fall 2025', color: 0xFF3BAA84),
    Course(id: 'c5', name: 'Software Engineering', code: 'CS 320', professor: 'Prof. Maya Saleh', room: 'B-108', type: CourseType.lecture, day: 'Thursday', start: '09:30', end: '11:00', semester: 'Fall 2025', color: 0xFFE16B88),
  ];
  static final tasks = <StudyTask>[
    StudyTask(id: 't1', title: 'Binary tree implementation', courseId: 'c1', deadline: DateTime.now().add(const Duration(days: 2)), status: TaskStatus.inProgress, priority: Priority.high, progress: 65, reminder: true),
    StudyTask(id: 't2', title: 'Linear algebra problem set', courseId: 'c2', deadline: DateTime.now().add(const Duration(days: 4)), status: TaskStatus.todo, priority: Priority.medium, progress: 0),
    StudyTask(id: 't3', title: 'HCI research summary', courseId: 'c3', deadline: DateTime.now().add(const Duration(days: 1)), status: TaskStatus.todo, priority: Priority.high, progress: 20, reminder: true),
    StudyTask(id: 't4', title: 'ER diagram submission', courseId: 'c4', deadline: DateTime.now().subtract(const Duration(days: 1)), status: TaskStatus.completed, priority: Priority.low, progress: 100),
  ];
  static final notes = <StudyNote>[
    StudyNote(id: 'n1', title: 'Binary search trees', body: 'A binary search tree stores values so that left descendants are smaller and right descendants are larger. Average lookup is O(log n).', courseId: 'c1', updatedAt: DateTime.now().subtract(const Duration(hours: 3))),
    StudyNote(id: 'n2', title: 'Usability heuristics', body: 'Visibility of system status · Match between system and real world · User control and freedom · Consistency and standards.', courseId: 'c3', updatedAt: DateTime.now().subtract(const Duration(days: 1))),
    StudyNote(id: 'n3', title: 'Exam week plan', body: 'Review lecture notes, complete practice questions, and leave time for a final recap.', updatedAt: DateTime.now().subtract(const Duration(days: 3))),
  ];
  static final events = <StudyEvent>[
    StudyEvent(id: 'e1', title: 'HCI project deadline', description: 'Submit prototype and usability report', dateTime: DateTime.now().add(const Duration(days: 1, hours: 4)), type: EventType.deadline, location: 'Online', courseId: 'c3', reminder: true),
    StudyEvent(id: 'e2', title: 'Data Structures midterm', description: 'Trees, graphs, and complexity', dateTime: DateTime.now().add(const Duration(days: 6)), type: EventType.exam, location: 'Hall 2', courseId: 'c1', reminder: true),
    StudyEvent(id: 'e3', title: 'Study group', description: 'Review database normalization', dateTime: DateTime.now().add(const Duration(days: 3)), type: EventType.personal, location: 'Library'),
  ];
  static final notifications = <StudyNotification>[
    StudyNotification(id: 'a1', title: 'Deadline coming up', message: 'HCI project is due tomorrow.', dateTime: DateTime.now().subtract(const Duration(minutes: 25)), category: 'Deadline', eventId: 'e1'),
    StudyNotification(id: 'a2', title: 'New course reminder', message: 'Data Structures starts at 9:00 AM on Monday.', dateTime: DateTime.now().subtract(const Duration(hours: 4)), category: 'Course', read: true),
    StudyNotification(id: 'a3', title: 'Exam in 6 days', message: 'Your Data Structures midterm is coming up.', dateTime: DateTime.now().subtract(const Duration(days: 1)), category: 'Exam', eventId: 'e2'),
    StudyNotification(id: 'a4', title: 'Reminders enabled', message: 'You will be notified before your exams and deadlines.', dateTime: DateTime.now().subtract(const Duration(days: 2)), category: 'System', read: true),
  ];
}
