class SignupValidators {
  static final RegExp _emailShape = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final RegExp _regNumberShape = RegExp(r'^[A-Za-z0-9/.-]{5,30}$');
  static final RegExp _phoneShape = RegExp(r'^\+?[0-9]{9,15}$');

  static String? validateFullName(String value) {
    final v = value.trim();
    if (v.isEmpty) return 'Full name is required.';
    if (v.length < 2) return 'Full name must be at least 2 characters.';
    return null;
  }

  static String? validateRegistrationNumber(String value) {
    final v = value.trim();
    if (v.isEmpty) return 'Registration number is required.';
    if (!_regNumberShape.hasMatch(v)) {
      return 'Use letters, numbers, /, -, or . only.';
    }
    return null;
  }

  static String? validateUniversityEmail(String value) {
    final v = value.trim().toLowerCase();
    if (v.isEmpty) return 'University email is required.';
    if (!_emailShape.hasMatch(v)) return 'Enter a valid email address.';
    final allowed =
        v.endsWith('@must.ac.ug') || v.endsWith('@std.must.ac.ug');
    if (!allowed) return 'Use @must.ac.ug or @std.must.ac.ug email.';
    return null;
  }

  static String? validatePhone(String value) {
    final normalized = value.replaceAll(RegExp(r'\s+'), '').trim();
    if (normalized.isEmpty) return 'Phone number is required.';
    if (!_phoneShape.hasMatch(normalized)) {
      return 'Enter a valid phone number.';
    }
    return null;
  }

  static String? validateOtp(String value) {
    final v = value.trim();
    if (v.length != 5) return 'Enter the 5-digit code.';
    if (!RegExp(r'^\d{5}$').hasMatch(v)) return 'OTP must contain digits only.';
    return null;
  }

  static String? validatePassword(String value) {
    if (value.isEmpty) return 'Password is required.';
    if (value.length < 8 || value.length > 72) {
      return 'Password must be 8-72 characters.';
    }
    return null;
  }

  static String? validateConfirmPassword(String password, String confirm) {
    if (confirm.isEmpty) return 'Please confirm your password.';
    if (password != confirm) return 'Passwords do not match.';
    return null;
  }
}
