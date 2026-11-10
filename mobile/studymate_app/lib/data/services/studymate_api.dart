import 'package:dio/dio.dart';

import '../../core/config/api_config.dart';
import '../models/ai_models.dart';
import '../models/document_models.dart';
import '../models/event_models.dart';
import '../models/planning_models.dart';
import '../models/study_models.dart';

typedef FirebaseTokenProvider = Future<String?> Function();

class StudyMateApiException implements Exception {
  const StudyMateApiException(
    this.message, {
    this.code,
    this.statusCode,
    this.isNetworkError = false,
  });

  final String message;

  /// Code d'erreur métier renvoyé par le backend (ex. `ai_consent_required`).
  final String? code;

  /// Statut HTTP, quand le serveur a répondu.
  final int? statusCode;

  /// `true` si le serveur n'a pas pu être joint (hors ligne, délai dépassé) :
  /// l'opération peut être rejouée plus tard sans risque.
  final bool isNetworkError;

  @override
  String toString() => message;
}

class StudyMateApi {
  StudyMateApi({required FirebaseTokenProvider? tokenProvider})
      : _tokenProvider = tokenProvider,
        _dio = Dio(
          BaseOptions(
            baseUrl: ApiConfig.baseUrl,
            connectTimeout: const Duration(seconds: 5),
            receiveTimeout: const Duration(seconds: 10),
            sendTimeout: const Duration(seconds: 10),
            headers: const {'Accept': 'application/json'},
          ),
        );

  final FirebaseTokenProvider? _tokenProvider;
  final Dio _dio;

  Future<void> checkHealth() async {
    try {
      await _dio.get<Map<String, dynamic>>('/health');
    } on DioException catch (error) {
      throw _toApiException(error);
    }
  }

  Future<StudyMateUserProfile> getCurrentUser() async {
    final response = await _get<Map<String, dynamic>>('/users/me');
    return StudyMateUserProfile.fromJson(response);
  }

  Future<StudyMateUserProfile> updateCurrentUser({
    required String displayName,
    String? photoUrl,
    String? locale,
    String? timezone,
  }) async {
    final response = await _put<Map<String, dynamic>>(
      '/users/me',
      data: {
        'display_name': displayName,
        'photo_url': photoUrl,
        'locale': locale,
        'timezone': timezone,
      },
    );
    return StudyMateUserProfile.fromJson(response);
  }

  Future<StudentProfile> getStudentProfile() async {
    final response = await _get<Map<String, dynamic>>('/profile');
    return StudentProfile.fromJson(response);
  }

  Future<StudentProfile> updateStudentProfile({
    required String? studyLevel,
    required String? specialty,
    required List<String> academicGoals,
    required String? preferredLearningStyle,
    required int dailyStudyGoalMinutes,
    required Map<String, dynamic> preferences,
  }) async {
    final response = await _put<Map<String, dynamic>>(
      '/profile',
      data: {
        'study_level': studyLevel,
        'specialty': specialty,
        'academic_goals': academicGoals,
        'preferred_learning_style': preferredLearningStyle,
        'daily_study_goal_minutes': dailyStudyGoalMinutes,
        'preferences': preferences,
      },
    );
    return StudentProfile.fromJson(response);
  }

  Future<List<StudyCourse>> getCourses() async {
    final response = await _get<List<dynamic>>('/courses');
    return response.map((item) => StudyCourse.fromJson(_asJson(item))).toList();
  }

  Future<List<StudyCourse>> getWeeklySchedule() async {
    final response = await _get<List<dynamic>>('/courses/schedule');
    return response.map((item) => StudyCourse.fromJson(_asJson(item))).toList();
  }

  Future<StudyCourse> createCourse({
    required String title,
    String? code,
    String? professor,
    String? room,
    int? weekday,
    String? startTime,
    String? endTime,
  }) async {
    final response = await _post<Map<String, dynamic>>(
      '/courses',
      data: _coursePayload(
        title: title,
        code: code,
        professor: professor,
        room: room,
        weekday: weekday,
        startTime: startTime,
        endTime: endTime,
      ),
    );
    return StudyCourse.fromJson(response);
  }

