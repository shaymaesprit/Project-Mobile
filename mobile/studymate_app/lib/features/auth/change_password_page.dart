import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'auth_validators.dart';
import 'auth_widgets.dart';
import 'study_mate_auth_service.dart';

/// Changes the password of a password-based account through Firebase
/// Authentication, after re-authenticating with the current password.
class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key, required this.auth});

  final FirebaseAuth auth;

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await StudyMateAuthService.changePassword(
        widget.auth,
        currentPassword: _current.text,
        newPassword: _new.text,
      );
      messenger.showSnackBar(
        const SnackBar(content: Text('Mot de passe modifié.')),
      );
      navigator.pop();
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
        showBack: true,
        title: 'Changer le mot de passe',
        children: [
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PasswordField(
                  controller: _current,
                  label: 'Mot de passe actuel',
                  enabled: !_loading,
                  validator: AuthValidators.currentPassword,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 14),
                PasswordField(
                  controller: _new,
                  label: 'Nouveau mot de passe',
                  enabled: !_loading,
                  validator: AuthValidators.newPassword,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newPassword],
                ),
                const SizedBox(height: 14),
                PasswordField(
                  controller: _confirm,
                  label: 'Confirmer le nouveau mot de passe',
                  enabled: !_loading,
                  validator: (v) =>
                      AuthValidators.confirmPassword(v, _new.text),
                  textInputAction: TextInputAction.done,
                  onSubmitted: _submit,
                ),
                const SizedBox(height: 16),
                AuthErrorText(_error),
                AuthSubmitButton(
                  label: 'Modifier le mot de passe',
                  loading: _loading,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ],
      );
}
