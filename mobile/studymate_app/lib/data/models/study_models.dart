class StudyMateUserProfile {
  const StudyMateUserProfile({
    required this.firebaseUid,
    required this.createdAt,
    required this.updatedAt,
    this.email,
    this.displayName,
    this.photoUrl,
    this.locale,
    this.timezone,
  });

  final String firebaseUid;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final String? locale;
  final String? timezone;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory StudyMateUserProfile.fromJson(Map<String, dynamic> json) =>
      StudyMateUserProfile(
        firebaseUid: json['firebase_uid'] as String,
        email: json['email'] as String?,
        displayName: json['display_name'] as String?,
        photoUrl: json['photo_url'] as String?,
        locale: json['locale'] as String?,
        timezone: json['timezone'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );
}

class StudentProfile {
  const StudentProfile({
    required this.dailyStudyGoalMinutes,
    required this.academicGoals,
    required this.preferences,
    this.studyLevel,
    this.specialty,
    this.preferredLearningStyle,
  });

  final String? studyLevel;
  final String? specialty;
  final List<String> academicGoals;
  final String? preferredLearningStyle;
  final int dailyStudyGoalMinutes;
  final Map<String, dynamic> preferences;

  factory StudentProfile.fromJson(Map<String, dynamic> json) => StudentProfile(
        studyLevel: json['study_level'] as String?,
        specialty: json['specialty'] as String?,
        academicGoals: (json['academic_goals'] as List<dynamic>)
            .map((goal) => goal as String)
            .toList(growable: false),
        preferredLearningStyle: json['preferred_learning_style'] as String?,
        dailyStudyGoalMinutes: json['daily_study_goal_minutes'] as int,
        preferences: Map<String, dynamic>.from(
          json['preferences'] as Map<String, dynamic>,
        ),
      );
}

class StudyCourse {
  const StudyCourse({
    required this.id,
    required this.title,
    this.code,
    this.professor,
    this.room,
    this.weekday,
    this.startTime,
    this.endTime,
  });

  final String id;
  final String title;
  final String? code;
  final String? professor;
  final String? room;
  final int? weekday;
  final String? startTime;
  final String? endTime;

  factory StudyCourse.fromJson(Map<String, dynamic> json) => StudyCourse(
        id: json['id'] as String,
        title: json['title'] as String,
        code: json['code'] as String?,
        professor: json['professor'] as String?,
        room: json['room'] as String?,
        weekday: json['weekday'] as int?,
        startTime: json['start_time'] as String?,
        endTime: json['end_time'] as String?,
      );
}

class StudyTask {
  const StudyTask({
    required this.id,
    required this.title,
    this.description,
    this.priority = 'medium',
    this.deadline,
    this.courseId,
    this.isCompleted = false,
  });

  final String id;
  final String title;
  final String? description;
  final String priority;
  final DateTime? deadline;
  final String? courseId;
  final bool isCompleted;

  factory StudyTask.fromJson(Map<String, dynamic> json) => StudyTask(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        priority: json['priority'] as String? ?? 'medium',
        deadline: json['deadline'] == null
            ? null
            : DateTime.parse(json['deadline'] as String).toLocal(),
        courseId: json['course_id'] as String?,
        isCompleted: json['is_completed'] as bool? ?? false,
      );

  StudyTask copyWith({bool? isCompleted}) => StudyTask(
        id: id,
        title: title,
        description: description,
        priority: priority,
        deadline: deadline,
        courseId: courseId,
        isCompleted: isCompleted ?? this.isCompleted,
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'priority': priority,
        'deadline': deadline?.toUtc().toIso8601String(),
        'course_id': courseId,
      };
}

class StudyNote {
  const StudyNote({
    required this.id,
    required this.title,
    required this.content,
    this.courseId,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String content;
  final String? courseId;
  final DateTime? updatedAt;

  factory StudyNote.fromJson(Map<String, dynamic> json) => StudyNote(
        id: json['id'] as String,
        title: json['title'] as String,
        content: json['content'] as String? ?? '',
        courseId: json['course_id'] as String?,
        updatedAt: json['updated_at'] == null
            ? null
            : DateTime.parse(json['updated_at'] as String).toLocal(),
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'content': content,
        'course_id': courseId,
      };
}
