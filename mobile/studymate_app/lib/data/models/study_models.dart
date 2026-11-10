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

class StudyFlashcardDeck {
  const StudyFlashcardDeck({
    required this.id,
    required this.title,
    required this.source,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.courseId,
  });

  final String id;
  final String title;
  final String? description;
  final String? courseId;
  final String source;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory StudyFlashcardDeck.fromJson(Map<String, dynamic> json) =>
      StudyFlashcardDeck(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        courseId: json['course_id'] as String?,
        source: json['source'] as String? ?? 'manual',
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
        updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'course_id': courseId,
      };
}

class StudyFlashcard {
  const StudyFlashcard({
    required this.id,
    required this.question,
    required this.answer,
    required this.repetitions,
    required this.intervalDays,
    required this.easeFactor,
    this.deckId,
    this.courseId,
    this.dueAt,
  });

  final String id;
  final String? deckId;
  final String? courseId;
  final String question;
  final String answer;
  final DateTime? dueAt;
  final int repetitions;
  final int intervalDays;
  final double easeFactor;

  factory StudyFlashcard.fromJson(Map<String, dynamic> json) => StudyFlashcard(
        id: json['id'] as String,
        deckId: json['deck_id'] as String?,
        courseId: json['course_id'] as String?,
        question: json['question'] as String,
        answer: json['answer'] as String,
        dueAt: json['due_at'] == null
            ? null
            : DateTime.parse(json['due_at'] as String).toLocal(),
        repetitions: json['repetitions'] as int? ?? 0,
        intervalDays: json['interval_days'] as int? ?? 0,
        easeFactor: _toDouble(json['ease_factor']) ?? 2.5,
      );

  Map<String, dynamic> toJson() => {
        'question': question,
        'answer': answer,
        'deck_id': deckId,
        'course_id': courseId,
      };
}

class StudyFlashcardDeckProgress {
  const StudyFlashcardDeckProgress({
    required this.deckId,
    required this.totalCards,
    required this.reviewedCards,
    required this.masteredCards,
    required this.totalReviews,
    required this.correctAnswers,
    required this.incorrectAnswers,
    this.accuracyRate,
  });

  final String deckId;
  final int totalCards;
  final int reviewedCards;
  final int masteredCards;
  final int totalReviews;
  final int correctAnswers;
  final int incorrectAnswers;
  final double? accuracyRate;

  factory StudyFlashcardDeckProgress.fromJson(Map<String, dynamic> json) =>
      StudyFlashcardDeckProgress(
        deckId: json['deck_id'] as String,
        totalCards: json['total_cards'] as int,
        reviewedCards: json['reviewed_cards'] as int,
        masteredCards: json['mastered_cards'] as int,
        totalReviews: json['total_reviews'] as int,
        correctAnswers: json['correct_answers'] as int,
        incorrectAnswers: json['incorrect_answers'] as int,
        accuracyRate: _toDouble(json['accuracy_rate']),
      );
}

class StudyFlashcardReviewResult {
  const StudyFlashcardReviewResult({
    required this.flashcard,
    required this.totalReviews,
    required this.correctAnswers,
    required this.incorrectAnswers,
    this.accuracyRate,
  });

  final StudyFlashcard flashcard;
  final int totalReviews;
  final int correctAnswers;
  final int incorrectAnswers;
  final double? accuracyRate;

  factory StudyFlashcardReviewResult.fromJson(Map<String, dynamic> json) =>
      StudyFlashcardReviewResult(
        flashcard: StudyFlashcard.fromJson(
          json['flashcard'] as Map<String, dynamic>,
        ),
        totalReviews: json['total_reviews'] as int,
        correctAnswers: json['correct_answers'] as int,
        incorrectAnswers: json['incorrect_answers'] as int,
        accuracyRate: _toDouble(json['accuracy_rate']),
      );
}

class StudyEvaluation {
  const StudyEvaluation({
    required this.id,
    required this.title,
    required this.evaluationType,
    required this.createdAt,
    required this.updatedAt,
    this.courseId,
    this.scheduledAt,
    this.score,
    this.maxScore,
    this.notes,
  });

