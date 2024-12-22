import 'package:bentobook/core/api/api_client.dart';
import 'package:bentobook/core/auth/auth_service.dart';
import 'package:bentobook/core/database/database.dart';
import 'package:bentobook/core/sync/operation_types.dart';
import 'package:bentobook/core/sync/queue_manager.dart';
import 'package:bentobook/core/theme/theme.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'dart:developer' as dev;
import '../shared/providers.dart';
import 'theme_persistence.dart';

abstract class BaseThemeNotifier extends StateNotifier<ThemeMode> {
  BaseThemeNotifier(super.initial);
  
  void setTheme(ThemeMode theme);
}

class NotAuthenticatedThemeNotifier extends BaseThemeNotifier {
  NotAuthenticatedThemeNotifier() : super(ThemeMode.system);
  
  @override
  void setTheme(ThemeMode theme) {
    state = theme;
  }
}

final themeProvider = StateNotifierProvider<BaseThemeNotifier, ThemeMode>((ref) {
  final authState = ref.watch(authServiceProvider);
  
  // Return system theme notifier if not authenticated
  if (!authState.maybeMap(
    authenticated: (_) => true,
    orElse: () => false,
  )) {
    return NotAuthenticatedThemeNotifier();
  }

  final user = authState.maybeMap(
    authenticated: (state) => state.user,
    orElse: () => throw StateError('User must be authenticated'),
  );
  
  final db = ref.watch(databaseProvider);
  final api = ref.watch(apiClientProvider);
  final queueManager = ref.watch(queueManagerProvider);
  
  return ThemeNotifier(
    db: db,
    api: api,
    queueManager: queueManager,
    userEmail: user.attributes.email,
  );
});

class ThemeNotifier extends BaseThemeNotifier {
  final AppDatabase db;
  final ApiClient api;
  final QueueManager queueManager;
  final String userEmail;

  ThemeNotifier({
    required this.db,
    required this.api,
    required this.queueManager,
    required this.userEmail,
  }) : super(ThemeMode.system);

  @override
  Future<void> setTheme(ThemeMode theme) async {
    state = theme;
    dev.log('ThemeNotifier: Setting theme to ${theme.toString()}');
    
    try {
      await db.updateUserTheme(userEmail, theme);
      dev.log('ThemeNotifier: Updated theme in database');
      
      try {
        await api.updateProfile(preferredTheme: ThemePersistence.themeToString(theme));
        dev.log('ThemeNotifier: Synced theme with API');
      } catch (e) {
        dev.log('ThemeNotifier: API sync failed, queueing operation');
        await queueManager.enqueueOperation(
          type: OperationType.themeUpdate,
          payload: {'theme': ThemePersistence.themeToString(theme)},
        );
      }
    } catch (e) {
      dev.log('ThemeNotifier: Error updating theme', error: e);
      rethrow;
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
  ColorSchemeNotifier() : super(FlexScheme.blue);

  void setSchemeByName(String schemeName) {
    state = AppTheme.stringToScheme(schemeName);
  }
}

final colorSchemeProvider = StateNotifierProvider<ColorSchemeNotifier, FlexScheme>((ref) {
  return ColorSchemeNotifier();
});