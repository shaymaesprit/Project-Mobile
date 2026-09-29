import 'api_client.dart';

/// API boundary for replacing the in-memory demo data with Spring Boot.
/// Suggested routes: /api/auth, /api/courses, /api/tasks, /api/notes, /api/events, /api/notifications.
class StudyRepository {
  StudyRepository(this.api);
  final ApiClient api;

  Future<dynamic> signIn(String email, String password) => api.request('POST', '/api/auth/login', body: {'email': email, 'password': password});
  Future<dynamic> register(Map<String, dynamic> profile) => api.request('POST', '/api/auth/register', body: profile);
  Future<dynamic> courses() => api.request('GET', '/api/courses');
  Future<dynamic> tasks() => api.request('GET', '/api/tasks');
  Future<dynamic> notes() => api.request('GET', '/api/notes');
  Future<dynamic> events() => api.request('GET', '/api/events');
  Future<dynamic> notifications() => api.request('GET', '/api/notifications');
  Future<dynamic> create(String collection, Map<String, dynamic> data) => api.request('POST', '/api/$collection', body: data);
  Future<dynamic> update(String collection, String id, Map<String, dynamic> data) => api.request('PUT', '/api/$collection/$id', body: data);
  Future<dynamic> delete(String collection, String id) => api.request('DELETE', '/api/$collection/$id');
}
