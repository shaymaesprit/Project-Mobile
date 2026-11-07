import 'package:flutter_test/flutter_test.dart';
import 'package:studymate/features/auth/auth_validators.dart';

void main() {
  group('email', () {
    test('rejects empty and malformed addresses', () {
      expect(AuthValidators.email(''), isNotNull);
      expect(AuthValidators.email('   '), isNotNull);
      expect(AuthValidators.email('student'), isNotNull);
      expect(AuthValidators.email('student@'), isNotNull);
      expect(AuthValidators.email('student@univ'), isNotNull);
      expect(AuthValidators.email('stu dent@univ.tn'), isNotNull);
    });

    test('accepts a valid address', () {
      expect(AuthValidators.email('student@univ.tn'), isNull);
      expect(AuthValidators.email('  first.last+tag@univ.edu '), isNull);
    });
  });

  group('newPassword', () {
    test('enforces length, case and digit rules', () {
      expect(AuthValidators.newPassword(''), isNotNull);
      expect(AuthValidators.newPassword('Ab1'), isNotNull);
      expect(AuthValidators.newPassword('alllowercase1'), isNotNull);
      expect(AuthValidators.newPassword('ALLUPPERCASE1'), isNotNull);
      expect(AuthValidators.newPassword('NoDigitsHere'), isNotNull);
    });

    test('accepts a strong password', () {
      expect(AuthValidators.newPassword('StrongPass1'), isNull);
    });
  });

  group('confirmPassword', () {
    test('requires a matching value', () {
      expect(AuthValidators.confirmPassword('', 'StrongPass1'), isNotNull);
      expect(AuthValidators.confirmPassword('Other1234', 'StrongPass1'),
          isNotNull);
      expect(AuthValidators.confirmPassword('StrongPass1', 'StrongPass1'),
          isNull);
    });
  });

  group('required fields', () {
    test('rejects blank values', () {
      expect(AuthValidators.required(null, 'Le champ'), isNotNull);
      expect(AuthValidators.required('  ', 'Le champ'), isNotNull);
      expect(AuthValidators.required('ok', 'Le champ'), isNull);
      expect(AuthValidators.name('', 'Le prénom'), isNotNull);
      expect(AuthValidators.name('A' * 81, 'Le prénom'), isNotNull);
    });
  });

  group('optionalPhone', () {
    test('allows empty and valid numbers only', () {
      expect(AuthValidators.optionalPhone(null), isNull);
      expect(AuthValidators.optionalPhone(''), isNull);
      expect(AuthValidators.optionalPhone('+216 20 123 456'), isNull);
      expect(AuthValidators.optionalPhone('abc'), isNotNull);
      expect(AuthValidators.optionalPhone('123'), isNotNull);
    });
  });
}
