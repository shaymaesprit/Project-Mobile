import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'auth_widgets.dart';
import 'study_mate_auth_service.dart';

/// Shown to password-based accounts until their email address is verified.
class EmailVerificationPage extends StatefulWidget {
  const EmailVerificationPage({
    super.key,
    required this.auth,
    required this.email,
    required this.onVerified,
  });

  final FirebaseAuth auth;
  final String email;

  /// Called once the account is verified so the auth gate can rebuild.
  final VoidCallback onVerified;

  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  static const _cooldown = Duration(seconds: 30);

  Timer? _poll;
  Timer? _cooldownTimer;
  bool _checking = false;
  bool _sending = false;
  int _secondsLeft = 0;
  String? _message;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _check(silent: true),
    );
  }

  @override
  void dispose() {
    _poll?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _check({bool silent = false}) async {
    if (_checking) return;
    _checking = true;
    if (!silent) setState(() {});
    try {
      final verified =
          await StudyMateAuthService.refreshEmailVerification(widget.auth);
      if (!mounted) return;
      if (verified) {
        _poll?.cancel();
        widget.onVerified();
        return;
      }
      if (!silent) {
        setState(() {
          _isError = true;
          _message = 'Ton email n’est pas encore vérifié.';
        });
      }
    } catch (error) {
      if (!mounted || silent) return;
      setState(() {
        _isError = true;
        _message = StudyMateAuthService.messageFor(error);
      });
    } finally {
      _checking = false;
      if (mounted && !silent) setState(() {});
    }
  }

  Future<void> _resend() async {
    final user = widget.auth.currentUser;
    if (user == null) return;
    setState(() {
      _sending = true;
      _message = null;
    });
    try {
      await StudyMateAuthService.resendVerificationEmail(user);
      if (!mounted) return;
      setState(() {
        _isError = false;
        _message = 'Email de vérification renvoyé à ${widget.email}.';
        _secondsLeft = _cooldown.inSeconds;
      });
      _cooldownTimer?.cancel();
      _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted || _secondsLeft <= 1) {
          timer.cancel();
          if (mounted) setState(() => _secondsLeft = 0);
          return;
        }
        setState(() => _secondsLeft--);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isError = true;
        _message = StudyMateAuthService.messageFor(error);
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AuthScaffold(
      title: 'Vérifie ton email',
      subtitle: 'Nous avons envoyé un lien de vérification à ${widget.email}. '
          'Ouvre-le puis reviens ici.',
      children: [
        const Icon(Icons.mark_email_unread_outlined, size: 56),
        const SizedBox(height: 20),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _message!,
              textAlign: TextAlign.center,
              style: TextStyle(color: _isError ? colors.error : colors.primary),
            ),
          ),
        AuthSubmitButton(
          label: 'J’ai vérifié mon email',
          loading: _checking,
          onPressed: _check,
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _sending || _secondsLeft > 0 ? null : _resend,
          child: Text(
            _secondsLeft > 0
                ? 'Renvoyer l’email (${_secondsLeft}s)'
                : 'Renvoyer l’email de vérification',
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => StudyMateAuthService.signOut(widget.auth),
          child: const Text('Utiliser un autre compte'),
        ),
      ],
    );
  }
}
