import 'package:flutter_test/flutter_test.dart';
import 'package:unimart/utils/validation.dart';

void main() {
  group('email validation', () {
    test('accepts a well-formed email', () {
      expect(validateEmail('student@unimart.com'), isNull);
    });

    test('rejects empty email', () {
      expect(validateEmail(''), 'Please enter your email');
    });

    test('rejects malformed email', () {
      expect(validateEmail('student@'), 'Please enter a valid email address');
    });
  });

  group('password validation', () {
    test('accepts a strong password', () {
      expect(validatePassword('Secure123!'), isNull);
    });

    test('rejects short password', () {
      expect(validatePassword('abc'), 'Password must be at least 6 characters');
    });
  });
}
