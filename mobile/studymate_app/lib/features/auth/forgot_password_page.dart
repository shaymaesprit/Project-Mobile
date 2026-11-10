import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'auth_validators.dart';
import 'auth_widgets.dart';
import 'study_mate_auth_service.dart';

/// Sends a password reset email through Firebase Authentication.
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({
    super.key,
    required this.auth,
    this.initialEmail = '',
  });

  final FirebaseAuth auth;
  final String initialEmail;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController =
      TextEditingController(text: widget.initialEmail.trim());
  bool _loading = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await StudyMateAuthService.sendPasswordReset(
        widget.auth,
        _emailController.text,
      );
      if (mounted) setState(() => _sent = true);
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      // Do not reveal whether an account exists for this address.
      if (error.code == 'user-not-found') {
        setState(() => _sent = true);
      } else {
        setState(() => _error = StudyMateAuthService.messageFor(error));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => AuthScaffold(
        showBack: true,
        title: 'Mot de passe oublié',
        subtitle: 'Saisis ton email pour recevoir un lien de réinitialisation.',
        children: [
          if (_sent) ...[
            const Icon(Icons.mark_email_read_outlined, size: 48),
            const SizedBox(height: 12),
            Text(
              'Si un compte existe pour ${_emailController.text.trim()}, '
              'un email de réinitialisation vient d’être envoyé. '
              'Pense à vérifier tes courriers indésirables.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Retour à la connexion'),
            ),
          ] else
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _emailController,
                    enabled: !_loading,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.email],
                    validator: AuthValidators.email,
                    onFieldSubmitted: (_) => _submit(),
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.mail_outline),
                    ),
                  ),
                  const SizedBox(height: 16),
                  AuthErrorText(_error),
                  AuthSubmitButton(
                    label: 'Envoyer le lien',
                    loading: _loading,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
        ],
      );
}
