import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../data/local/local_database.dart';
import '../data/models/study_models.dart';
import '../data/services/studymate_api.dart';
import '../data/sync/offline_outbox.dart';
import '../data/sync/sync_service.dart';
import '../features/notifications/push_service.dart';

class StudyController extends ChangeNotifier {
  StudyController({
    required StudyMateApi api,
    this.push,
    this.sync,
    LocalDatabase? localDb,
  })  : _api = api,
        _db = localDb ?? LocalDatabase.instance {
    sync?.onCreated(_onSyncCreated);
    sync?.onRejected(_onSyncRejected);
  }

  /// File d'attente hors ligne (absente dans les tests unitaires).
  final SyncService? sync;

  /// Expose the local database so callers can run direct queries (e.g. stats).
  LocalDatabase get localDb => _db;

  final StudyMateApi _api;
  final LocalDatabase _db;
  final PushService? push;

  StudyMateApi get api => _api;

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

  /// Change (ou retire, avec `null`) la photo de profil tout de suite, sans
  /// attendre le reste du formulaire : l'avatar de l'accueil se met à jour.
  Future<void> updateProfilePhoto({
    required User firebaseUser,
    required String? photoUrl,
  }) async {
    final current = _userProfile;
    _userProfile = await _api.updateCurrentUser(
      displayName: current?.displayName ?? firebaseUser.displayName ?? '',
      photoUrl: photoUrl,
      locale: current?.locale,
      timezone: current?.timezone,
    );
    try {
      await firebaseUser.updatePhotoURL(photoUrl);
    } on FirebaseAuthException {
      // Le profil StudyMate fait foi ; Firebase sera resynchronisé au prochain enregistrement.
    }
    notifyListeners();
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
      await _clearAccountData();
      return;
    }

    _hasBackendSession = true;
    _errorMessage = null;
    _isProfileLoading = true;
    _profileErrorMessage = null;
    _userProfile = null;
    _studentProfile = null;
    _evaluationSummary = null;

    // ── Step 1 : load from SQLite immediately (cache-first) ──────────────
    final cached = await Future.wait([
      _db.getCourses(),
      _db.getTasks(),
      _db.getNotes(),
      _db.getFlashcardDecks(),
      _db.getEvaluations(),
    ]);
    _courses = cached[0] as List<StudyCourse>;
    _tasks = cached[1] as List<StudyTask>;
    _notes = cached[2] as List<StudyNote>;
    _flashcardDecks = cached[3] as List<StudyFlashcardDeck>;
    _evaluations = cached[4] as List<StudyEvaluation>;

    // Show cached data immediately while we fetch from network.
    _isLoading = _courses.isEmpty && _tasks.isEmpty;
    notifyListeners();

    final cachedCourses = _courses;
    final cachedTasks = _tasks;
    final cachedNotes = _notes;

