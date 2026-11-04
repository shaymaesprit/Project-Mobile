import 'package:dio/dio.dart';

import '../../core/config/api_config.dart';
import '../models/study_models.dart';

typedef FirebaseTokenProvider = Future<String?> Function();

class StudyMateApiException implements Exception {
  const StudyMateApiException(this.message);

  final String message;

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

  Future<void> deleteNote(String id) async {
    await _delete('/notes/$id');
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
    final token = await tokenProvider();
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
      if (detail is String && detail.isNotEmpty) {
        return StudyMateApiException(detail);
      }
    }

    if (error.response?.statusCode == 401) {
      return const StudyMateApiException(
        'Session expirée. Reconnecte-toi pour continuer.',
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
        ),
      _ => StudyMateApiException(
          'La requête a échoué${error.response?.statusCode == null ? '' : ' '
              '(${error.response!.statusCode})'}. Réessaie dans un instant.',
        ),
    };
  }

  Map<String, dynamic> _asJson(Object? value) {
    if (value is Map<String, dynamic>) return value;
    throw const StudyMateApiException(
      'Le backend a renvoyé un format de données inattendu.',
    );
  }
}
