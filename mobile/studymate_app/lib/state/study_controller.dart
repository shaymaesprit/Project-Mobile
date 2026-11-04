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
  List<StudyTask> _tasks = const [];
  List<StudyNote> _notes = const [];

  bool _hasBackendSession = false;
  bool _isLoading = false;
  bool _isProfileLoading = false;
  String? _errorMessage;
  String? _profileErrorMessage;
  StudyMateUserProfile? _userProfile;
  StudentProfile? _studentProfile;
  DateTime? _lastSyncedAt;

  List<StudyCourse> get courses => List.unmodifiable(_courses);
  List<StudyTask> get tasks => List.unmodifiable(_tasks);
  List<StudyNote> get notes => List.unmodifiable(_notes);
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
    _tasks = const [];
    _notes = const [];
    notifyListeners();

    try {
      await _api.checkHealth();
      _userProfile = await _api.getCurrentUser();
      final results = await Future.wait([
        _api.getCourses(),
        _api.getTasks(),
        _api.getNotes(),
        _api.getStudentProfile(),
      ]);
      _courses = results[0] as List<StudyCourse>;
      _tasks = results[1] as List<StudyTask>;
      _notes = results[2] as List<StudyNote>;
      _studentProfile = results[3] as StudentProfile;
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
  }) async {
    _requireBackendSession();
    try {
      final course = await _api.createCourse(
        title: title,
        code: code,
        professor: professor,
        room: room,
      );
      _courses = [course, ..._courses];
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

  void _clearAccountData() {
    _hasBackendSession = false;
    _isLoading = false;
    _isProfileLoading = false;
    _errorMessage = null;
    _profileErrorMessage = null;
    _userProfile = null;
    _studentProfile = null;
    _courses = const [];
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

  void _setError(StudyMateApiException error) {
    _errorMessage = error.message;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }
}
