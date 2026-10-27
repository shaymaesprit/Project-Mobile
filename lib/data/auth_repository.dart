import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  Stream<AuthState> get authStateChanges =>
      _client.auth.onAuthStateChange.map((state) => state);

  User? get currentUser => _client.auth.currentUser;

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) =>
      _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String university,
    required String level,
    required String specialty,
  }) =>
      _client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {
          'prenom': firstName.trim(),
          'nom': lastName.trim(),
          'universite': university.trim(),
          'niveau': level.trim(),
          'specialite': specialty.trim(),
        },
      );

  Future<void> sendPasswordReset(String email) =>
      _client.auth.resetPasswordForEmail(email.trim());

  Future<void> signOut() => _client.auth.signOut();
}
