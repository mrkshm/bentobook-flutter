import 'package:bentobook/core/api/api_client.dart';
import 'package:bentobook/core/network/connectivity_service.dart';
import 'package:bentobook/core/sync/queue_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bentobook/core/database/database.dart';
import 'package:bentobook/core/auth/auth_service.dart';
import 'package:bentobook/core/config/env_config.dart';
import 'dart:developer' as dev;

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

final queueManagerProvider = Provider<QueueManager>((ref) {
  final db = ref.watch(databaseProvider);
  final api = ref.watch(apiClientProvider);
  final connectivity = ref.watch(connectivityProvider);
  final authState = ref.watch(authServiceProvider);
  final userId = authState.maybeMap(
    authenticated: (state) => state.userId,
    orElse: () => null
  );
  
  return QueueManager(
    db: db, 
    api: api,
    connectivity: connectivity,
    userId: userId
  );
});

// Auth initialization state
enum AuthInitState {
  notStarted,
  inProgress,
  completed,
  error,
}

final authInitStateProvider = StateProvider<AuthInitState>((ref) => AuthInitState.notStarted);

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
      _ref.read(authInitStateProvider.notifier).state = AuthInitState.inProgress;
      
      final authService = _ref.read(authServiceProvider.notifier);
      await authService.initializeAuth();

      _ref.read(authInitStateProvider.notifier).state = AuthInitState.completed;
    } catch (e) {
      dev.log('AuthInit: Error during initialization: $e');
      _ref.read(authInitStateProvider.notifier).state = AuthInitState.error;
    }
  }
}