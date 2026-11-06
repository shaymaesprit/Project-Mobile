import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../data/models/study_models.dart';
import '../data/services/studymate_api.dart';

class StudyController extends ChangeNotifier {
  StudyController({
    required StudyMateApi api,
  }) : _api = api;

  final StudyMateApi _api;

  List<StudyCourse> _courses = const [];
  List<StudyCourse> _weeklySchedule = const [];
  List<StudyTask> _tasks = const [];
  List<StudyNote> _notes = const [];
  List<StudyFlashcardDeck> _flashcardDecks = const [];
  List<StudyEvaluation> _evaluations = const [];

  bool _hasBackendSession = false;
  bool _isLoading = false;
  bool _isProfileLoading = false;
  String? _errorMessage;
  String? _profileErrorMessage;
  StudyMateUserProfile? _userProfile;
  StudentProfile? _studentProfile;
  StudyEvaluationSummary? _evaluationSummary;
  DateTime? _lastSyncedAt;

  List<StudyCourse> get courses => List.unmodifiable(_courses);
  List<StudyCourse> get weeklySchedule => List.unmodifiable(_weeklySchedule);
  List<StudyTask> get tasks => List.unmodifiable(_tasks);
  List<StudyNote> get notes => List.unmodifiable(_notes);
  List<StudyFlashcardDeck> get flashcardDecks =>
      List.unmodifiable(_flashcardDecks);
  List<StudyEvaluation> get evaluations => List.unmodifiable(_evaluations);
  StudyEvaluationSummary? get evaluationSummary => _evaluationSummary;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get profileErrorMessage => _profileErrorMessage;
  StudyMateUserProfile? get userProfile => _userProfile;
  StudentProfile? get studentProfile => _studentProfile;
  bool get isProfileLoading => _isProfileLoading;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  int get completedTaskCount => _tasks.where((task) => task.isCompleted).length;

