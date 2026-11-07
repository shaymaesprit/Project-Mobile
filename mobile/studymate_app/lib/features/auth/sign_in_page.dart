import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../data/services/studymate_api.dart';
import 'auth_validators.dart';
import 'auth_widgets.dart';
import 'forgot_password_page.dart';
import 'register_page.dart';
import 'study_mate_auth_service.dart';

/// Entry screen for unauthenticated users: email/password and Google login,
/// with links to registration and password recovery.
class SignInPage extends StatefulWidget {
  const SignInPage({super.key, required this.auth, required this.api});

  final FirebaseAuth auth;
  final StudyMateApi api;

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signInWithEmail() async {
    if (!_formKey.currentState!.validate()) return;
    await _run(
      () => StudyMateAuthService.signInWithEmail(
        widget.auth,
        email: _emailController.text,
        password: _passwordController.text,
      ),
    );
  }

  Future<void> _signInWithGoogle() =>
      _run(() => StudyMateAuthService.signInWithGoogle(widget.auth));

  Future<void> _run(Future<Object?> Function() action) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await action();
      // On success the auth gate replaces this page.
      if (mounted) setState(() => _loading = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = StudyMateAuthService.messageFor(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) => AuthScaffold(
        title: 'Bienvenue sur StudyMate',
        subtitle: 'Connecte-toi pour retrouver tes cours, tâches et notes.',
        children: [
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _emailController,
                  enabled: !_loading,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  validator: AuthValidators.email,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.mail_outline),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                PasswordField(
                  controller: _passwordController,
                  label: 'Mot de passe',
                  enabled: !_loading,
                  validator: AuthValidators.currentPassword,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  onSubmitted: _signInWithEmail,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _loading
                        ? null
                        : () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => ForgotPasswordPage(
                                  auth: widget.auth,
                                  initialEmail: _emailController.text,
                                ),
                              ),
                            ),
                    child: const Text('Mot de passe oublié ?'),
                  ),
                ),
                AuthErrorText(_error),
                AuthSubmitButton(
                  label: 'Se connecter',
                  loading: _loading,
                  onPressed: _signInWithEmail,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Row(
            children: [
              Expanded(child: Divider()),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('ou'),
              ),
              Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _loading ? null : _signInWithGoogle,
            icon: const Icon(Icons.account_circle_outlined),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text('Continuer avec Google'),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _loading
                ? null
                : () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => RegisterPage(
                          auth: widget.auth,
                          api: widget.api,
                        ),
                      ),
                    ),
            child: const Text('Pas encore de compte ? Créer un compte'),
          ),
        ],
      );
}
