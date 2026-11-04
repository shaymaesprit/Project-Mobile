import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/config/firebase_config.dart';
import 'study_mate_auth_service.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({
    super.key,
    required this.auth,
  });

  final FirebaseAuth auth;

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isRegistering = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: colorScheme.secondaryContainer,
                          child: Icon(
                            Icons.school_rounded,
                            color: colorScheme.primary,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'StudyMate',
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _isRegistering
                              ? 'Crée ton compte pour synchroniser tes études.'
                              : 'Connecte-toi pour retrouver tes données partout.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 24),
                        if (_isRegistering) ...[
                          TextFormField(
                            controller: _displayNameController,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Nom affiché',
                              prefixIcon: Icon(Icons.person_outline),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (_isRegistering &&
                                  (value?.trim().isEmpty ?? true)) {
                                return 'Saisis ton nom.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                        ],
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Adresse e-mail',
                            prefixIcon: Icon(Icons.email_outlined),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            final email = value?.trim() ?? '';
                            if (!email.contains('@') || !email.contains('.')) {
                              return 'Saisis une adresse e-mail valide.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          autofillHints: [
                            _isRegistering
                                ? AutofillHints.newPassword
                                : AutofillHints.password,
                          ],
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            labelText: 'Mot de passe',
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              tooltip: _obscurePassword
                                  ? 'Afficher le mot de passe'
                                  : 'Masquer le mot de passe',
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if ((value ?? '').length < 6) {
                              return 'Utilise au moins 6 caractères.';
                            }
                            return null;
                          },
                        ),
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 12),
                          _AuthError(message: _errorMessage!),
                        ],
                        const SizedBox(height: 18),
                        FilledButton(
                          onPressed: _isLoading ? null : _submit,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: _isLoading
                                ? const SizedBox.square(
                                    dimension: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    _isRegistering
                                        ? 'Créer mon compte'
                                        : 'Se connecter',
                                  ),
                          ),
                        ),
                        if (!_isRegistering)
                          TextButton(
                            onPressed: _isLoading ? null : _sendPasswordReset,
                            child: const Text('Mot de passe oublié ?'),
                          ),
                        TextButton(
                          onPressed: _isLoading
                              ? null
                              : () => setState(() {
                                    _isRegistering = !_isRegistering;
                                    _errorMessage = null;
                                  }),
                          child: Text(
                            _isRegistering
                                ? 'J’ai déjà un compte · Se connecter'
                                : 'Nouveau ici ? Créer un compte',
                          ),
                        ),
                        const Divider(height: 24),
                        OutlinedButton.icon(
                          onPressed: _isLoading ? null : _signInWithGoogle,
                          icon:
                              const Icon(Icons.g_mobiledata_rounded, size: 28),
                          label: const Text('Continuer avec Google'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      if (_isRegistering) {
        final credential = await widget.auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        await credential.user?.updateDisplayName(
          _displayNameController.text.trim(),
        );
        await credential.user?.getIdToken(true);
      } else {
        await widget.auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) setState(() => _errorMessage = _firebaseMessage(error.code));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      if (StudyMateFirebaseConfig.googleServerClientId.isEmpty) {
        throw FirebaseAuthException(
          code: 'missing-google-server-client-id',
          message: 'Configure STUDYMATE_GOOGLE_SERVER_CLIENT_ID.',
        );
      }
      await StudyMateAuthService.signInWithGoogle(widget.auth);
    } on GoogleSignInException catch (error) {
      if (error.code != GoogleSignInExceptionCode.canceled && mounted) {
        setState(
          () => _errorMessage =
              error.description ?? 'La connexion Google a échoué.',
        );
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) setState(() => _errorMessage = _firebaseMessage(error.code));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendPasswordReset() async {
    final email = _emailController.text.trim();
    if (!email.contains('@')) {
      setState(
          () => _errorMessage = 'Saisis ton e-mail pour recevoir le lien.');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await widget.auth.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('E-mail de réinitialisation envoyé.')),
      );
    } on FirebaseAuthException catch (error) {
      if (mounted) setState(() => _errorMessage = _firebaseMessage(error.code));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _firebaseMessage(String code) => switch (code) {
        'email-already-in-use' =>
          'Cette adresse e-mail possède déjà un compte.',
        'invalid-email' => 'Cette adresse e-mail est invalide.',
        'invalid-credential' ||
        'wrong-password' ||
        'user-not-found' =>
          'E-mail ou mot de passe incorrect.',
        'weak-password' => 'Choisis un mot de passe plus sûr.',
        'network-request-failed' =>
          'Connexion impossible. Vérifie ton accès à Internet.',
        'operation-not-allowed' =>
          'Active la connexion par e-mail dans Firebase Console.',
        'missing-google-server-client-id' =>
          'Configure l’identifiant OAuth Web de Google pour activer cette connexion.',
        'missing-google-id-token' =>
          'Google n’a pas fourni le jeton nécessaire. Vérifie la configuration OAuth.',
        _ => 'Firebase n’a pas pu terminer la demande ($code).',
      };
}

class _AuthError extends StatelessWidget {
  const _AuthError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: TextStyle(color: colors.onErrorContainer),
      ),
    );
  }
}
