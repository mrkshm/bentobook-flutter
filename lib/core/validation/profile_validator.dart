class ProfileValidator {
  static const minUsernameLength = 3;
  static const maxUsernameLength = 20;
  static const maxNameLength = 50;
  static const maxAboutLength = 500;
  static final _usernameRegex = RegExp(r'^[a-zA-Z0-9_]+$');
  static final _nameRegex = RegExp(r"^[a-zA-Z\s\-']+$");

  static String? validateUsername(String value) {
    if (value.isEmpty) return 'Username is required';
    if (value.length < minUsernameLength) {
      return 'Username must be at least $minUsernameLength characters';
    }
    if (value.length > maxUsernameLength) {
      return 'Username must be less than $maxUsernameLength characters';
    }
    if (!_usernameRegex.hasMatch(value)) {
      return 'Username can only contain letters, numbers and underscores';
    }
    return null;
  }

  static String? validateName(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return null; // Names are optional
    }
    if (value.length > maxNameLength) {
      return '$fieldName must be less than $maxNameLength characters';
    }
    if (!_nameRegex.hasMatch(value)) {
      return '$fieldName can only contain letters, spaces, hyphens, and apostrophes';
    }
    return null;
  }

  static String? validateAbout(String? value) {
    if (value == null || value.isEmpty) {
      return null; // About is optional
    }
    if (value.length > maxAboutLength) {
      return 'About must be less than $maxAboutLength characters';
    }
    return null;
  }
}
