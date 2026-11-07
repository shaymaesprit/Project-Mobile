import 'package:firebase_core/firebase_core.dart';

class StudyMateFirebaseConfig {
  const StudyMateFirebaseConfig._();

  static const _apiKey = String.fromEnvironment('STUDYMATE_FIREBASE_API_KEY');
  static const _appId = String.fromEnvironment(
    'STUDYMATE_FIREBASE_APP_ID',
    defaultValue: '1:406992456210:android:f0189e87cc8c19f67a26cb',
  );
  static const _projectId = String.fromEnvironment(
    'STUDYMATE_FIREBASE_PROJECT_ID',
    defaultValue: 'studymate-8930d',
  );
  static const _messagingSenderId = String.fromEnvironment(
    'STUDYMATE_FIREBASE_SENDER_ID',
    defaultValue: '406992456210',
  );
  static const _authDomain =
      String.fromEnvironment('STUDYMATE_FIREBASE_AUTH_DOMAIN');
  static const _storageBucket =
      String.fromEnvironment('STUDYMATE_FIREBASE_STORAGE_BUCKET');
  static String? get storageBucket =>
      _storageBucket.isEmpty ? null : _storageBucket;
  static const googleServerClientId =
      String.fromEnvironment('STUDYMATE_GOOGLE_SERVER_CLIENT_ID');

  // Cloudinary config for profile photo uploads
  static const cloudinaryCloudName =
      String.fromEnvironment('STUDYMATE_CLOUDINARY_CLOUD_NAME');
  static const cloudinaryApiKey =
      String.fromEnvironment('STUDYMATE_CLOUDINARY_API_KEY');
  static const cloudinaryApiSecret =
      String.fromEnvironment('STUDYMATE_CLOUDINARY_API_SECRET');
  static bool get cloudinaryConfigured =>
      cloudinaryCloudName.isNotEmpty && cloudinaryApiKey.isNotEmpty && cloudinaryApiSecret.isNotEmpty;

  static bool get isConfigured =>
      _apiKey.isNotEmpty &&
      _appId.isNotEmpty &&
      _projectId.isNotEmpty &&
      _messagingSenderId.isNotEmpty;

  static List<String> get missingOptions => [
        if (_apiKey.isEmpty) 'STUDYMATE_FIREBASE_API_KEY',
        if (_appId.isEmpty) 'STUDYMATE_FIREBASE_APP_ID',
        if (_projectId.isEmpty) 'STUDYMATE_FIREBASE_PROJECT_ID',
        if (_messagingSenderId.isEmpty) 'STUDYMATE_FIREBASE_SENDER_ID',
      ];

  static FirebaseOptions? get options {
    if (!isConfigured) return null;
    return FirebaseOptions(
      apiKey: _apiKey,
      appId: _appId,
      projectId: _projectId,
      messagingSenderId: _messagingSenderId,
      authDomain: _authDomain.isEmpty ? null : _authDomain,
      storageBucket: _storageBucket.isEmpty ? null : _storageBucket,
    );
  }
}