  Future<StudyCourse> updateCourse({
    required StudyCourse course,
    required String title,
    String? code,
    String? professor,
    String? room,
    int? weekday,
    String? startTime,
    String? endTime,
  }) async {
    final response = await _put<Map<String, dynamic>>(
      '/courses/${course.id}',
      data: _coursePayload(
        title: title,
        code: code,
        professor: professor,
        room: room,
        weekday: weekday,
        startTime: startTime,
        endTime: endTime,
      ),
    );
    return StudyCourse.fromJson(response);
  }

  Future<void> deleteCourse(String id) async {
    await _delete('/courses/$id');
  }

  Map<String, dynamic> _coursePayload({
    required String title,
    String? code,
    String? professor,
    String? room,
    int? weekday,
    String? startTime,
    String? endTime,
  }) =>
      {
        'title': title,
        'code': code,
        'professor': professor,
        'room': room,
        'weekday': weekday,
        'start_time': startTime,
        'end_time': endTime,
      };

  Future<StudyTask> createTask(StudyTask task) async {
    final response = await _post<Map<String, dynamic>>(
      '/tasks',
      data: task.toJson(),
    );
    return StudyTask.fromJson(response);
  }

  Future<List<StudyTask>> getTasks() async {
    final response = await _get<List<dynamic>>('/tasks');
    return response.map((item) => StudyTask.fromJson(_asJson(item))).toList();
  }

  Future<StudyTask> updateTask(StudyTask task) async {
    final response = await _patch<Map<String, dynamic>>(
      '/tasks/${task.id}',
      data: {'is_completed': task.isCompleted},
    );
    return StudyTask.fromJson(response);
  }

  Future<void> deleteTask(String id) async {
    await _delete('/tasks/$id');
  }

  Future<List<StudyNote>> getNotes() async {
    final response = await _get<List<dynamic>>('/notes');
    return response.map((item) => StudyNote.fromJson(_asJson(item))).toList();
  }

  Future<StudyNote> createNote(StudyNote note) async {
    final response = await _post<Map<String, dynamic>>(
      '/notes',
      data: note.toJson(),
    );
    return StudyNote.fromJson(response);
  }

  Future<StudyNote> updateNote(StudyNote note) async {
    final response = await _put<Map<String, dynamic>>(
      '/notes/${note.id}',
      data: {'title': note.title, 'content': note.content},
    );
    return StudyNote.fromJson(response);
  }

  // ── Emploi du temps : agenda réel (jours fériés Nager.Date) ───────────────

  Future<WeekAgenda> getWeekAgenda(DateTime weekStart) async {
    final day = '${weekStart.year.toString().padLeft(4, '0')}-'
        '${weekStart.month.toString().padLeft(2, '0')}-'
        '${weekStart.day.toString().padLeft(2, '0')}';
    final path = Uri(
      path: '/schedule/week-agenda',
      queryParameters: {'week_start': day},
    ).toString();
    return WeekAgenda.fromJson(await _get<Map<String, dynamic>>(path));
  }

  // ── Partage de l'emploi du temps (QR code via QR Server) ──────────────────

  Future<TimetableShare> createTimetableShare({int days = 7}) async =>
      TimetableShare.fromJson(
        await _post<Map<String, dynamic>>(
          '/timetable/shares?days=$days',
          data: const <String, dynamic>{},
        ),
      );

  Future<List<TimetableShare>> getTimetableShares() async {
    final response = await _get<List<dynamic>>('/timetable/shares');
    return response
        .map((item) => TimetableShare.fromJson(_asJson(item)))
        .toList();
  }

  Future<void> revokeTimetableShare(String id) =>
      _delete('/timetable/shares/$id');

  // ── Planificateur intelligent de tâches ───────────────────────────────────

  Future<TaskPlan> getTaskPlan({int days = 7}) async => TaskPlan.fromJson(
      await _get<Map<String, dynamic>>('/tasks/plan?days=$days'));

