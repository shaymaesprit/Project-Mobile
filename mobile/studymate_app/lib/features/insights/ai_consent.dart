import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/services/studymate_api.dart';

/// Vérifie que l'étudiant a autorisé l'IA ; sinon, lui explique ce qui sera
/// envoyé ([purpose]) et lui demande son accord. Renvoie `true` si autorisé.
Future<bool> ensureAiConsent(
  BuildContext context,
  StudyMateApi api, {
  required String purpose,
}) async {
  if ((await api.getAiConsent()).granted) return true;
  if (!context.mounted) return false;
  final accepted = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.auto_awesome_rounded, color: AppPalette.violet),
      title: const Text('Autoriser l’IA ?'),
      content: Text(
        '$purpose Les adresses e-mail et numéros de téléphone sont masqués '
        'avant l’envoi. Tu peux retirer cette autorisation à tout moment dans '
        'Profil → Confidentialité.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Plus tard'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Autoriser'),
        ),
      ],
    ),
  );
  if (accepted != true) return false;
  return (await api.setAiConsent(true)).granted;
}
