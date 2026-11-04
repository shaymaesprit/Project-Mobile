import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/config/firebase_config.dart';

class StudyMateAuthService {
  StudyMateAuthService._();

  static Future<void>? _googleSignInInitialization;

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