  /// Découpe une tâche en étapes avec l'IA (Groq). Avec [createTasks], les
  /// étapes sont créées comme sous-tâches.
  Future<List<TaskBreakdownStep>> breakdownTask(
    String taskId, {
    bool createTasks = false,
  }) async {
    try {
      final options = await _authorizedOptions();
      final response = await _dio.post<Map<String, dynamic>>(
        '/ai/tasks/$taskId/breakdown',
        data: {'create_tasks': createTasks},
        options: options.copyWith(receiveTimeout: const Duration(seconds: 60)),
      );
      final body = _asJson(response.data);
      return [
        for (final item in (body['steps'] as List<dynamic>? ?? const []))
          TaskBreakdownStep.fromJson(_asJson(item)),
      ];
    } on DioException catch (error) {
      throw _toApiException(error);
    }
  }

  // ── Enrichissement des notes (Wikipédia) ──────────────────────────────────

  Future<List<WikipediaResult>> searchWikipedia(String query) async {
    final path = Uri(
      path: '/knowledge/wikipedia',
      queryParameters: {'q': query},
    ).toString();
    final response = await _get<List<dynamic>>(path);
    return response
        .map((item) => WikipediaResult.fromJson(_asJson(item)))
        .toList();
  }

  Future<void> deleteNote(String id) async {
    await _delete('/notes/$id');
  }

  Future<List<StudyFlashcardDeck>> getFlashcardDecks() async {
    final response = await _get<List<dynamic>>('/flashcard-decks');
    return response
        .map((item) => StudyFlashcardDeck.fromJson(_asJson(item)))
        .toList();
  }

  Future<StudyFlashcardDeck> createFlashcardDeck(
    StudyFlashcardDeck deck,
  ) async {
    final response = await _post<Map<String, dynamic>>(
      '/flashcard-decks',
      data: deck.toJson(),
    );
    return StudyFlashcardDeck.fromJson(response);
  }

  Future<StudyFlashcardDeck> updateFlashcardDeck(
    StudyFlashcardDeck deck,
  ) async {
    final response = await _put<Map<String, dynamic>>(
      '/flashcard-decks/${deck.id}',
      data: deck.toJson(),
    );
    return StudyFlashcardDeck.fromJson(response);
  }

  Future<void> deleteFlashcardDeck(String id) async {
    await _delete('/flashcard-decks/$id');
  }

  Future<List<StudyFlashcard>> getFlashcards(String deckId) async {
    final response = await _get<List<dynamic>>(
      '/flashcard-decks/$deckId/cards',
    );
    return response
        .map((item) => StudyFlashcard.fromJson(_asJson(item)))
        .toList();
  }

  Future<StudyFlashcardDeckProgress> getFlashcardDeckProgress(
    String deckId,
  ) async {
    final response = await _get<Map<String, dynamic>>(
      '/flashcard-decks/$deckId/progress',
    );
    return StudyFlashcardDeckProgress.fromJson(response);
  }

  Future<StudyFlashcard> createFlashcard({
    required String deckId,
    required String question,
    required String answer,
  }) async {
    final response = await _post<Map<String, dynamic>>(
      '/flashcard-decks/$deckId/cards',
      data: {
        'question': question,
        'answer': answer,
        'deck_id': deckId,
      },
    );
    return StudyFlashcard.fromJson(response);
  }

  /// Fait générer des cartes par l'IA dans [deckId], à partir d'une note
  /// ([noteId]) ou d'un texte collé ([text]).
  Future<StudyFlashcardGeneration> generateFlashcards({
    required String deckId,
    String? noteId,
    String? documentId,
    String? text,
    int maxCards = 8,
  }) async {
    try {
      final options = await _authorizedOptions();
      final response = await _dio.post<Map<String, dynamic>>(
        '/flashcard-decks/$deckId/generate',
        data: {
          if (noteId != null) 'note_id': noteId,
          if (documentId != null) 'document_id': documentId,
          if (text != null) 'text': text,
          'max_cards': maxCards,
        },
        // L'IA peut prendre plus longtemps qu'une requête classique.
        options: options.copyWith(
          receiveTimeout: const Duration(seconds: 60),
        ),
      );
      final body = _asJson(response.data);
      return StudyFlashcardGeneration(
        source: body['source'] == 'ai' ? 'ai' : 'rules',
        cards: [
          for (final item in (body['cards'] as List<dynamic>? ?? const []))
            StudyFlashcard.fromJson(_asJson(item)),
        ],
      );
    } on DioException catch (error) {
      throw _toApiException(error);
    }
  }