  final String id;
  final String title;
  final String evaluationType;
  final String? courseId;
  final DateTime? scheduledAt;
  final double? score;
  final double? maxScore;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  double? get percentage =>
      score == null || maxScore == null ? null : score! / maxScore! * 100;

  factory StudyEvaluation.fromJson(Map<String, dynamic> json) =>
      StudyEvaluation(
        id: json['id'] as String,
        title: json['title'] as String,
        evaluationType: json['evaluation_type'] as String? ?? 'other',
        courseId: json['course_id'] as String?,
        scheduledAt: json['scheduled_at'] == null
            ? null
            : DateTime.parse(json['scheduled_at'] as String).toLocal(),
        score: _toDouble(json['score']),
        maxScore: _toDouble(json['max_score']),
        notes: json['notes'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
        updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'evaluation_type': evaluationType,
        'course_id': courseId,
        'scheduled_at': scheduledAt?.toUtc().toIso8601String(),
        'score': score,
        'max_score': maxScore,
        'notes': notes,
      };
}

class StudyEvaluationTrendPoint {
  const StudyEvaluationTrendPoint({
    required this.title,
    required this.date,
    required this.score,
    required this.maxScore,
    required this.percentage,
  });

  final String title;
  final DateTime date;
  final double score;
  final double maxScore;
  final double percentage;

  factory StudyEvaluationTrendPoint.fromJson(Map<String, dynamic> json) =>
      StudyEvaluationTrendPoint(
        title: json['title'] as String,
        date: DateTime.parse(json['date'] as String).toLocal(),
        score: (_toDouble(json['score']) ?? 0),
        maxScore: (_toDouble(json['max_score']) ?? 0),
        percentage: (_toDouble(json['percentage']) ?? 0),
      );
}

class StudyCourseEvaluationAverage {
  const StudyCourseEvaluationAverage({
    required this.averagePercentage,
    required this.evaluationCount,
    this.courseId,
  });

  final String? courseId;
  final double averagePercentage;
  final int evaluationCount;

  factory StudyCourseEvaluationAverage.fromJson(Map<String, dynamic> json) =>
      StudyCourseEvaluationAverage(
        courseId: json['course_id'] as String?,
        averagePercentage: (_toDouble(json['average_percentage']) ?? 0),
        evaluationCount: json['evaluation_count'] as int,
      );
}

class StudyEvaluationSummary {
  const StudyEvaluationSummary({
    required this.gradedCount,
    required this.courseAverages,
    required this.trend,
    this.averagePercentage,
  });

  final int gradedCount;
  final double? averagePercentage;
  final List<StudyCourseEvaluationAverage> courseAverages;
  final List<StudyEvaluationTrendPoint> trend;

  factory StudyEvaluationSummary.fromJson(Map<String, dynamic> json) =>
      StudyEvaluationSummary(
        gradedCount: json['graded_count'] as int,
        averagePercentage: _toDouble(json['average_percentage']),
        courseAverages: (json['course_averages'] as List<dynamic>)
            .map(
              (item) => StudyCourseEvaluationAverage.fromJson(
                item as Map<String, dynamic>,
              ),
            )
            .toList(growable: false),
        trend: (json['trend'] as List<dynamic>)
            .map(
              (item) => StudyEvaluationTrendPoint.fromJson(
                item as Map<String, dynamic>,
              ),
            )
            .toList(growable: false),
      );
}

/// Résultat d'une génération de flashcards par l'IA.
class StudyFlashcardGeneration {
  const StudyFlashcardGeneration({required this.source, required this.cards});

  /// `ai` si le modèle a produit les cartes, `rules` si le backend a dû
  /// se rabattre sur l'extraction automatique (IA indisponible).
  final String source;
  final List<StudyFlashcard> cards;

  bool get usedAi => source == 'ai';
}


/// Les champs `Decimal` du backend arrivent en texte (« 2.50 ») : on accepte
/// un nombre ou une chaîne.
double? _toDouble(Object? value) => switch (value) {
      num() => value.toDouble(),
      String() => double.tryParse(value),
      _ => null,
    };
