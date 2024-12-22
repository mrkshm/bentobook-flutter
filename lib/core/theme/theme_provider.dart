import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flex_color_scheme/flex_color_scheme.dart' show FlexScheme;
import 'dart:developer' as dev;
import '../auth/auth_service.dart';
import '../shared/providers.dart';
import 'theme.dart';

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  return ThemeNotifier(ref);
});

final colorSchemeProvider = StateNotifierProvider<ColorSchemeNotifier, FlexScheme>((ref) {
  return ColorSchemeNotifier();
});

class ThemeNotifier extends StateNotifier<ThemeMode> {
  final Ref _ref;
  
  ThemeNotifier(this._ref) : super(ThemeMode.system);

  void setTheme(ThemeMode theme) async {
    dev.log('ThemeNotifier: Setting theme to ${theme.toString()}');
    state = theme;
    
    // Update theme in database for current user
    try {
      final authState = _ref.read(authServiceProvider);
      final email = authState.maybeMap(
        authenticated: (state) => state.user.attributes.email,
        orElse: () => null,
      );
      
      if (email != null) {
        final userRepo = _ref.read(userRepositoryProvider);
        final user = await userRepo.getCurrentUser(email);
        if (user != null) {
          dev.log('ThemeNotifier: Updating theme in database for user ${user.email}');
          await _ref.read(databaseProvider).updateUser(
            user.copyWith(
              preferredTheme: theme,
              updatedAt: DateTime.now(),
            ),
          );
        }
      }
    } catch (e) {
      dev.log('ThemeNotifier: Failed to update theme in database', error: e);
    }
  }

  void toggleTheme() {
    final newTheme = state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    dev.log('ThemeNotifier: Toggling theme from ${state.toString()} to ${newTheme.toString()}');
    setTheme(newTheme);
  }

  String get themeName {
    switch (state) {
      case ThemeMode.system:
        return 'System';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
    }
  }
}

class ColorSchemeNotifier extends StateNotifier<FlexScheme> {
  ColorSchemeNotifier() : super(AppTheme.defaultScheme);

  void setScheme(FlexScheme scheme) {
    state = scheme;
  }

  void setSchemeByName(String name) {
    state = AppTheme.stringToScheme(name);
  }

  String get schemeName => AppTheme.schemeToString(state);
}