  // ── PDF de cours ──────────────────────────────────────────────────────

  Future<List<CourseDocument>> listCourseDocuments(String courseId) async {
    final response = await _get<List<dynamic>>('/courses/$courseId/documents');
    return [for (final item in response) CourseDocument.fromJson(_asJson(item))];
  }

  Future<CourseDocument> uploadCourseDocument({
    required String courseId,
    required List<int> bytes,
    required String filename,
    String? title,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final options = await _authorizedOptions();
      final response = await _dio.post<Map<String, dynamic>>(
        '/courses/$courseId/documents',
        data: FormData.fromMap({
          'file': MultipartFile.fromBytes(
            bytes,
            filename: filename,
            contentType: DioMediaType('application', 'pdf'),
          ),
          if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
        }),
        options: options.copyWith(
          sendTimeout: const Duration(minutes: 2),
          receiveTimeout: const Duration(minutes: 2),
        ),
        onSendProgress: onProgress == null
            ? null
            : (sent, total) {
                if (total > 0) onProgress(sent / total);
              },
      );
      return CourseDocument.fromJson(_asJson(response.data));
    } on DioException catch (error) {
      throw _toApiException(error);
    }
  }

  /// Contenu brut du PDF (pour l'afficher dans l'app).
  Future<List<int>> downloadDocument(
    String documentId, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      final options = await _authorizedOptions();
      final response = await _dio.get<List<int>>(
        '/documents/$documentId/file',
        options: options.copyWith(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(minutes: 2),
        ),
        onReceiveProgress: onProgress == null
            ? null
            : (received, total) {
                if (total > 0) onProgress(received / total);
              },
      );
      return response.data ?? const [];
    } on DioException catch (error) {
      throw _toApiException(error);
    }
  }

  Future<CourseDocument> renameDocument(String documentId, String title) async {
    final response = await _patch<Map<String, dynamic>>(
      '/documents/$documentId',
      data: {'title': title},
    );
    return CourseDocument.fromJson(response);
  }

  Future<void> deleteDocument(String documentId) => _delete('/documents/$documentId');

  Future<StudyFlashcard> updateFlashcard(StudyFlashcard flashcard) async {
    final response = await _put<Map<String, dynamic>>(
      '/flashcards/${flashcard.id}',
      data: flashcard.toJson(),
    );
    return StudyFlashcard.fromJson(response);
  }

  Future<void> deleteFlashcard(String id) async {
    await _delete('/flashcards/$id');
  }

  Future<StudyFlashcardReviewResult> reviewFlashcard({
    required String flashcardId,
    required bool isCorrect,
  }) async {
    final response = await _post<Map<String, dynamic>>(
      '/flashcards/$flashcardId/review',
      data: {'is_correct': isCorrect},
    );
    return StudyFlashcardReviewResult.fromJson(response);
  }

  Future<List<StudyEvaluation>> getEvaluations() async {
    final response = await _get<List<dynamic>>('/evaluations');
    return response
        .map((item) => StudyEvaluation.fromJson(_asJson(item)))
        .toList();
  }

  Future<StudyEvaluationSummary> getEvaluationSummary() async {
    final response = await _get<Map<String, dynamic>>('/evaluations/summary');
    return StudyEvaluationSummary.fromJson(response);
  }

  Future<StudyEvaluation> createEvaluation(StudyEvaluation evaluation) async {
    final response = await _post<Map<String, dynamic>>(
      '/evaluations',
      data: evaluation.toJson(),
    );
    return StudyEvaluation.fromJson(response);
  }

  Future<StudyEvaluation> updateEvaluation(StudyEvaluation evaluation) async {
    final response = await _put<Map<String, dynamic>>(
      '/evaluations/${evaluation.id}',
      data: evaluation.toJson(),
    );
    return StudyEvaluation.fromJson(response);
  }

  Future<void> deleteEvaluation(String id) async {
    await _delete('/evaluations/$id');
  }

  Future<AiConsent> getAiConsent() async =>
      AiConsent.fromJson(await _get<Map<String, dynamic>>('/ai/consent'));

  Future<AiConsent> setAiConsent(bool granted) async => AiConsent.fromJson(
        await _put<Map<String, dynamic>>(
          '/ai/consent',
          data: {'granted': granted},
        ),
      );

  Future<List<AiInsight>> getAiInsights() async {
    final response = await _get<List<dynamic>>('/ai/insights');
    return response.map((item) => AiInsight.fromJson(_asJson(item))).toList();
  }

  Future<AiInsight> analyzeAiProfile() async => AiInsight.fromJson(
        await _post<Map<String, dynamic>>('/ai/profile/analyze', data: null),
      );

  Future<List<AiRecommendation>> getAiRecommendations() async {
    final response = await _get<List<dynamic>>('/ai/recommendations');
    return response
        .map((item) => AiRecommendation.fromJson(_asJson(item)))
        .toList();
  }

  Future<List<AiRecommendation>> generateAiRecommendations() async {
    final response = await _post<List<dynamic>>(
      '/ai/recommendations',
      data: null,
    );
    return response
        .map((item) => AiRecommendation.fromJson(_asJson(item)))
        .toList();
  }

  Future<AiRecommendation> updateAiRecommendation(
    String id, {
    required String status,
    String? title,
    String? description,
  }) async =>
      AiRecommendation.fromJson(
        await _patch<Map<String, dynamic>>(
          '/ai/recommendations/$id',
          data: {
            'status': status,
            if (title != null) 'title': title,
            if (description != null) 'description': description,
          },
        ),
      );

  Future<String> chatWithAi(String message) async {
    final response = await _post<Map<String, dynamic>>(
      '/ai/chat',
      data: {'message': message},
    );
    return response['reply'] as String? ?? '';
  }

  Future<MlOverview> getMlOverview() async {
    final results = await Future.wait([
      _get<Map<String, dynamic>>('/ml/learning-profile'),
      _get<Map<String, dynamic>>('/ml/behavior'),
      _get<Map<String, dynamic>>('/ml/performance'),
      _get<Map<String, dynamic>>('/ml/recommendations'),
    ]);
    return MlOverview(
      profile: results[0],
      behavior: results[1],
      performance: results[2],
      recommendations: results[3],
    );
  }

  Future<void> createStudySession({
    required DateTime startedAt,
    required DateTime endedAt,
    int? focusRating,
  }) async {
    await _post<Map<String, dynamic>>(
      '/study-sessions',
      data: {
        'started_at': startedAt.toUtc().toIso8601String(),
        'ended_at': endedAt.toUtc().toIso8601String(),
        if (focusRating != null) 'focus_rating': focusRating,
      },
    );
  }

  Future<String> registerDevice({
    required String fcmToken,
    required String platform,
    String? deviceName,
  }) async {
    final response = await _post<Map<String, dynamic>>(
      '/users/me/devices',
      data: {
        'fcm_token': fcmToken,
        'platform': platform,
        if (deviceName != null) 'device_name': deviceName,
      },
    );
    return response['id'] as String;
  }

  Future<void> unregisterDevice(String deviceId) async {
    await _delete('/users/me/devices/$deviceId');
  }

  Future<void> sendTestNotification() async {
    await _post<Map<String, dynamic>>('/notifications/test', data: null);
  }

  // ----- Événements, calendrier et notifications -------------------------

  Future<List<StudyEvent>> getEvents() async {
    final response = await _get<List<dynamic>>('/events');
    return response.map((item) => StudyEvent.fromJson(_asJson(item))).toList();
  }

  Future<StudyEvent> getEvent(String id) async =>
      StudyEvent.fromJson(await _get<Map<String, dynamic>>('/events/$id'));

  Future<StudyEvent> createEvent(StudyEvent event, {bool force = false}) async {
    final response = await _post<Map<String, dynamic>>(
      force ? '/events?force=true' : '/events',
      data: event.toPayload(),
    );
    return StudyEvent.fromJson(response);
  }

  Future<StudyEvent> updateEvent(StudyEvent event, {bool force = false}) async {
    final response = await _put<Map<String, dynamic>>(
      force ? '/events/${event.id}?force=true' : '/events/${event.id}',
      data: event.toPayload(),
    );
    return StudyEvent.fromJson(response);
  }

  Future<void> deleteEvent(String id) async {
    await _delete('/events/$id');
  }

  Future<List<EventConflictInfo>> checkEventConflicts({
    required DateTime startsAt,
    required String eventType,
    DateTime? endsAt,
    String? excludeId,
  }) async {
    final path = Uri(path: '/events/conflicts', queryParameters: {
      'starts_at': startsAt.toUtc().toIso8601String(),
      if (endsAt != null) 'ends_at': endsAt.toUtc().toIso8601String(),
      'event_type': eventType,
      if (excludeId != null) 'exclude_id': excludeId,
    }).toString();
    final response = await _get<Map<String, dynamic>>(path);
    return (response['conflicts'] as List<dynamic>)
        .map((item) => EventConflictInfo.fromJson(_asJson(item)))
        .toList();
  }

  Future<List<CalendarItem>> getCalendar(DateTime from, DateTime to) async {
    final path = Uri(path: '/calendar', queryParameters: {
      'from': from.toUtc().toIso8601String(),
      'to': to.toUtc().toIso8601String(),
    }).toString();
    final response = await _get<List<dynamic>>(path);
    return response
        .map((item) => CalendarItem.fromJson(_asJson(item)))
        .toList();
  }

  Future<EventDraft> parseEventText(String text) async {
    final response = await _post<Map<String, dynamic>>(
      '/ai/events/parse',
      data: {
        'text': text,
        'utc_offset_minutes': DateTime.now().timeZoneOffset.inMinutes,
      },
    );
    return EventDraft.fromJson(response);
  }

  Future<List<PlaceSuggestion>> autocompletePlaces(
    String query, {
    String? sessionToken,
  }) async {
    final path = Uri(path: '/places/autocomplete', queryParameters: {
      'q': query,
      if (sessionToken != null) 'session_token': sessionToken,
    }).toString();
    final response = await _get<List<dynamic>>(path);
    return response
        .map((item) => PlaceSuggestion.fromJson(_asJson(item)))
        .toList();
  }

  Future<PlaceDetails> getPlaceDetails(String placeId) async {
    final path = Uri(
      path: '/places/details',
      queryParameters: {'place_id': placeId},
    ).toString();
    return PlaceDetails.fromJson(await _get<Map<String, dynamic>>(path));
  }

  Future<List<AppNotification>> getNotifications({
    bool unreadOnly = false,
    String? type,
    int limit = 50,
  }) async {
    final path = Uri(path: '/notifications', queryParameters: {
      'limit': '$limit',
      if (unreadOnly) 'unread_only': 'true',
      if (type != null) 'type': type,
    }).toString();
    final response = await _get<List<dynamic>>(path);
    return response
        .map((item) => AppNotification.fromJson(_asJson(item)))
        .toList();
  }

  Future<int> getUnreadNotificationCount() async {
    final response =
        await _get<Map<String, dynamic>>('/notifications/unread-count');
    return response['count'] as int;
  }

  Future<void> markNotificationRead(String id) async {
    await _put<Map<String, dynamic>>('/notifications/$id/read', data: null);
  }

  Future<void> markAllNotificationsRead() async {
    await _put<Map<String, dynamic>>('/notifications/read-all', data: null);
  }

  Future<void> deleteNotification(String id) async {
    await _delete('/notifications/$id');
  }

  Future<void> logoutAllSessions() async {
    await _post<dynamic>('/auth/logout-all', data: null);
  }

  Future<T> _get<T>(String path) async {
    try {
      final response = await _dio.get<T>(
        path,
        options: await _authorizedOptions(),
      );
      return response.data as T;
    } on DioException catch (error) {
      throw _toApiException(error);
    }
  }

  Future<T> _post<T>(String path, {required Object? data}) async {
    try {
      final response = await _dio.post<T>(
        path,
        data: data,
        options: await _authorizedOptions(),
      );
      return response.data as T;
    } on DioException catch (error) {
      throw _toApiException(error);
    }
  }

  Future<T> _patch<T>(String path, {required Object? data}) async {
    try {
      final response = await _dio.patch<T>(
        path,
        data: data,
        options: await _authorizedOptions(),
      );
      return response.data as T;
    } on DioException catch (error) {
      throw _toApiException(error);
    }
  }

  Future<T> _put<T>(String path, {required Object? data}) async {
    try {
      final response = await _dio.put<T>(
        path,
        data: data,
        options: await _authorizedOptions(),
      );
      return response.data as T;
    } on DioException catch (error) {
      throw _toApiException(error);
    }
  }

  Future<void> _delete(String path) async {
    try {
      await _dio.delete<void>(
        path,
        options: await _authorizedOptions(),
      );
    } on DioException catch (error) {
      throw _toApiException(error);
    }
  }

  Future<Options> _authorizedOptions() async {
    final tokenProvider = _tokenProvider;
    if (tokenProvider == null) {
      throw const StudyMateApiException(
        'Connecte-toi avec Firebase pour synchroniser tes données.',
      );
    }
    final String? token;
    try {
      token = await tokenProvider();
    } catch (_) {
      // Hors ligne, Firebase ne peut pas renouveler un jeton expiré.
      throw const StudyMateApiException(
        'Impossible de vérifier ta session sans connexion.',
        isNetworkError: true,
      );
    }
    if (token == null || token.isEmpty) {
      throw const StudyMateApiException(
        'La session Firebase a expiré. Reconnecte-toi.',
      );
    }
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  StudyMateApiException _toApiException(DioException error) {
    final responseData = error.response?.data;
    if (responseData is Map<String, dynamic>) {
      final detail = responseData['detail'];
      final code = responseData['code'];
      if (detail is String && detail.isNotEmpty) {
        return StudyMateApiException(
          detail,
          code: code is String ? code : null,
          statusCode: error.response?.statusCode,
        );
      }
    }

    if (error.response?.statusCode == 401) {
      return const StudyMateApiException(
        'Session expirée. Reconnecte-toi pour continuer.',
        statusCode: 401,
      );
    }

    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.connectionError =>
        StudyMateApiException(
          'API inaccessible à ${ApiConfig.baseUrl}. Vérifie que le backend '
          'est démarré et que l’URL est correcte.',
          isNetworkError: true,
        ),
      _ when error.response == null => StudyMateApiException(
          'Connexion au serveur impossible. Réessaie dans un instant.',
          isNetworkError: true,
        ),
      _ => StudyMateApiException(
          'La requête a échoué${error.response?.statusCode == null ? '' : ' '
              '(${error.response!.statusCode})'}. Réessaie dans un instant.',
          statusCode: error.response?.statusCode,
        ),
    };
  }

  /// Requête brute utilisée par la synchronisation hors ligne.
  Future<Map<String, dynamic>?> syncRequest(
    String method,
    String path, {
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await _dio.request<dynamic>(
        path,
        data: data,
        options: (await _authorizedOptions()).copyWith(method: method),
      );
      final body = response.data;
      return body is Map<String, dynamic> ? body : null;
    } on DioException catch (error) {
      throw _toApiException(error);
    }
  }

  Map<String, dynamic> _asJson(Object? value) {
    if (value is Map<String, dynamic>) return value;
    throw const StudyMateApiException(
      'Le backend a renvoyé un format de données inattendu.',
    );
  }
}
