import 'package:flutter/material.dart';

import '../../data/services/studymate_api.dart';
import '../../state/study_controller.dart';

/// Collects the declared learning preferences used by the ML models.
/// Values are stored in the student profile `preferences`.
class LearningProfileOnboardingPage extends StatefulWidget {
  const LearningProfileOnboardingPage({super.key, required this.controller});

  final StudyController controller;

  @override
  State<LearningProfileOnboardingPage> createState() =>
      _LearningProfileOnboardingPageState();
}

class _LearningProfileOnboardingPageState
    extends State<LearningProfileOnboardingPage> {
  final _subjects = TextEditingController();
  final _hours = <int>{};
  double _sessionMinutes = 45;
  double _attendance = 90;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final preferences = widget.controller.studentProfile?.preferences ??
        const <String, dynamic>{};
    final hours = preferences['preferred_hours'];
    if (hours is List) _hours.addAll(hours.whereType<int>());
    final subjects = preferences['difficult_subjects'];
    if (subjects is List) {
      _subjects.text = subjects.whereType<String>().join(', ');
    }
    final minutes = preferences['session_minutes'];
    if (minutes is int) _sessionMinutes = minutes.clamp(15, 180).toDouble();
    final attendance = preferences['attendance_rate'];
    if (attendance is num) _attendance = (attendance * 100).clamp(0, 100).toDouble();
  }

  @override
  void dispose() {
    _subjects.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final student = widget.controller.studentProfile;
    if (student == null) {
      setState(() => _error = 'Profil indisponible : réessaie plus tard.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final preferences = Map<String, dynamic>.from(student.preferences);
    final subjects = _subjects.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .take(20)
        .toList();
    preferences['preferred_hours'] = _hours.toList()..sort();
    preferences['difficult_subjects'] = subjects;
    preferences['session_minutes'] = _sessionMinutes.round();
    preferences['attendance_rate'] = double.parse(
      (_attendance / 100).toStringAsFixed(2),
    );
    try {
      await widget.controller.api.updateStudentProfile(
        studyLevel: student.studyLevel,
        specialty: student.specialty,
        academicGoals: student.academicGoals,
        preferredLearningStyle: student.preferredLearningStyle,
        dailyStudyGoalMinutes: student.dailyStudyGoalMinutes,
        preferences: preferences,
      );
      await widget.controller.refreshProfile();
      if (mounted) Navigator.of(context).pop(true);
    } on StudyMateApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Questionnaire d’apprentissage')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Ces réponses sont facultatives. Elles améliorent tes '
              'recommandations tant que tu n’as pas assez de données réelles.',
            ),
            const SizedBox(height: 20),
            Text(
              'Heures où tu étudies le mieux',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var hour = 6; hour <= 23; hour++)
                  FilterChip(
                    label: Text('$hour h'),
                    selected: _hours.contains(hour),
                    onSelected: (selected) => setState(
                      () => selected ? _hours.add(hour) : _hours.remove(hour),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Matières difficiles',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            TextField(
              controller: _subjects,
              decoration: const InputDecoration(
                hintText: 'Séparées par des virgules',
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Durée de session souhaitée : ${_sessionMinutes.round()} min',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Slider(
              value: _sessionMinutes,
              min: 15,
              max: 180,
              divisions: 33,
              label: '${_sessionMinutes.round()} min',
              onChanged: (value) => setState(() => _sessionMinutes = value),
            ),
            Text(
              'Assiduité aux cours : ${_attendance.round()} %',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Slider(
              value: _attendance,
              min: 0,
              max: 100,
              divisions: 20,
              label: '${_attendance.round()} %',
              onChanged: (value) => setState(() => _attendance = value),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Enregistrer'),
            ),
          ],
        ),
      );
}
