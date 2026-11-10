import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../data/models/study_models.dart';
import '../../state/study_controller.dart';
import '../insights/learning_insights_page.dart';
import '../insights/learning_profile_onboarding_page.dart';
import '../settings/privacy_settings_page.dart';
import 'edit_profile_page.dart';
import 'user_avatar.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.controller,
    required this.user,
    this.onSignOut,
  });

  final StudyController controller;
  final User? user;
  final Future<void> Function()? onSignOut;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  void initState() {
    super.initState();
  }

  Future<void> _refresh() => widget.controller.refreshProfile();

  Future<void> _open(Widget page) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => page),
    );
    if (mounted) await _refresh();
  }

  Future<void> _editProfile() async {
    final user = widget.user;
    if (user == null) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditProfilePage(
          controller: widget.controller,
          user: user,
        ),
      ),
    );
    if (saved == true && mounted) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final account = widget.controller.userProfile;
        final student = widget.controller.studentProfile;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Mon profil'),
            actions: [
              IconButton(
                tooltip: 'Actualiser',
                onPressed: widget.controller.isProfileLoading ? null : _refresh,
                icon: const Icon(Icons.refresh),
              ),
              if (account != null)
                IconButton(
                  tooltip: 'Modifier mon profil',
                  onPressed: widget.controller.isProfileLoading
                      ? null
                      : _editProfile,
                  icon: const Icon(Icons.edit_outlined),
                ),
            ],
          ),
          body: widget.user == null
              ? _loadError('Connecte-toi pour consulter ton profil.')
              : widget.controller.isProfileLoading && account == null
              ? const Center(child: CircularProgressIndicator())
              : widget.controller.profileErrorMessage != null && account == null
                  ? _loadError(widget.controller.profileErrorMessage!)
                  : account == null || student == null
                      ? _loadError('Le profil reçu de l’API est incomplet.')
                      : RefreshIndicator(
                          onRefresh: _refresh,
                          child: _profileContent(account, student),
                        ),
        );
      },
    );
  }

  Widget _loadError(String message) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 40),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );

  Widget _profileContent(
    StudyMateUserProfile account,
    StudentProfile student,
  ) =>
      ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Column(
              children: [
                UserAvatar(
                  photoUrl: account.photoUrl,
                  name: account.displayName ?? account.email,
                  radius: 48,
                  ring: true,
                ),
                const SizedBox(height: 12),
                Text(
                  account.displayName ?? 'Nom non renseigné',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                if (account.email != null) ...[
                  const SizedBox(height: 4),
                  Text(account.email!),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          _section('Études', [
            _detail('Niveau', student.studyLevel),
            _detail('Spécialité', student.specialty),
            _detail(
              'Objectif quotidien',
              '${student.dailyStudyGoalMinutes} minutes',
            ),
          ]),
          const SizedBox(height: 14),
          _section('Objectifs académiques', [
            if (student.academicGoals.isEmpty)
              const Text('Aucun objectif enregistré.')
            else
              ...student.academicGoals.map(
                (goal) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.flag_outlined),
                  title: Text(goal),
                ),
              ),
          ]),
          const SizedBox(height: 14),
          _section('Préférences d’apprentissage', [
            _detail(
              'Style préféré',
              _learningStyleLabel(student.preferredLearningStyle),
            ),
            ...student.preferences.entries
                .where((entry) => entry.key != 'ai_consent')
                .map(
              (entry) => _detail(
                _preferenceLabel(entry.key),
                entry.value is List
                    ? (entry.value as List).join(', ')
                    : entry.value.toString(),
              ),
            ),
          ]),
          const SizedBox(height: 14),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.insights_outlined),
                  title: const Text('Analyses d’apprentissage'),
                  subtitle: const Text('Performance, comportement, assistant IA'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _open(
                    LearningInsightsPage(controller: widget.controller),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.tune),
                  title: const Text('Questionnaire d’apprentissage'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _open(
                    LearningProfileOnboardingPage(controller: widget.controller),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Confidentialité et réglages'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _open(
                    PrivacySettingsPage(
                      controller: widget.controller,
                      onSignOut: widget.onSignOut,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (widget.controller.profileErrorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              widget.controller.profileErrorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _editProfile,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Modifier mon profil'),
          ),
        ],
      );

  Widget _section(String title, List<Widget> children) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ...children,
            ],
          ),
        ),
      );

  Widget _detail(String label, String? value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 150,
              child: Text(
                label,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(child: Text(value?.isNotEmpty == true ? value! : '—')),
          ],
        ),
      );

  String _learningStyleLabel(String? value) => switch (value) {
        'visual' => 'Visuel',
        'auditory' => 'Auditif',
        'reading' => 'Lecture',
        'kinesthetic' => 'Pratique',
        'mixed' => 'Mixte',
        _ => 'Non renseigné',
      };

  String _preferenceLabel(String key) => switch (key) {
        'study_environment' => 'Environnement',
        'session_minutes' => 'Durée de session',
        'break_minutes' => 'Durée de pause',
        'preferred_hours' => 'Heures préférées',
        'difficult_subjects' => 'Matières difficiles',
        'attendance_rate' => 'Assiduité',
        _ => key,
      };
}
