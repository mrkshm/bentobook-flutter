import 'package:bentobook/core/api/api_client.dart';
import 'package:bentobook/core/auth/auth_service.dart';
import 'package:bentobook/core/database/database.dart';
import 'package:bentobook/core/database/operations/profile_operations.dart';
import 'package:bentobook/core/network/connectivity_service.dart';
import 'package:bentobook/core/profile/profile_repository.dart';
import 'package:bentobook/core/sync/operation_types.dart';
import 'package:bentobook/core/sync/queue_manager.dart';
import 'package:bentobook/core/theme/theme.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:developer' as dev;
import '../shared/providers.dart';
import 'theme_persistence.dart';
import 'package:bentobook/core/profile/profile_provider.dart';

abstract class BaseThemeNotifier extends StateNotifier<ThemeMode> {
  BaseThemeNotifier(super.initial);

  Future<void> setTheme(ThemeMode theme);
  void toggleTheme();
  String get themeName;
}

class NotAuthenticatedThemeNotifier extends BaseThemeNotifier {
  NotAuthenticatedThemeNotifier() : super(ThemeMode.system);

  @override
  Future<void> setTheme(ThemeMode theme) async {
    state = theme;
  }

  @override
  void toggleTheme() {
    setTheme(state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light);
  }

  @override
  String get themeName => ThemePersistence.themeToString(state);
}

final themeProvider = StateNotifierProvider<BaseThemeNotifier, ThemeMode>((ref) {
  final authState = ref.watch(authServiceProvider);

  if (!authState.maybeMap(
    authenticated: (_) => true,
    orElse: () => false,
  )) {
    return NotAuthenticatedThemeNotifier();
  }

  final db = ref.watch(databaseProvider);
  final api = ref.watch(apiClientProvider);
  final queueManager = ref.watch(queueManagerProvider);
  final userId = authState.maybeMap(
    authenticated: (state) => state.userId,
    orElse: () => throw StateError('User must be authenticated'),
  );

  return AuthenticatedThemeNotifier(
    db: db,
    api: api,
    queueManager: queueManager,
    userId: userId,
    ref: ref,
  );
});

class AuthenticatedThemeNotifier extends BaseThemeNotifier {
  final AppDatabase db;
  final ApiClient api;
  final QueueManager queueManager;
  final String userId;
  final Ref ref;
  final ProfileRepository _repository;

  AuthenticatedThemeNotifier({
    required this.db,
    required this.api,
    required this.queueManager,
    required this.userId,
    required this.ref,
  })  : _repository = ProfileRepository(api, db),
        super(ThemeMode.system) {
    _loadStoredTheme();
    
    // Listen to profile changes
    ref.listen(profileProvider, (previous, next) {
      if (next.profile?.attributes.preferredTheme != null) {
        final theme = ThemePersistence.stringToTheme(
          next.profile!.attributes.preferredTheme!
        );
        if (theme != state) {
          setTheme(theme);
        }
      }
    });
  }

  Future<void> _loadStoredTheme() async {
    try {
      final profile = await db.getProfile(userId);
      if (profile != null && profile.preferredTheme != null) {
        state = ThemePersistence.stringToTheme(profile.preferredTheme!);
        dev.log('ThemeNotifier: Loaded stored theme: $state');
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
        // If online, update through repository
        await _repository.updateProfile(
          userId: userId,
          preferredTheme: themeString,
        );
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

  @override
  void toggleTheme() {
    final newTheme = state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    dev.log('ThemeNotifier: Toggling theme from $state to $newTheme');
    setTheme(newTheme);
  }

  @override
  String get themeName => ThemePersistence.themeToString(state);
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
