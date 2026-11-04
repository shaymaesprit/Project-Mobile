import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../data/models/study_models.dart';
import '../../state/study_controller.dart';
import 'edit_profile_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.controller,
    required this.user,
  });

  final StudyController controller;
  final User? user;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  void initState() {
    super.initState();
  }

  Future<void> _refresh() => widget.controller.refreshProfile();

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
                _ProfileAvatar(photoUrl: account.photoUrl, radius: 48),
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
            ...student.preferences.entries.map(
              (entry) => _detail(
                _preferenceLabel(entry.key),
                entry.value.toString(),
              ),
            ),
          ]),
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
        _ => key,
      };
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.photoUrl, required this.radius});

  final String? photoUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final url = photoUrl;
    if (url == null || url.isEmpty) {
      return CircleAvatar(
        radius: radius,
        child: const Icon(Icons.person_outline, size: 44),
      );
    }
    return ClipOval(
      child: Image.network(
        url,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => CircleAvatar(
          radius: radius,
          child: const Icon(Icons.person_outline, size: 44),
        ),
      ),
    );
  }
}
