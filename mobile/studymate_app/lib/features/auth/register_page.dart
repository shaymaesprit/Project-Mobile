import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../data/services/studymate_api.dart';
import '../profile/profile_photo_service.dart';
import 'auth_validators.dart';
import 'auth_widgets.dart';
import 'study_mate_auth_service.dart';

const academicLevels = <String>[
  'Licence 1',
  'Licence 2',
  'Licence 3',
  'Master 1',
  'Master 2',
  'Ingénieur',
  'Doctorat',
  'Autre',
];

/// Account creation: Firebase Authentication account, verification email,
/// then a best-effort synchronisation of the profile with the StudyMate API.
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key, required this.auth, required this.api});

  final FirebaseAuth auth;
  final StudyMateApi api;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _university = TextEditingController();
  final _specialty = TextEditingController();
  final _phone = TextEditingController();
  String? _level;
  PickedProfilePhoto? _photo;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in [
      _firstName,
      _lastName,
      _email,
      _password,
      _confirmPassword,
      _university,
      _specialty,
      _phone,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final photo = await ProfilePhotoService.pick();
      if (photo != null && mounted) setState(() => _photo = photo);
    } on StateError catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _loading = true;
      _error = null;
    });

    final displayName =
        '${_firstName.text.trim()} ${_lastName.text.trim()}'.trim();
    final User user;
    try {
      user = await StudyMateAuthService.registerWithEmail(
        widget.auth,
        email: _email.text,
        password: _password.text,
        displayName: displayName,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = StudyMateAuthService.messageFor(error);
      });
      return;
    }

    // The account exists from here on: the auth gate already shows the
    // verification screen below this page. Failures below must not block it.
    final warnings = <String>[];
    String? photoUrl;
    final photo = _photo;
    if (photo != null) {
      try {
        photoUrl = await ProfilePhotoService.upload(user.uid, photo);
      } catch (_) {
        warnings.add('la photo de profil');
      }
    }
    try {
      await _syncProfile(displayName: displayName, photoUrl: photoUrl);
    } catch (_) {
      warnings.add('le profil universitaire');
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          warnings.isEmpty
              ? 'Compte créé. Un email de vérification a été envoyé à '
                  '${user.email}.'
              : 'Compte créé, mais ${warnings.join(' et ')} n’a pas pu être '
                  'enregistré. Complète-le depuis ton profil.',
        ),
      ),
    );
    navigator.popUntil((route) => route.isFirst);
  }

  Future<void> _syncProfile({
    required String displayName,
    required String? photoUrl,
  }) async {
    await widget.api.updateCurrentUser(
      displayName: displayName,
      photoUrl: photoUrl,
    );
    final phone = _phone.text.trim();
    await widget.api.updateStudentProfile(
      studyLevel: _level,
      specialty: _specialty.text.trim(),
      academicGoals: const [],
      preferredLearningStyle: null,
      dailyStudyGoalMinutes: 60,
      preferences: {
        'university': _university.text.trim(),
        if (phone.isNotEmpty) 'phone': phone,
      },
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    TextInputAction action = TextInputAction.next,
    Iterable<String>? autofillHints,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextFormField(
          controller: controller,
          enabled: !_loading,
          keyboardType: keyboardType,
          textInputAction: action,
          autofillHints: autofillHints,
          validator: validator,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => AuthScaffold(
        showBack: true,
        title: 'Créer un compte',
        subtitle: 'Quelques informations pour personnaliser StudyMate.',
        children: [
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: GestureDetector(
                    onTap: _loading ? null : _pickPhoto,
                    child: CircleAvatar(
                      radius: 42,
                      backgroundImage: _photo == null
                          ? null
                          : MemoryImage(_photo!.bytes),
                      child: _photo == null
                          ? const Icon(Icons.add_a_photo_outlined)
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Center(child: Text('Photo de profil (optionnelle)')),
                const SizedBox(height: 16),
                _field(
                  controller: _firstName,
                  label: 'Prénom',
                  icon: Icons.person_outline,
                  autofillHints: const [AutofillHints.givenName],
                  validator: (v) => AuthValidators.name(v, 'Le prénom'),
                ),
                _field(
                  controller: _lastName,
                  label: 'Nom',
                  icon: Icons.person_outline,
                  autofillHints: const [AutofillHints.familyName],
                  validator: (v) => AuthValidators.name(v, 'Le nom'),
                ),
                _field(
                  controller: _email,
                  label: 'Email',
                  icon: Icons.mail_outline,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  validator: AuthValidators.email,
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: PasswordField(
                    controller: _password,
                    label: 'Mot de passe',
                    enabled: !_loading,
                    validator: AuthValidators.newPassword,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.newPassword],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: PasswordField(
                    controller: _confirmPassword,
                    label: 'Confirmer le mot de passe',
                    enabled: !_loading,
                    validator: (v) =>
                        AuthValidators.confirmPassword(v, _password.text),
                    textInputAction: TextInputAction.next,
                  ),
                ),
                _field(
                  controller: _university,
                  label: 'Université',
                  icon: Icons.account_balance_outlined,
                  validator: (v) =>
                      AuthValidators.required(v, 'L’université'),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: DropdownButtonFormField<String>(
                    // ignore: deprecated_member_use
                    value: _level,
                    items: [
                      for (final level in academicLevels)
                        DropdownMenuItem(value: level, child: Text(level)),
                    ],
                    onChanged:
                        _loading ? null : (v) => setState(() => _level = v),
                    validator: (v) =>
                        AuthValidators.required(v, 'Le niveau académique'),
                    decoration: const InputDecoration(
                      labelText: 'Niveau académique',
                      prefixIcon: Icon(Icons.school_outlined),
                    ),
                  ),
                ),
                _field(
                  controller: _specialty,
                  label: 'Spécialité',
                  icon: Icons.menu_book_outlined,
                  validator: (v) => AuthValidators.required(v, 'La spécialité'),
                ),
                _field(
                  controller: _phone,
                  label: 'Téléphone (optionnel)',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  action: TextInputAction.done,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  validator: AuthValidators.optionalPhone,
                ),
                AuthErrorText(_error),
                AuthSubmitButton(
                  label: 'Créer mon compte',
                  loading: _loading,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ],
      );
}