  Future<void> refreshProfile() async {
    _isProfileLoading = true;
    _profileErrorMessage = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _api.getCurrentUser(),
        _api.getStudentProfile(),
      ]);
      _userProfile = results[0] as StudyMateUserProfile;
      _studentProfile = results[1] as StudentProfile;
    } on StudyMateApiException catch (error) {
      _profileErrorMessage = error.message;
    } finally {
      _isProfileLoading = false;
      notifyListeners();
    }
  }

  Future<void> saveStudentProfile({
    required User firebaseUser,
    required String displayName,
    required String? photoUrl,
    required String? locale,
    required String? timezone,
    required String? studyLevel,
    required String? specialty,
    required List<String> academicGoals,
    required String? preferredLearningStyle,
    required int dailyStudyGoalMinutes,
    required Map<String, dynamic> preferences,
  }) async {
    _isProfileLoading = true;
    _profileErrorMessage = null;
    notifyListeners();
    try {
      _studentProfile = await _api.updateStudentProfile(
        studyLevel: studyLevel,
        specialty: specialty,
        academicGoals: academicGoals,
        preferredLearningStyle: preferredLearningStyle,
        dailyStudyGoalMinutes: dailyStudyGoalMinutes,
        preferences: preferences,
      );
      _userProfile = await _api.updateCurrentUser(
        displayName: displayName,
        photoUrl: photoUrl,
        locale: locale,
        timezone: timezone,
      );
      await firebaseUser.updateDisplayName(displayName);
      await firebaseUser.updatePhotoURL(photoUrl);
      _errorMessage = null;
      _clearError();
    } on StudyMateApiException catch (error) {
      _profileErrorMessage = error.message;
      rethrow;
    } finally {
      _isProfileLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadForUser(User? user) async {
    if (user == null) {
      _clearAccountData();
      return;
    }

    _hasBackendSession = true;
    _isLoading = true;
    _errorMessage = null;
    _isProfileLoading = true;
    _profileErrorMessage = null;
    _userProfile = null;
    _studentProfile = null;
    _courses = const [];
    _weeklySchedule = const [];
    _tasks = const [];
    _notes = const [];
    _flashcardDecks = const [];
    _evaluations = const [];
    _evaluationSummary = null;
    notifyListeners();

    try {
      await _api.checkHealth();
      _userProfile = await _api.getCurrentUser();
      final results = await Future.wait([
        _api.getCourses(),
        _api.getWeeklySchedule(),
        _api.getTasks(),
        _api.getNotes(),
        _api.getStudentProfile(),
        _api.getFlashcardDecks(),
        _api.getEvaluations(),
        _api.getEvaluationSummary(),
      ]);
      _courses = results[0] as List<StudyCourse>;
      _weeklySchedule = results[1] as List<StudyCourse>;
      _tasks = results[2] as List<StudyTask>;
      _notes = results[3] as List<StudyNote>;
      _studentProfile = results[4] as StudentProfile;
      _flashcardDecks = results[5] as List<StudyFlashcardDeck>;
      _evaluations = results[6] as List<StudyEvaluation>;
      _evaluationSummary = results[7] as StudyEvaluationSummary;
      _lastSyncedAt = DateTime.now();
    } on StudyMateApiException catch (error) {
      _errorMessage = error.message;
      _profileErrorMessage = error.message;
    } finally {
      _isLoading = false;
      _isProfileLoading = false;
      notifyListeners();
    }
  }

  Future<void> addTask(String title) async {
    _requireBackendSession();
    final task = StudyTask(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      description: 'À faire aujourd’hui',
    );
    try {
      final saved = await _api.createTask(task);
      _tasks = [saved, ..._tasks];
      _clearError();
    } on StudyMateApiException catch (error) {
      _setError(error);
      rethrow;
    }
    notifyListeners();
  }

  Future<void> toggleTask(StudyTask task, bool isCompleted) async {
    _requireBackendSession();
    final index = _tasks.indexWhere((item) => item.id == task.id);
    if (index < 0) return;
    final previous = _tasks[index];
    _replaceTask(index, previous.copyWith(isCompleted: isCompleted));

    try {
      final saved = await _api.updateTask(_tasks[index]);
      _replaceTask(index, saved);
      _clearError();
    } on StudyMateApiException catch (error) {
      _replaceTask(index, previous);
      _setError(error);
      rethrow;
    }
  }

  Future<void> addCourse({
    required String title,
    String? code,
    String? professor,
    String? room,
    int? weekday,
    String? startTime,
    String? endTime,
  }) async {
    _requireBackendSession();
    try {
      final course = await _api.createCourse(
        title: title,
        code: code,
        professor: professor,
        room: room,
        weekday: weekday,
        startTime: startTime,
        endTime: endTime,
      );
      _courses = [course, ..._courses];
      await _refreshWeeklySchedule();
      _clearError();
    } on StudyMateApiException catch (error) {
      _setError(error);
      rethrow;
    }
    notifyListeners();
  }

  Future<void> updateCourse({
    required StudyCourse course,
    required String title,
    String? code,
    String? professor,
    String? room,
    int? weekday,
    String? startTime,
    String? endTime,
  }) async {
    _requireBackendSession();
    try {
      final saved = await _api.updateCourse(
        course: course,
        title: title,
        code: code,
        professor: professor,
        room: room,
        weekday: weekday,
        startTime: startTime,
        endTime: endTime,
      );
      _courses = [
        for (final item in _courses)
          if (item.id == saved.id) saved else item,
      ];
      await _refreshWeeklySchedule();
      _clearError();
    } on StudyMateApiException catch (error) {
      _setError(error);
      rethrow;
    }
    notifyListeners();
  }

  Future<void> deleteCourse(StudyCourse course) async {
    _requireBackendSession();
    try {
      await _api.deleteCourse(course.id);
      _courses = _courses.where((item) => item.id != course.id).toList();
      _weeklySchedule =
          _weeklySchedule.where((item) => item.id != course.id).toList();
      _clearError();
    } on StudyMateApiException catch (error) {
      _setError(error);
      rethrow;
    }
    notifyListeners();
  }

  Future<void> addNote({
    required String title,
    required String content,
  }) async {
    _requireBackendSession();
    final note = StudyNote(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      content: content,
    );
    try {
      final saved = await _api.createNote(note);
      _notes = [saved, ..._notes];
      _clearError();
    } on StudyMateApiException catch (error) {
      _setError(error);
      rethrow;
    }
    notifyListeners();
  }

  Future<void> deleteNote(StudyNote note) async {
    _requireBackendSession();
    try {
      await _api.deleteNote(note.id);
      _notes = _notes.where((item) => item.id != note.id).toList();
      _clearError();
    } on StudyMateApiException catch (error) {
      _setError(error);
      rethrow;
    }
    notifyListeners();
  }

  Future<void> addFlashcardDeck({
    required String title,
    String? description,
    String? courseId,
  }) async {
    _requireBackendSession();
    final now = DateTime.now();
    final deck = StudyFlashcardDeck(
      id: 'local-${now.microsecondsSinceEpoch}',
      title: title,
      description: description,
      courseId: courseId,
      source: 'manual',
      createdAt: now,
      updatedAt: now,
    );
    try {
      final saved = await _api.createFlashcardDeck(deck);
      _flashcardDecks = [saved, ..._flashcardDecks];
      _clearError();
    } on StudyMateApiException catch (error) {
      _setError(error);
      rethrow;
    }
    notifyListeners();
  }

  Future<void> updateFlashcardDeck({
    required StudyFlashcardDeck deck,
    required String title,
    String? description,
    String? courseId,
  }) async {
    _requireBackendSession();
    final updated = StudyFlashcardDeck(
      id: deck.id,
      title: title,
      description: description,
      courseId: courseId,
      source: deck.source,
      createdAt: deck.createdAt,
      updatedAt: DateTime.now(),
    );
    try {
      final saved = await _api.updateFlashcardDeck(updated);
      _flashcardDecks = [
        for (final item in _flashcardDecks)
          if (item.id == saved.id) saved else item,
      ];
      _clearError();
    } on StudyMateApiException catch (error) {
      _setError(error);
      rethrow;
    }
    notifyListeners();
  }

  Future<void> deleteFlashcardDeck(StudyFlashcardDeck deck) async {
    _requireBackendSession();
    try {
      await _api.deleteFlashcardDeck(deck.id);
      _flashcardDecks =
          _flashcardDecks.where((item) => item.id != deck.id).toList();
      _clearError();
    } on StudyMateApiException catch (error) {
      _setError(error);
      rethrow;
    }
    notifyListeners();
  }

  Future<List<StudyFlashcard>> getFlashcards(String deckId) async {
    _requireBackendSession();
    try {
      return await _api.getFlashcards(deckId);
    } on StudyMateApiException catch (error) {
      _setError(error);
      rethrow;
    }
  }

  Future<StudyFlashcardDeckProgress> getFlashcardDeckProgress(
    String deckId,
  ) async {
    _requireBackendSession();
    try {
      return await _api.getFlashcardDeckProgress(deckId);
    } on StudyMateApiException catch (error) {
      _setError(error);
      rethrow;
    }
  }

  Future<void> addFlashcard({
    required String deckId,
    required String question,
    required String answer,
  }) async {
    _requireBackendSession();
    try {
      await _api.createFlashcard(
        deckId: deckId,
        question: question,
        answer: answer,
      );
      _clearError();
    } on StudyMateApiException catch (error) {
      _setError(error);
      rethrow;
    }
    notifyListeners();
  }

  Future<void> updateFlashcard(StudyFlashcard flashcard) async {
    _requireBackendSession();
    try {
      await _api.updateFlashcard(flashcard);
      _clearError();
    } on StudyMateApiException catch (error) {
      _setError(error);
      rethrow;
    }
    notifyListeners();
  }

  Future<void> deleteFlashcard(StudyFlashcard flashcard) async {
    _requireBackendSession();
    try {
      await _api.deleteFlashcard(flashcard.id);
      _clearError();
    } on StudyMateApiException catch (error) {
      _setError(error);
      rethrow;
    }
    notifyListeners();
  }

  Future<StudyFlashcardReviewResult> reviewFlashcard({
    required StudyFlashcard flashcard,
    required bool isCorrect,
  }) async {
    _requireBackendSession();
    try {
      final result = await _api.reviewFlashcard(
        flashcardId: flashcard.id,
        isCorrect: isCorrect,
      );
      _clearError();
      notifyListeners();
      return result;
    } on StudyMateApiException catch (error) {
      _setError(error);
      rethrow;
    }
  }

  Future<void> addEvaluation({
    required String title,
    required String evaluationType,
    required double? score,
    required double? maxScore,
    String? courseId,
    DateTime? scheduledAt,
    String? notes,
  }) async {
    _requireBackendSession();
    final now = DateTime.now();
    final evaluation = StudyEvaluation(
      id: 'local-${now.microsecondsSinceEpoch}',
      title: title,
      evaluationType: evaluationType,
      courseId: courseId,
      scheduledAt: scheduledAt,
      score: score,
      maxScore: maxScore,
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );
    try {
      final saved = await _api.createEvaluation(evaluation);
      _evaluations = [saved, ..._evaluations];
      await _refreshEvaluationSummary();
      _clearError();
    } on StudyMateApiException catch (error) {
      _setError(error);
      rethrow;
    }
    notifyListeners();
  }

  Future<void> updateEvaluation(StudyEvaluation evaluation) async {
    _requireBackendSession();
    try {
      final saved = await _api.updateEvaluation(evaluation);
      _evaluations = [
        for (final item in _evaluations)
          if (item.id == saved.id) saved else item,
      ];
      await _refreshEvaluationSummary();
      _clearError();
    } on StudyMateApiException catch (error) {
      _setError(error);
      rethrow;
    }
    notifyListeners();
  }

  Future<void> deleteEvaluation(StudyEvaluation evaluation) async {
    _requireBackendSession();
    try {
      await _api.deleteEvaluation(evaluation.id);
      _evaluations =
          _evaluations.where((item) => item.id != evaluation.id).toList();
      await _refreshEvaluationSummary();
      _clearError();
    } on StudyMateApiException catch (error) {
      _setError(error);
      rethrow;
    }
    notifyListeners();
  }

  void _clearAccountData() {
    _hasBackendSession = false;
    _isLoading = false;
    _isProfileLoading = false;
    _errorMessage = null;
    _profileErrorMessage = null;
    _userProfile = null;
    _studentProfile = null;
    _courses = const [];
    _weeklySchedule = const [];
    _tasks = const [];
    _notes = const [];
    notifyListeners();
  }

  void _requireBackendSession() {
    if (!_hasBackendSession) {
      throw const StudyMateApiException(
        'Connecte-toi pour enregistrer tes données dans StudyMate.',
      );
    }
  }

  void _replaceTask(int index, StudyTask value) {
    final next = [..._tasks];
    next[index] = value;
    _tasks = next;
    notifyListeners();
  }

  Future<void> _refreshWeeklySchedule() async {
    _weeklySchedule = await _api.getWeeklySchedule();
  }

  Future<void> _refreshEvaluationSummary() async {
    final results = await Future.wait([
      _api.getEvaluations(),
      _api.getEvaluationSummary(),
    ]);
    _evaluations = results[0] as List<StudyEvaluation>;
    _evaluationSummary = results[1] as StudyEvaluationSummary;
  }

  void _setError(StudyMateApiException error) {
    _errorMessage = error.message;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }
}
