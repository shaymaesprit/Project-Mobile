import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../data/services/studymate_api.dart';
import '../../state/study_controller.dart';
import 'profile_photo_service.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({
    super.key,
    required this.controller,
    required this.user,
  });

  final StudyController controller;
  final User user;

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _levelController;
  late final TextEditingController _specialtyController;
  late final TextEditingController _goalsController;
  late final TextEditingController _dailyGoalController;
  late final TextEditingController _sessionMinutesController;
  late final TextEditingController _breakMinutesController;
  late final TextEditingController _localeController;
  late final TextEditingController _timezoneController;
  String _learningStyle = '';
  String _environment = '';
  String? _photoUrl;
  bool _isSaving = false;
  bool _isUploading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final userProfile = widget.controller.userProfile;
    final studentProfile = widget.controller.studentProfile;
    final preferences = studentProfile?.preferences ?? const <String, dynamic>{};
    _nameController = TextEditingController(
      text: userProfile?.displayName ?? widget.user.displayName ?? '',
    );
    _levelController =
        TextEditingController(text: studentProfile?.studyLevel ?? '');
    _specialtyController =
        TextEditingController(text: studentProfile?.specialty ?? '');
    _goalsController = TextEditingController(
      text: studentProfile?.academicGoals.join('\n') ?? '',
    );
    _dailyGoalController = TextEditingController(
      text: '${studentProfile?.dailyStudyGoalMinutes ?? 60}',
    );
    _sessionMinutesController = TextEditingController(
      text: preferences['session_minutes']?.toString() ?? '',
    );
    _breakMinutesController = TextEditingController(
      text: preferences['break_minutes']?.toString() ?? '',
    );
    _localeController = TextEditingController(text: userProfile?.locale ?? '');
    _timezoneController =
        TextEditingController(text: userProfile?.timezone ?? '');
    _learningStyle = studentProfile?.preferredLearningStyle ?? '';
    _environment = preferences['study_environment'] as String? ?? '';
    _photoUrl = userProfile?.photoUrl ?? widget.user.photoURL;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _levelController.dispose();
    _specialtyController.dispose();
    _goalsController.dispose();
    _dailyGoalController.dispose();
    _sessionMinutesController.dispose();
    _breakMinutesController.dispose();
    _localeController.dispose();
    _timezoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Modifier mon profil')),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: Column(
                  children: [
                    _photoUrl == null
                        ? const CircleAvatar(
                            radius: 48,
                            child: Icon(Icons.person_outline, size: 44),
                          )
                        : ClipOval(
                            child: Image.network(
                              _photoUrl!,
                              width: 96,
                              height: 96,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const CircleAvatar(
                                radius: 48,
                                child: Icon(Icons.person_outline, size: 44),
                              ),
                            ),
                          ),
                    TextButton.icon(
                      onPressed: _isUploading || _isSaving ? null : _pickPhoto,
                      icon: _isUploading
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.photo_library_outlined),
                      label: Text(
                        _isUploading ? 'Envoi de la photo…' : 'Changer la photo',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nom affiché'),
                validator: (value) {
                  final name = value?.trim() ?? '';
                  if (name.isEmpty) return 'Le nom est obligatoire.';
                  if (name.length > 160) return '160 caractères maximum.';
                  return null;
                },
              ),
              TextFormField(
                initialValue: widget.user.email ?? '',
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Adresse e-mail',
                  helperText: 'L’adresse e-mail est gérée par Firebase Auth.',
                ),
              ),
              TextFormField(
                controller: _localeController,
                decoration: const InputDecoration(
                  labelText: 'Langue (ex. fr-FR)',
                ),
                validator: (value) => (value?.length ?? 0) > 20
                    ? '20 caractères maximum.'
                    : null,
              ),
              TextFormField(
                controller: _timezoneController,
                decoration: const InputDecoration(
                  labelText: 'Fuseau horaire (ex. Europe/Paris)',
                ),
                validator: (value) => (value?.length ?? 0) > 64
                    ? '64 caractères maximum.'
                    : null,
              ),
              const SizedBox(height: 20),
              Text('Études', style: Theme.of(context).textTheme.titleLarge),
              TextFormField(
                controller: _levelController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Niveau d’étude',
                  hintText: 'Ex. Licence 2, Master, Terminale',
                ),
                validator: (value) => (value?.length ?? 0) > 80
                    ? '80 caractères maximum.'
                    : null,
              ),
              TextFormField(
                controller: _specialtyController,
                textCapitalization: TextCapitalization.words,
                decoration:
                    const InputDecoration(labelText: 'Spécialité / filière'),
                validator: (value) => (value?.length ?? 0) > 160
                    ? '160 caractères maximum.'
                    : null,
              ),
              TextFormField(
                controller: _goalsController,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Objectifs académiques',
                  helperText: 'Un objectif par ligne, 20 au maximum.',
                  alignLabelWithHint: true,
                ),
                validator: (value) {
                  final goals = _goals(value ?? '');
                  if (goals.length > 20) return '20 objectifs maximum.';
                  if (goals.any((goal) => goal.length > 200)) {
                    return '200 caractères maximum par objectif.';
                  }
                  return null;
                },
              ),
              DropdownButtonFormField<String>(
                initialValue: _learningStyle,
                decoration: const InputDecoration(
                  labelText: 'Style d’apprentissage préféré',
                ),
                items: const [
                  DropdownMenuItem(value: '', child: Text('Non renseigné')),
                  DropdownMenuItem(value: 'visual', child: Text('Visuel')),
                  DropdownMenuItem(value: 'auditory', child: Text('Auditif')),
                  DropdownMenuItem(value: 'reading', child: Text('Lecture')),
                  DropdownMenuItem(
                    value: 'kinesthetic',
                    child: Text('Pratique'),
                  ),
                  DropdownMenuItem(value: 'mixed', child: Text('Mixte')),
                ],
                onChanged: _isSaving
                    ? null
                    : (value) => setState(() => _learningStyle = value ?? ''),
              ),
              TextFormField(
                controller: _dailyGoalController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Objectif d’étude quotidien (minutes)',
                ),
                validator: (value) {
                  final minutes = int.tryParse(value ?? '');
                  if (minutes == null || minutes < 0 || minutes > 1440) {
                    return 'Saisis un nombre entre 0 et 1440.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              Text(
                'Préférences d’apprentissage',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              DropdownButtonFormField<String>(
                initialValue: _environment,
                decoration:
                    const InputDecoration(labelText: 'Environnement préféré'),
                items: const [
                  DropdownMenuItem(value: '', child: Text('Non renseigné')),
                  DropdownMenuItem(
                    value: 'quiet',
                    child: Text('Calme'),
                  ),
                  DropdownMenuItem(
                    value: 'shared',
                    child: Text('Espace partagé'),
                  ),
                  DropdownMenuItem(
                    value: 'cafe',
                    child: Text('Café / espace public'),
                  ),
                ],
                onChanged: _isSaving
                    ? null
                    : (value) => setState(() => _environment = value ?? ''),
              ),
              TextFormField(
                controller: _sessionMinutesController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Durée de session préférée (minutes)',
                ),
                validator: (value) => _validateOptionalMinutes(value),
              ),
              TextFormField(
                controller: _breakMinutesController,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Durée de pause (minutes)'),
                validator: (value) => _validateOptionalMinutes(value),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _isSaving || _isUploading ? null : _save,
                icon: _isSaving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_isSaving ? 'Enregistrement…' : 'Enregistrer'),
              ),
            ],
          ),
        ),
      );

  Future<void> _pickPhoto() async {
    setState(() {
      _isUploading = true;
      _errorMessage = null;
    });
    try {
      final url = await ProfilePhotoService.selectAndUpload(widget.user);
      if (url != null && mounted) setState(() => _photoUrl = url);
    } on StateError catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } on FirebaseException catch (error) {
      if (mounted) {
        setState(
          () => _errorMessage =
              'Le téléversement Firebase Storage a échoué (${error.code}).',
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    final preferences = Map<String, dynamic>.from(
      widget.controller.studentProfile?.preferences ?? const {},
    );
    if (_environment.isEmpty) {
      preferences.remove('study_environment');
    } else {
      preferences['study_environment'] = _environment;
    }
    _setOptionalMinutes(preferences, 'session_minutes', _sessionMinutesController);
    _setOptionalMinutes(preferences, 'break_minutes', _breakMinutesController);

    try {
      await widget.controller.saveStudentProfile(
        firebaseUser: widget.user,
        displayName: _nameController.text.trim(),
        photoUrl: _photoUrl,
        locale: _optional(_localeController.text),
        timezone: _optional(_timezoneController.text),
        studyLevel: _optional(_levelController.text),
        specialty: _optional(_specialtyController.text),
        academicGoals: _goals(_goalsController.text),
        preferredLearningStyle:
            _learningStyle.isEmpty ? null : _learningStyle,
        dailyStudyGoalMinutes: int.parse(_dailyGoalController.text),
        preferences: preferences,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on StudyMateApiException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        setState(
          () => _errorMessage =
              'Firebase n’a pas pu mettre à jour le profil (${error.code}).',
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  List<String> _goals(String input) => input
      .split('\n')
      .map((goal) => goal.trim())
      .where((goal) => goal.isNotEmpty)
      .toList(growable: false);

  String? _optional(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String? _validateOptionalMinutes(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final minutes = int.tryParse(value);
    if (minutes == null || minutes < 0 || minutes > 1440) {
      return 'Saisis un nombre entre 0 et 1440.';
    }
    return null;
  }

  void _setOptionalMinutes(
    Map<String, dynamic> preferences,
    String key,
    TextEditingController controller,
  ) {
    final value = controller.text.trim();
    if (value.isEmpty) {
      preferences.remove(key);
    } else {
      preferences[key] = int.parse(value);
    }
  }
}
