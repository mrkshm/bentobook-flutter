import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bentobook/core/theme/theme_persistence.dart';

void main() {
  group('ThemePersistence', () {
    test('themeToString converts ThemeMode to correct string', () {
      expect(ThemePersistence.themeToString(ThemeMode.light), 'light');
      expect(ThemePersistence.themeToString(ThemeMode.dark), 'dark');
      expect(ThemePersistence.themeToString(ThemeMode.system), 'system');
    });

    test('stringToTheme converts string to correct ThemeMode', () {
      expect(ThemePersistence.stringToTheme('light'), ThemeMode.light);
      expect(ThemePersistence.stringToTheme('dark'), ThemeMode.dark);
      expect(ThemePersistence.stringToTheme('system'), ThemeMode.system);
    });

    test('stringToTheme handles case insensitive input', () {
      expect(ThemePersistence.stringToTheme('LIGHT'), ThemeMode.light);
      expect(ThemePersistence.stringToTheme('Dark'), ThemeMode.dark);
      expect(ThemePersistence.stringToTheme('SYSTEM'), ThemeMode.system);
    });

    test('stringToTheme returns system for null or invalid input', () {
      expect(ThemePersistence.stringToTheme(null), ThemeMode.system);
      expect(ThemePersistence.stringToTheme('invalid'), ThemeMode.system);
      expect(ThemePersistence.stringToTheme(''), ThemeMode.system);
    });
  });
}