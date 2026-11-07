/// Pure form validators shared by the authentication screens.
///
/// Every validator returns `null` when the value is valid, otherwise a French
/// message suitable for `FormField.validator`.
class AuthValidators {
  const AuthValidators._();

  static final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');
  static final _phonePattern = RegExp(r'^\+?[0-9 ().-]{8,20}$');

  static String? required(String? value, String label) {
    if (value == null || value.trim().isEmpty) return '$label est requis.';
    return null;
  }

  static String? name(String? value, String label) {
    final missing = required(value, label);
    if (missing != null) return missing;
    if (value!.trim().length > 80) {
      return '$label ne doit pas dépasser 80 caractères.';
    }
    return null;
  }

  static String? email(String? value) {
    final missing = required(value, 'L’email');
    if (missing != null) return missing;
    if (!_emailPattern.hasMatch(value!.trim())) {
      return 'Saisis une adresse email valide.';
    }
    return null;
  }

  /// At least 8 characters with a lowercase letter, an uppercase letter and a
  /// digit.
  static String? newPassword(String? value) {
    if (value == null || value.isEmpty) return 'Le mot de passe est requis.';
    if (value.length < 8) {
      return 'Le mot de passe doit contenir au moins 8 caractères.';
    }
    if (!value.contains(RegExp(r'[a-z]'))) {
      return 'Ajoute au moins une lettre minuscule.';
    }
    if (!value.contains(RegExp(r'[A-Z]'))) {
      return 'Ajoute au moins une lettre majuscule.';
    }
    if (!value.contains(RegExp(r'[0-9]'))) {
      return 'Ajoute au moins un chiffre.';
    }
    return null;
  }

  static String? currentPassword(String? value) {
    if (value == null || value.isEmpty) return 'Le mot de passe est requis.';
    return null;
  }

  static String? confirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Confirme ton mot de passe.';
    }
    if (value != password) return 'Les mots de passe ne correspondent pas.';
    return null;
  }

  /// The phone number is optional; an empty value is valid.
  static String? optionalPhone(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    if (!_phonePattern.hasMatch(value.trim())) {
      return 'Saisis un numéro de téléphone valide.';
    }
    return null;
  }
}