    // ── Step 2 : sync from API in background ─────────────────────────────
    try {
      // Envoie d'abord le travail fait hors ligne.
      await sync?.flush();
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

      // Ce qui n'a pas encore pu partir reste visible.
      final pending = await sync?.outbox.pending(user.uid) ?? const [];
      _courses = _overlay(_courses, cachedCourses, pending, 'course', (c) => c.id);
      _tasks = _overlay(_tasks, cachedTasks, pending, 'task', (t) => t.id);
      _notes = _overlay(_notes, cachedNotes, pending, 'note', (n) => n.id);
      _refreshWeeklySchedule();

      // ── Step 3 : persist fresh data into SQLite ───────────────────────
      await Future.wait([
        _db.upsertCourses(_courses),
        _db.upsertTasks(_tasks),
        _db.upsertNotes(_notes),
        _db.upsertDecks(_flashcardDecks),
        _db.upsertEvaluations(_evaluations),
      ]);
    } on StudyMateApiException catch (error) {
      // Hors ligne : les données locales suffisent, pas de bandeau d'erreur.
      if (!error.isNetworkError) _errorMessage = error.message;
      _profileErrorMessage = error.message;
      _refreshWeeklySchedule();
      // Keep showing cached data — don't blank the UI.
    } finally {
      _isLoading = false;
      _isProfileLoading = false;
      notifyListeners();
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // Hors ligne d'abord : chaque modification est appliquée tout de suite sur
  // le téléphone (écran + SQLite), puis mise dans la file d'attente et
  // envoyée au serveur dès que le réseau le permet.
  // ══════════════════════════════════════════════════════════════════════

  Future<void> _queue(
    String entity,
    OutboxOp op,
    String entityId, [
    Map<String, dynamic> payload = const {},
  ]) async {
    final sync = this.sync;
    if (sync == null) return;
    await sync.enqueue(
      entity: entity,
      op: op,
      entityId: entityId,
      payload: payload,
    );
  }

  /// Nombre de modifications pas encore envoyées au serveur.
  int get pendingChanges => sync?.pendingCount ?? 0;

  Future<void> addTask(String title) async {
    _requireBackendSession();
    final task = StudyTask(
      id: newLocalId(),
      title: title,
      description: 'À faire aujourd’hui',
    );
    _tasks = [task, ..._tasks];
    await _db.upsertTask(task);
    _clearError();
    notifyListeners();
    await _queue('task', OutboxOp.create, task.id, task.toJson());
  }

  Future<void> toggleTask(StudyTask task, bool isCompleted) async {
    _requireBackendSession();
    final index = _tasks.indexWhere((item) => item.id == task.id);
    if (index < 0) return;
    final updated = _tasks[index].copyWith(isCompleted: isCompleted);
    _replaceTask(index, updated);
    await _db.upsertTask(updated);
    await _queue('task', OutboxOp.update, task.id, {'is_completed': isCompleted});
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
    final course = StudyCourse(
      id: newLocalId(),
      title: title,
      code: code,
      professor: professor,
      room: room,
      weekday: weekday,
      startTime: startTime,
      endTime: endTime,
    );
    _checkCourseOverlap(course);
    _courses = [course, ..._courses];
    _refreshWeeklySchedule();
    await _db.upsertCourse(course);
    _clearError();
    notifyListeners();
    await _queue('course', OutboxOp.create, course.id, _coursePayload(course));
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
    final updated = StudyCourse(
      id: course.id,
      title: title,
      code: code,
      professor: professor,
      room: room,
      weekday: weekday,
      startTime: startTime,
      endTime: endTime,
    );
    _checkCourseOverlap(updated);
    _courses = [
      for (final item in _courses)
        if (item.id == updated.id) updated else item,
    ];
    _refreshWeeklySchedule();
    await _db.upsertCourse(updated);
    _clearError();
    notifyListeners();
    await _queue('course', OutboxOp.update, course.id, _coursePayload(updated));
  }

  Future<void> deleteCourse(StudyCourse course) async {
    _requireBackendSession();
    _courses = _courses.where((item) => item.id != course.id).toList();
    _refreshWeeklySchedule();
    await _db.deleteCourse(course.id);
    _clearError();
    notifyListeners();
    await _queue('course', OutboxOp.delete, course.id);
  }

  Future<void> addNote({
    required String title,
    required String content,
  }) async {
    _requireBackendSession();
    final note = StudyNote(
      id: newLocalId(),
      title: title,
      content: content,
      updatedAt: DateTime.now(),
    );
    _notes = [note, ..._notes];
    await _db.upsertNote(note);
    _clearError();
    notifyListeners();
    await _queue('note', OutboxOp.create, note.id, note.toJson());
  }

  Future<void> updateNote(StudyNote note) async {
    _requireBackendSession();
    _notes = [for (final item in _notes) item.id == note.id ? note : item];
    await _db.upsertNote(note);
    _clearError();
    notifyListeners();
    await _queue(
      'note',
      OutboxOp.update,
      note.id,
      {'title': note.title, 'content': note.content},
    );
  }

  Future<void> deleteNote(StudyNote note) async {
    _requireBackendSession();
    _notes = _notes.where((item) => item.id != note.id).toList();
    await _db.deleteNote(note.id);
    _clearError();
    notifyListeners();
    await _queue('note', OutboxOp.delete, note.id);
  }

  static Map<String, dynamic> _coursePayload(StudyCourse course) => {
        'title': course.title,
        'code': course.code,
        'professor': course.professor,
        'room': course.room,
        'weekday': course.weekday,
        'start_time': course.startTime,
        'end_time': course.endTime,
      };

  /// Même règle que le serveur : deux cours ne peuvent pas se chevaucher le
  /// même jour. Vérifiée localement pour répondre tout de suite, hors ligne.
  void _checkCourseOverlap(StudyCourse course) {
    int? minutes(String? value) {
      if (value == null || value.isEmpty) return null;
      final parts = value.split(':');
      return int.parse(parts[0]) * 60 + int.parse(parts[1]);
    }

    final start = minutes(course.startTime);
    final end = minutes(course.endTime);
    if (course.weekday == null || start == null || end == null) return;
    for (final other in _courses) {
      if (other.id == course.id || other.weekday != course.weekday) continue;
      final otherStart = minutes(other.startTime);
      final otherEnd = minutes(other.endTime);
      if (otherStart == null || otherEnd == null) continue;
      if (start < otherEnd && otherStart < end) {
        throw StudyMateApiException(
          'Ce créneau chevauche « ${other.title} » le même jour.',
          code: 'course_schedule_conflict',
        );
      }
    }
  }

  /// Création confirmée par le serveur : l'identifiant local est remplacé.
  Future<void> _onSyncCreated(
    String entity,
    String localId,
    Map<String, dynamic> json,
  ) async {
    switch (entity) {
      case 'task':
        final saved = StudyTask.fromJson(json);
        _tasks = [for (final t in _tasks) t.id == localId ? saved : t];
        await _db.deleteTask(localId);
        await _db.upsertTask(saved);
        // Une tâche peut pointer vers un cours créé hors ligne.
      case 'course':
        final saved = StudyCourse.fromJson(json);
        _courses = [for (final c in _courses) c.id == localId ? saved : c];
        _tasks = [
          for (final t in _tasks)
            t.courseId == localId
                ? StudyTask(
                    id: t.id,
                    title: t.title,
                    description: t.description,
                    priority: t.priority,
                    deadline: t.deadline,
                    courseId: saved.id,
                    isCompleted: t.isCompleted,
                  )
                : t,
        ];
        _refreshWeeklySchedule();
        await _db.deleteCourse(localId);
        await _db.upsertCourse(saved);
      case 'note':
        final saved = StudyNote.fromJson(json);
        _notes = [for (final n in _notes) n.id == localId ? saved : n];
        await _db.deleteNote(localId);
        await _db.upsertNote(saved);
      default:
        return;
    }
    notifyListeners();
  }

  /// Refus définitif : on annule le changement local puis on se recale sur
  /// le serveur, pour que l'écran reflète la vérité.
  Future<void> _onSyncRejected(OutboxEntry entry, String message) async {
    if (!const {'task', 'course', 'note'}.contains(entry.entity)) return;
    _errorMessage = sync?.takeLastRejection() ?? message;
    if (entry.op == OutboxOp.create) {
      switch (entry.entity) {
        case 'task':
          _tasks = _tasks.where((t) => t.id != entry.entityId).toList();
          await _db.deleteTask(entry.entityId);
        case 'course':
          _courses = _courses.where((c) => c.id != entry.entityId).toList();
          _refreshWeeklySchedule();
          await _db.deleteCourse(entry.entityId);
        case 'note':
          _notes = _notes.where((n) => n.id != entry.entityId).toList();
          await _db.deleteNote(entry.entityId);
      }
    } else {
      try {
        switch (entry.entity) {
          case 'task':
            _tasks = await _api.getTasks();
            await _db.upsertTasks(_tasks);
          case 'course':
            _courses = await _api.getCourses();
            _refreshWeeklySchedule();
            await _db.upsertCourses(_courses);
          case 'note':
            _notes = await _api.getNotes();
            await _db.upsertNotes(_notes);
        }
      } on StudyMateApiException catch (_) {}
    }
    notifyListeners();
  }

  /// Réapplique les modifications en attente sur une liste reçue du serveur
  /// (sinon un rechargement ferait « disparaître » le travail hors ligne).
  List<T> _overlay<T>(
    List<T> server,
    List<T> local,
    List<OutboxEntry> pending,
    String entity,
    String Function(T) idOf,
  ) {
    final ops = pending.where((e) => e.entity == entity).toList();
    if (ops.isEmpty) return server;
    final localById = {for (final item in local) idOf(item): item};
    final deleted = {
      for (final e in ops)
        if (e.op == OutboxOp.delete) e.entityId,
    };
    final changed = {
      for (final e in ops)
        if (e.op != OutboxOp.delete && localById.containsKey(e.entityId)) e.entityId,
    };
    final result = [
      for (final item in server)
        if (!deleted.contains(idOf(item)))
          changed.contains(idOf(item)) ? localById[idOf(item)] as T : item,
    ];
    final serverIds = {for (final item in server) idOf(item)};
    final created = [
      for (final id in changed)
        if (!serverIds.contains(id)) localById[id] as T,
    ];
    return [...created, ...result];
  }

  Future<StudyFlashcardDeck> addFlashcardDeck({
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
      await _db.upsertDeck(saved);
      _clearError();
      notifyListeners();
      return saved;
    } on StudyMateApiException catch (error) {
      _setError(error);
      rethrow;
    }
  }

  /// Fait générer des cartes par l'IA dans [deck].
  Future<StudyFlashcardGeneration> generateFlashcards({
    required StudyFlashcardDeck deck,
    String? noteId,
    String? documentId,
    String? text,
    int maxCards = 8,
  }) async {
    _requireBackendSession();
    final result = await _api.generateFlashcards(
      deckId: deck.id,
      noteId: noteId,
      documentId: documentId,
      text: text,
      maxCards: maxCards,
    );
    await _db.upsertFlashcards(result.cards);
    if (result.usedAi && deck.source != 'ai_generated') {
      final updated = StudyFlashcardDeck(
        id: deck.id,
        title: deck.title,
        description: deck.description,
        courseId: deck.courseId,
        source: 'ai_generated',
        createdAt: deck.createdAt,
        updatedAt: DateTime.now(),
      );
      _flashcardDecks = [
        for (final item in _flashcardDecks) item.id == deck.id ? updated : item,
      ];
      await _db.upsertDeck(updated);
    }
    notifyListeners();
    return result;
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
      await _db.upsertDeck(saved);
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
      await _db.deleteDeck(deck.id);
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
      final cards = await _api.getFlashcards(deckId);
      await _db.upsertFlashcards(cards);
      return cards;
    } on StudyMateApiException catch (error) {
      _setError(error);
      // Fallback to local cache when offline.
      final cached = await _db.getFlashcards(deckId);
      if (cached.isNotEmpty) return cached;
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
      await _db.deleteFlashcard(flashcard.id);
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
      await _db.upsertFlashcard(result.flashcard);
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
      await _db.upsertEvaluation(saved);
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
      await _db.upsertEvaluation(saved);
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
      await _db.deleteEvaluation(evaluation.id);
      await _refreshEvaluationSummary();
      _clearError();
    } on StudyMateApiException catch (error) {
      _setError(error);
      rethrow;
    }
    notifyListeners();
  }

  Future<void> _clearAccountData() async {
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
    _flashcardDecks = const [];
    _evaluations = const [];
    _evaluationSummary = null;
    // Wipe local SQLite cache on sign-out for privacy.
    await _db.clearAll();
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

  void _refreshWeeklySchedule() {
    _weeklySchedule = [
      for (final course in _courses)
        if (course.weekday != null) course,
    ];
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
