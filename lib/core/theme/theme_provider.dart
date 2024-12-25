import 'package:bentobook/core/api/api_client.dart';
import 'package:bentobook/core/api/models/profile.dart';
import 'package:bentobook/core/auth/auth_service.dart';
import 'package:bentobook/core/database/database.dart';
import 'package:bentobook/core/database/operations/user_operations.dart';
import 'package:bentobook/core/network/connectivity_service.dart';
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

final themeProvider =
    StateNotifierProvider<BaseThemeNotifier, ThemeMode>((ref) {
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
  }) : super(ThemeMode.system) {
    _loadStoredTheme();
  }

  Future<void> _loadStoredTheme() async {
    try {
      final user = await db.getUserByEmail(userEmail);
      if (user != null) {
        state = user.preferredTheme;
        dev.log('ThemeNotifier: Loaded stored theme: ${user.preferredTheme}');
      }
    } catch (e) {
      dev.log('ThemeNotifier: Error loading stored theme', error: e);
    }
  }

  @override
  Future<void> setTheme(ThemeMode theme) async {
    state = theme;
    final themeString = ThemePersistence.themeToString(theme);
    
    try {
      if (await ConnectivityService().hasConnection()) {
        // If online, update server directly
        await api.updateProfile(
          request: ProfileUpdateRequest(
            preferredTheme: themeString,
          ),
        );
        
        // Update local database
        await db.updateUser(
          await db.getUserByEmail(userEmail).then((user) => user!.copyWith(
            preferredTheme: theme,
            updatedAt: DateTime.now(),
          )),
        );
        dev.log('ThemeNotifier: Updated theme in database');
      } else {
        // If offline, queue the update
        await queueManager.enqueueOperation(
          type: OperationType.themeUpdate,
          payload: {'theme': themeString},
        );
      }
    } catch (e) {
      dev.log('ThemeNotifier: Error updating theme', error: e);
      rethrow;
    }
  }

  void toggleTheme() {
    final newTheme =
        state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    dev.log(
        'ThemeNotifier: Toggling theme from ${state.toString()} to ${newTheme.toString()}');
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

final colorSchemeProvider =
    StateNotifierProvider<ColorSchemeNotifier, FlexScheme>((ref) {
  return ColorSchemeNotifier();
});
