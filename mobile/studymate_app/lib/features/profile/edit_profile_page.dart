import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_theme.dart';
import '../../data/services/studymate_api.dart';
import '../../state/study_controller.dart';
import 'profile_photo_service.dart';
import 'user_avatar.dart';

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

enum _PhotoAction { gallery, camera, remove }

class _EditProfilePageState extends State<EditProfilePage> {
  static const _locales = {
    'fr-FR': 'Français',
    'en-US': 'English',
    'ar-TN': 'العربية',
  };
  static const _timezones = [
    'Africa/Tunis',
    'Europe/Paris',
    'Africa/Algiers',
    'Africa/Casablanca',
    'UTC',
  ];
  static const _styles = {
    'visual': ('Visuel', Icons.visibility_rounded),
    'auditory': ('Auditif', Icons.headphones_rounded),
    'reading': ('Lecture', Icons.menu_book_rounded),
    'kinesthetic': ('Pratique', Icons.back_hand_rounded),
    'mixed': ('Mixte', Icons.auto_awesome_rounded),
  };
  static const _environments = {
    'quiet': ('Calme', Icons.volume_off_rounded),
    'shared': ('Espace partagé', Icons.groups_rounded),
    'cafe': ('Café / public', Icons.local_cafe_rounded),
  };

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _levelController;
  late final TextEditingController _specialtyController;
  late final TextEditingController _goalsController;
  late final TextEditingController _sessionMinutesController;
  late final TextEditingController _breakMinutesController;
  String _locale = '';
  String _timezone = '';
  String _learningStyle = '';
  String _environment = '';
  int _dailyGoal = 60;
  String? _photoUrl;
  Uint8List? _photoPreview;
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
    _levelController = TextEditingController(text: studentProfile?.studyLevel ?? '');
    _specialtyController = TextEditingController(text: studentProfile?.specialty ?? '');
    _goalsController = TextEditingController(
      text: studentProfile?.academicGoals.join('\n') ?? '',
    );
    _dailyGoal = studentProfile?.dailyStudyGoalMinutes ?? 60;
    _sessionMinutesController = TextEditingController(
      text: preferences['session_minutes']?.toString() ?? '',
    );
    _breakMinutesController = TextEditingController(
      text: preferences['break_minutes']?.toString() ?? '',
    );
    _locale = userProfile?.locale ?? '';
    _timezone = userProfile?.timezone ?? '';
    _learningStyle = studentProfile?.preferredLearningStyle ?? '';
    _environment = preferences['study_environment'] as String? ?? '';
    _photoUrl = userProfile?.photoUrl ?? widget.user.photoURL;
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _levelController.dispose();
    _specialtyController.dispose();
    _goalsController.dispose();
    _sessionMinutesController.dispose();
    _breakMinutesController.dispose();
    super.dispose();
  }

  bool get _busy => _isSaving || _isUploading;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // L'objectif quotidien peut dépasser 8 h si l'étudiant l'a saisi avant.
    final goalMax = _dailyGoal > 480 ? ((_dailyGoal + 59) ~/ 60) * 60 : 480;
    return Scaffold(
      appBar: AppBar(title: const Text('Modifier mon profil')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            _header(context),
            const SizedBox(height: 16),
            _Section(
              icon: Icons.badge_rounded,
              title: 'Identité',
              children: [
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nom affiché',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: (value) {
                    final name = value?.trim() ?? '';
                    if (name.isEmpty) return 'Le nom est obligatoire.';
                    if (name.length > 160) return '160 caractères maximum.';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _locale,
                  decoration: const InputDecoration(
                    labelText: 'Langue',
                    prefixIcon: Icon(Icons.translate_rounded),
                  ),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('Non renseignée')),
                    for (final entry in {
                      ..._locales,
                      if (_locale.isNotEmpty && !_locales.containsKey(_locale)) _locale: _locale,
                    }.entries)
                      DropdownMenuItem(value: entry.key, child: Text(entry.value)),
                  ],
                  onChanged: _busy ? null : (v) => setState(() => _locale = v ?? ''),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _timezone,
                  decoration: const InputDecoration(
                    labelText: 'Fuseau horaire',
                    prefixIcon: Icon(Icons.public_rounded),
                  ),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('Non renseigné')),
                    for (final zone in {..._timezones, if (_timezone.isNotEmpty) _timezone})
                      DropdownMenuItem(value: zone, child: Text(zone)),
                  ],
                  onChanged: _busy ? null : (v) => setState(() => _timezone = v ?? ''),
                ),
              ],
            ),
            _Section(
              icon: Icons.school_rounded,
              title: 'Études',
              children: [
                TextFormField(
                  controller: _levelController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Niveau d’étude',
                    hintText: 'Ex. Licence 2, Master, Terminale',
                    prefixIcon: Icon(Icons.stairs_rounded),
                  ),
                  validator: (value) =>
                      (value?.length ?? 0) > 80 ? '80 caractères maximum.' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _specialtyController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Spécialité / filière',
                    prefixIcon: Icon(Icons.workspace_premium_outlined),
                  ),
                  validator: (value) =>
                      (value?.length ?? 0) > 160 ? '160 caractères maximum.' : null,
                ),
                const SizedBox(height: 12),
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
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Objectif d’étude quotidien',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    Text(
                      _formatMinutes(_dailyGoal),
                      style: TextStyle(fontWeight: FontWeight.w800, color: colors.primary),
                    ),
                  ],
                ),
                Slider(
                  value: _dailyGoal.toDouble(),
                  max: goalMax.toDouble(),
                  divisions: goalMax ~/ 15,
                  label: _formatMinutes(_dailyGoal),
                  onChanged: _busy ? null : (v) => setState(() => _dailyGoal = v.round()),
                ),
              ],
            ),
            _Section(
              icon: Icons.psychology_alt_rounded,
              title: 'Façon d’apprendre',
              children: [
                Text('Style d’apprentissage', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                _Choices(
                  options: _styles,
                  selected: _learningStyle,
                  enabled: !_busy,
                  onSelected: (v) => setState(() => _learningStyle = v),
                ),
                const SizedBox(height: 16),
                Text('Environnement préféré', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                _Choices(
                  options: _environments,
                  selected: _environment,
                  enabled: !_busy,
                  onSelected: (v) => setState(() => _environment = v),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _sessionMinutesController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Session (min)',
                          prefixIcon: Icon(Icons.timer_outlined),
                        ),
                        validator: _validateOptionalMinutes,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _breakMinutesController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Pause (min)',
                          prefixIcon: Icon(Icons.coffee_outlined),
                        ),
                        validator: _validateOptionalMinutes,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (_errorMessage != null)
              Card(
                color: colors.errorContainer,
                child: ListTile(
                  leading: Icon(Icons.error_outline_rounded, color: colors.onErrorContainer),
                  title: Text(
                    _errorMessage!,
                    style: TextStyle(color: colors.onErrorContainer),
                  ),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: _busy ? null : _save,
            icon: _isSaving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded),
            label: Text(_isSaving ? 'Enregistrement…' : 'Enregistrer'),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final name = _nameController.text.trim();
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: BoxDecoration(
        gradient: AppGradients.brand,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Semantics(
            button: true,
            label: 'Changer la photo de profil',
            child: GestureDetector(
              onTap: _busy ? null : _choosePhoto,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: UserAvatar(
                      photoUrl: _photoUrl,
                      name: name.isEmpty ? widget.user.email : name,
                      preview: _photoPreview,
                      radius: 52,
                    ),
                  ),
                  if (_isUploading)
                    Positioned.fill(
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.black38,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      ),
                    ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Material(
                      color: Theme.of(context).colorScheme.primary,
                      shape: const CircleBorder(side: BorderSide(color: Colors.white, width: 3)),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.photo_camera_rounded, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            name.isEmpty ? 'Ton nom' : name,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
          ),
          if (widget.user.email != null) ...[
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline_rounded, color: Colors.white70, size: 14),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    widget.user.email!,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Text(
            _isUploading
                ? 'Envoi de la photo…'
                : 'Touchez la photo pour la changer · enregistrée tout de suite',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Future<void> _choosePhoto() async {
    final hasPhoto = (_photoUrl ?? '').isNotEmpty;
    final action = await showModalBottomSheet<_PhotoAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choisir dans la galerie'),
              onTap: () => Navigator.pop(context, _PhotoAction.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('Prendre une photo'),
              onTap: () => Navigator.pop(context, _PhotoAction.camera),
            ),
            if (hasPhoto)
              ListTile(
                leading: Icon(Icons.delete_outline_rounded,
                    color: Theme.of(context).colorScheme.error),
                title: Text(
                  'Supprimer la photo',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                onTap: () => Navigator.pop(context, _PhotoAction.remove),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    if (action == _PhotoAction.remove) {
      await _applyPhoto(null);
    } else {
      await _uploadPhoto(
        action == _PhotoAction.camera ? ImageSource.camera : ImageSource.gallery,
      );
    }
  }

  Future<void> _uploadPhoto(ImageSource source) async {
    setState(() => _errorMessage = null);
    try {
      final photo = await ProfilePhotoService.pick(source: source);
      if (photo == null || !mounted) return;
      // Aperçu immédiat pendant l'envoi.
      setState(() {
        _photoPreview = photo.bytes;
        _isUploading = true;
      });
      final url = await ProfilePhotoService.upload(widget.user.uid, photo);
      await _applyPhoto(url);
    } on StateError catch (error) {
      _photoFailed(error.message);
    } on StudyMateApiException catch (error) {
      _photoFailed(error.message);
    } catch (_) {
      _photoFailed('La photo n’a pas pu être envoyée. Vérifie ta connexion.');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _applyPhoto(String? url) async {
    setState(() => _isUploading = true);
    try {
      await widget.controller.updateProfilePhoto(firebaseUser: widget.user, photoUrl: url);
      if (!mounted) return;
      setState(() {
        _photoUrl = url;
        _photoPreview = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(url == null ? 'Photo supprimée.' : 'Photo de profil mise à jour.')),
      );
    } on StudyMateApiException catch (error) {
      _photoFailed(error.message);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _photoFailed(String message) {
    if (!mounted) return;
    setState(() {
      _photoPreview = null;
      _errorMessage = message;
    });
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
        locale: _locale.isEmpty ? null : _locale,
        timezone: _timezone.isEmpty ? null : _timezone,
        studyLevel: _optional(_levelController.text),
        specialty: _optional(_specialtyController.text),
        academicGoals: _goals(_goalsController.text),
        preferredLearningStyle: _learningStyle.isEmpty ? null : _learningStyle,
        dailyStudyGoalMinutes: _dailyGoal,
        preferences: preferences,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on StudyMateApiException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        setState(
          () => _errorMessage = 'Firebase n’a pas pu mettre à jour le profil (${error.code}).',
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  static String _formatMinutes(int minutes) {
    if (minutes == 0) return 'Aucun';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '$m min';
    return m == 0 ? '$h h' : '$h h ${m.toString().padLeft(2, '0')}';
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
      return 'Entre 0 et 1440.';
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

class _Section extends StatelessWidget {
  const _Section({required this.icon, required this.title, required this.children});

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: colors.onPrimaryContainer),
                ),
                const SizedBox(width: 10),
                Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    )),
              ],
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _Choices extends StatelessWidget {
  const _Choices({
    required this.options,
    required this.selected,
    required this.enabled,
    required this.onSelected,
  });

  final Map<String, (String, IconData)> options;
  final String selected;
  final bool enabled;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final MapEntry(key: value, value: (label, icon)) in options.entries)
            ChoiceChip(
              avatar: Icon(icon, size: 18),
              label: Text(label),
              selected: selected == value,
              // Retoucher le choix actif le désélectionne (« non renseigné »).
              onSelected: enabled ? (on) => onSelected(on ? value : '') : null,
            ),
        ],
      );
}
