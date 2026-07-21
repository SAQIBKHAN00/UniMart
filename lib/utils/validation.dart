class ValidationUtils {
  static String? validateEmail(String? value) {
    final trimmedValue = value?.trim() ?? '';

    if (trimmedValue.isEmpty) {
      return 'Please enter your email';
    }

    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(trimmedValue)) {
      return 'Please enter a valid email address';
    }

    return null;
  }

  static String? validatePassword(String? value) {
    final trimmedValue = value?.trim() ?? '';

    if (trimmedValue.isEmpty) {
      return 'Please enter your password';
    }

    if (trimmedValue.length < 6) {
      return 'Password must be at least 6 characters';
    }

    return null;
  }
}

String? validateEmail(String? value) => ValidationUtils.validateEmail(value);
String? validatePassword(String? value) =>
    ValidationUtils.validatePassword(value);
