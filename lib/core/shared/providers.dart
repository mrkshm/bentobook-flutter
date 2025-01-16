import 'package:bentobook/core/api/api_client.dart';
import 'package:bentobook/core/auth/auth_service.dart';
import 'package:bentobook/core/database/database.dart';
import 'package:bentobook/core/network/connectivity_service.dart';
import 'package:bentobook/core/profile/profile_repository.dart';
import 'package:bentobook/core/sync/queue_manager.dart';
import 'package:bentobook/core/sync/resolvers/profile_resolver.dart';
import 'package:bentobook/core/image/image_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bentobook/core/repositories/user_repository.dart';
import 'package:bentobook/core/config/env_config.dart';
import 'dart:developer' as dev;
import 'package:bentobook/core/sync/conflict_resolver.dart';

// Database providers
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

final appDatabaseProvider = Provider<AppDatabase>((ref) => AppDatabase());

// Environment config
final envConfigProvider = Provider<EnvConfig>((ref) {
  return EnvConfig.development();
});

// API Client
final apiClientProvider = Provider<ApiClient>((ref) {
  final config = ref.watch(envConfigProvider);
  return ApiClient(config: config);
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return UserRepository(db);
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(
    db: ref.read(databaseProvider),
    apiClient: ref.read(apiClientProvider),
    queueManager: ref.read(QueueManager.currentProvider),
    resolver: ref.read(conflictResolverProvider),
    config: ref.read(envConfigProvider),
    imageManager: ref.read(imageManagerProvider),
  );
});

// Auth initialization state
enum AuthInitState {
  notStarted,
  inProgress,
  completed,
  error,
}

final authInitStateProvider =
    StateProvider<AuthInitState>((ref) => AuthInitState.notStarted);

// Auth initialization controller
final authInitControllerProvider = Provider((ref) {
  return AuthInitController(ref);
});

class AuthInitController {
  final Ref _ref;

  AuthInitController(this._ref);

  Future<void> initialize() async {
    if (_ref.read(authInitStateProvider) != AuthInitState.notStarted) {
      return;
    }

    try {
      _ref.read(authInitStateProvider.notifier).state =
          AuthInitState.inProgress;

      final authService = _ref.read(authServiceProvider.notifier);
      await authService.initializeAuth();

      _ref.read(authInitStateProvider.notifier).state = AuthInitState.completed;
    } catch (e) {
      dev.log('AuthInit: Error during initialization: $e');
      _ref.read(authInitStateProvider.notifier).state = AuthInitState.error;
    }
  }
}

final conflictResolverProvider = Provider<ConflictResolver>((ref) {
  return ConflictResolver(
    resolvers: {
      'profile': ProfileResolver(),
    },
  );
});

final imageManagerProvider = Provider<ImageManager>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ImageManager(dio: apiClient.dio);
});
