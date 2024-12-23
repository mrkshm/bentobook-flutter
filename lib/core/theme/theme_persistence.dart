import 'package:flutter/material.dart' show ThemeMode;

/// Handles conversion between ThemeMode enum and string representation
/// for database and API storage
class ThemePersistence {
  /// Convert ThemeMode to string for storage
  static String themeToString(ThemeMode theme) {
    switch (theme) {
      case ThemeMode.system:
        return 'system';
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
    }
  }

  /// Convert string from storage to ThemeMode
  static ThemeMode stringToTheme(String? value) {
    switch (value?.toLowerCase()) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }
}