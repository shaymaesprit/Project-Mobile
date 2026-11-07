import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../../data/services/studymate_api.dart';
import '../../state/study_controller.dart';

/// Privacy, permissions and session settings.
class PrivacySettingsPage extends StatefulWidget {
  const PrivacySettingsPage({
    super.key,
    required this.controller,
    this.onSignOut,
  });

  final StudyController controller;
  final Future<void> Function()? onSignOut;

  @override
  State<PrivacySettingsPage> createState() => _PrivacySettingsPageState();
}

class _PrivacySettingsPageState extends State<PrivacySettingsPage> {
  StudyMateApi get _api => widget.controller.api;

  bool? _aiConsent;
  bool _notificationsOn = false;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final consent = await _api.getAiConsent();
      var notifications = widget.controller.push?.isRegistered ?? false;
      final push = widget.controller.push;
      if (push != null && !notifications) {
        final status = await push.permissionStatus();
        notifications = false;
        if (status == AuthorizationStatus.denied) {
          _error = 'Les notifications sont refusées dans les réglages du '
              'système.';
        }
      }
      if (!mounted) return;
      setState(() {
        _aiConsent = consent.granted;
        _notificationsOn = notifications;
      });
    } on StudyMateApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Réglages indisponibles.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } on StudyMateApiException catch (error) {
      _snack(error.message);
    } catch (_) {
      _snack('Action impossible pour le moment.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setConsent(bool value) => _run(() async {
        final consent = await _api.setAiConsent(value);
        await widget.controller.refreshProfile();
        if (mounted) setState(() => _aiConsent = consent.granted);
      });

  Future<void> _setNotifications(bool value) => _run(() async {
        final push = widget.controller.push;
        if (push == null) return;
        if (value) {
          final granted = await push.enable();
          if (!granted) {
            _snack('Autorisation de notification refusée.');
            return;
          }
        } else {
          await push.disable();
        }
        if (mounted) setState(() => _notificationsOn = value);
      });

  Future<void> _sendTest() => _run(() async {
        await _api.sendTestNotification();
        _snack('Notification de test envoyée.');
      });

  Future<void> _logoutAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Se déconnecter partout ?'),
        content: const Text(
          'Toutes tes sessions, y compris sur d’autres appareils, seront '
          'fermées. Tu devras te reconnecter.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    var done = false;
    await _run(() async {
      await _api.logoutAllSessions();
      done = true;
    });
    if (!done || !mounted) return;
    final navigator = Navigator.of(context);
    await widget.onSignOut?.call();
    navigator.popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Confidentialité et réglages')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  Card(
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: const Text('Assistant IA'),
                          subtitle: const Text(
                            'Autorise l’utilisation de données anonymisées '
                            'pour générer des conseils. Retirable à tout '
                            'moment.',
                          ),
                          value: _aiConsent ?? false,
                          onChanged:
                              _busy || _aiConsent == null ? null : _setConsent,
                        ),
                        SwitchListTile(
                          title: const Text('Notifications'),
                          subtitle: const Text(
                            'Rappels de tâches, d’évaluations et de révisions '
                            'sur cet appareil.',
                          ),
                          value: _notificationsOn,
                          onChanged: _busy ||
                                  widget.controller.push == null
                              ? null
                              : _setNotifications,
                        ),
                        if (_notificationsOn)
                          ListTile(
                            leading: const Icon(Icons.notifications_active),
                            title: const Text('Envoyer une notification de test'),
                            onTap: _busy ? null : _sendTest,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Card(
                    child: ListTile(
                      leading: Icon(
                        Icons.logout,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      title: const Text('Se déconnecter de tous les appareils'),
                      subtitle: const Text(
                        'Révoque toutes les sessions ouvertes de ton compte.',
                      ),
                      onTap: _busy ? null : _logoutAll,
                    ),
                  ),
                ],
              ),
      );
}
