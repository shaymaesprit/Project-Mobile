import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/config/firebase_config.dart';

class StudyMateAuthService {
  StudyMateAuthService._();

  static Future<void>? _googleSignInInitialization;

  static Future<UserCredential> signInWithEmail(
    FirebaseAuth auth, {
    required String email,
    required String password,
  }) =>
      auth.signInWithEmailAndPassword(email: email.trim(), password: password);

  /// Creates the Firebase account, stores the display name and sends the
  /// verification email. Passwords go only to Firebase Authentication.
  static Future<User> registerWithEmail(
    FirebaseAuth auth, {
    required String email,
    required String password,
    required String displayName,
  }) async {
    final credential = await auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user!;
    await user.updateDisplayName(displayName.trim());
    await user.sendEmailVerification();
    return user;
  }

  static Future<void> sendPasswordReset(FirebaseAuth auth, String email) =>
      auth.sendPasswordResetEmail(email: email.trim());

  static Future<void> resendVerificationEmail(User user) =>
      user.sendEmailVerification();

  /// Reloads the user and refreshes the ID token so that the backend sees the
  /// up-to-date `email_verified` claim. Returns the verification status.
  static Future<bool> refreshEmailVerification(FirebaseAuth auth) async {
    final user = auth.currentUser;
    if (user == null) return false;
    await user.reload();
    final refreshed = auth.currentUser;
    if (refreshed != null && refreshed.emailVerified) {
      await refreshed.getIdToken(true);
      return true;
    }
    return false;
  }

  /// Re-authenticates with the current password, then sets the new one.
  static Future<void> changePassword(
    FirebaseAuth auth, {
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw FirebaseAuthException(code: 'no-current-user');
    }
    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: email, password: currentPassword),
    );
    await user.updatePassword(newPassword);
  }

  static bool usesPassword(User user) =>
      user.providerData.any((info) => info.providerId == 'password');

  /// Whether the user must verify an email address before using the app.
  static bool needsEmailVerification(User user) =>
      usesPassword(user) && !user.emailVerified;

  static Future<UserCredential> signInWithGoogle(FirebaseAuth auth) async {
    await _ensureGoogleSignInInitialized();
    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-google-id-token',
        message: 'Google n’a pas fourni de jeton d’identification.',
      );
    }

    return auth.signInWithCredential(
      GoogleAuthProvider.credential(idToken: idToken),
    );
  }

  static Future<void> signOut(FirebaseAuth auth) async {
    final googleInitialization = _googleSignInInitialization;
    if (googleInitialization != null) {
      await googleInitialization;
      await GoogleSignIn.instance.signOut();
    }
    await auth.signOut();
  }

  /// Converts an authentication error into a user-facing French message.
  /// Returns `null` when the user simply cancelled (nothing to display).
  static String? messageFor(Object error) {
    if (error is GoogleSignInException) {
      if (error.code == GoogleSignInExceptionCode.canceled) return null;
      return error.description ?? 'La connexion Google a échoué.';
    }
    if (error is FirebaseAuthException) {
      return switch (error.code) {
        'invalid-credential' ||
        'wrong-password' ||
        'user-not-found' =>
          'Email ou mot de passe incorrect.',
        'invalid-email' => 'L’adresse email est invalide.',
        'user-disabled' => 'Ce compte a été désactivé.',
        'email-already-in-use' =>
          'Un compte existe déjà avec cet email. Connecte-toi à la place.',
        'account-exists-with-different-credential' =>
          'Un compte existe déjà avec cet email via une autre méthode de '
              'connexion.',
        'weak-password' => 'Le mot de passe est trop faible.',
        'too-many-requests' =>
          'Trop de tentatives. Réessaie dans quelques minutes.',
        'network-request-failed' =>
          'Connexion impossible. Vérifie ta connexion internet.',
        'requires-recent-login' =>
          'Reconnecte-toi puis réessaie cette opération.',
        'operation-not-allowed' =>
          'Cette méthode de connexion n’est pas activée dans Firebase.',
        'missing-google-id-token' ||
        'missing-google-server-client-id' =>
          error.message ?? 'La configuration Google est incomplète.',
        _ => 'Une erreur d’authentification est survenue (${error.code}).',
      };
    }
    return 'Une erreur inattendue est survenue.';
  }

  static Future<void> _ensureGoogleSignInInitialized() {
    final existing = _googleSignInInitialization;
    if (existing != null) return existing;

    final serverClientId = StudyMateFirebaseConfig.googleServerClientId;
    if (serverClientId.isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-google-server-client-id',
        message:
            'Configure l’identifiant OAuth Web de Google dans le lancement Flutter.',
      );
    }

    final initialization = GoogleSignIn.instance.initialize(
      serverClientId: serverClientId,
    );
    _googleSignInInitialization = initialization;
    return initialization;
  }
}
