import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/study_models.dart';
import '../models/student_profile.dart';

class StudentRepository {
  StudentRepository(this._client);

  final SupabaseClient _client;

  String get _userId {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('A signed-in student is required.');
    return user.id;
  }

  Future<StudentProfile> fetchProfile() async {
    final row = await _client
        .from('profiles')
        .select()
        .eq('id', _userId)
        .single();
    final profile = StudentProfile.fromJson(row);
    final photoPath = profile.photoUrl;
    if (photoPath == null || photoPath.isEmpty) return profile;
    final signedUrl =
        await _client.storage.from('profile-photos').createSignedUrl(
              photoPath,
              const Duration(days: 7).inSeconds,
            );
    return StudentProfile(
      id: profile.id,
      firstName: profile.firstName,
      lastName: profile.lastName,
      email: profile.email,
      university: profile.university,
      level: profile.level,
      specialty: profile.specialty,
      phone: profile.phone,
      photoUrl: signedUrl,
    );
  }

  Future<StudentProfile> updateProfile({
    required String firstName,
    required String lastName,
    required String email,
    required String university,
    required String level,
    required String specialty,
    String? phone,
  }) async {
    final updated = await _client
        .from('profiles')
        .update({
          'prenom': firstName.trim(),
          'nom': lastName.trim(),
          'email': email.trim(),
          'universite': university.trim(),
          'niveau': level.trim(),
          'specialite': specialty.trim(),
          'telephone': phone?.trim(),
        })
        .eq('id', _userId)
        .select()
        .single();
    return StudentProfile.fromJson(updated);
  }

  Future<StudentProfile> uploadProfilePhoto(XFile image) async {
    final userId = _userId;
    final extension = image.name.split('.').last.toLowerCase();
    const allowed = {'jpg', 'jpeg', 'png', 'webp'};
    if (!allowed.contains(extension)) {
      throw const FormatException('Choose a JPG, PNG, or WebP image.');
    }
    final bytes = await image.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) {
      throw const FormatException('Profile photos must be 5 MB or smaller.');
    }
    final path = '$userId/profile.$extension';
    final contentType = switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      _ => 'image/webp',
    };
    await _client.storage.from('profile-photos').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: true,
          ),
        );
    await _client
        .from('profiles')
        .update({'photo_url': path})
        .eq('id', userId);
    return fetchProfile();
  }

  Future<StudentProfile> removeProfilePhoto() async {
    final profile = await fetchProfile();
    final photoPath = profile.photoUrl;
    if (photoPath != null && photoPath.isNotEmpty) {
      await _client.storage.from('profile-photos').remove([photoPath]);
      await _client
          .from('profiles')
          .update({'photo_url': null})
          .eq('id', _userId);
    }
    return fetchProfile();
  }
}

class CourseRepository {
  CourseRepository(this._client);

  final SupabaseClient _client;

  Future<List<Course>> fetchCourses() async {
    final rows = await _client
        .from('courses')
        .select()
        .order('jour')
        .order('heure_debut');
    return rows.map((row) => _courseFromJson(row)).toList();
  }

  Future<Course> createCourse(Course course) async {
    try {
      final row = await _client
          .from('courses')
          .insert(_courseToJson(course))
          .select()
          .single();
      return _courseFromJson(row);
    } on PostgrestException catch (error) {
      if (error.code == '23P01') {
        throw const CourseScheduleConflictException();
      }
      rethrow;
    }
  }

  Future<Course> updateCourse(Course course) async {
    try {
      final row = await _client
          .from('courses')
          .update(_courseToJson(course))
          .eq('id', course.id)
          .select()
          .single();
      return _courseFromJson(row);
    } on PostgrestException catch (error) {
      if (error.code == '23P01') {
        throw const CourseScheduleConflictException();
      }
      rethrow;
    }
  }

  Future<void> deleteCourse(String id) async {
    await _client.from('courses').delete().eq('id', id);
  }
}

class CourseScheduleConflictException implements Exception {
  const CourseScheduleConflictException();

  @override
  String toString() =>
      'This course overlaps another course in your schedule.';
}

Map<String, dynamic> _courseToJson(Course course) => {
      'nom_cours': course.name.trim(),
      'code_cours': course.code.trim(),
      'description': '',
      'professeur': course.professor.trim(),
      'salle': course.room.trim(),
      'type_cours': switch (course.type) {
        CourseType.lecture => 'Cours',
        CourseType.td => 'TD',
        CourseType.tp => 'TP',
      },
      'jour': course.day,
      'heure_debut': '${course.start}:00',
      'heure_fin': '${course.end}:00',
      'semestre': course.semester.trim(),
      'couleur': course.color,
    };

Course _courseFromJson(Map<String, dynamic> row) {
  final type = switch (row['type_cours'] as String) {
    'TD' => CourseType.td,
    'TP' => CourseType.tp,
    _ => CourseType.lecture,
  };
  return Course(
    id: row['id'] as String,
    name: row['nom_cours'] as String,
    code: row['code_cours'] as String? ?? '',
    professor: row['professeur'] as String? ?? '',
    room: row['salle'] as String? ?? '',
    type: type,
    day: row['jour'] as String,
    start: (row['heure_debut'] as String).substring(0, 5),
    end: (row['heure_fin'] as String).substring(0, 5),
    semester: row['semestre'] as String? ?? '',
    color: (row['couleur'] as num?)?.toInt() ?? 0xFF006D77,
  );
}
