import 'package:bentobook/core/api/api_client.dart';
import 'package:bentobook/core/network/connectivity_service.dart';
import 'package:bentobook/core/sync/queue_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bentobook/core/database/database.dart';
import 'package:bentobook/core/repositories/user_repository.dart';
import 'package:bentobook/core/auth/auth_service.dart';
import 'package:bentobook/core/profile/profile_provider.dart';
import 'package:bentobook/core/profile/profile_repository.dart';
import 'dart:developer' as dev;

// Database providers
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return UserRepository(db);
});

final appDatabaseProvider = Provider<AppDatabase>((ref) => AppDatabase());

final queueManagerProvider = Provider<QueueManager>((ref) {
  final db = ref.watch(databaseProvider);
  final api = ref.watch(apiClientProvider);
  final connectivity = ref.watch(connectivityProvider);
  return QueueManager(
    db: db, 
    api: api,
    connectivity: connectivity,
  );
});

// Profile providers
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final db = ref.watch(databaseProvider);
  final authState = ref.watch(authServiceProvider);
  final authService = ref.read(authServiceProvider.notifier);
  return ProfileRepository(apiClient, db, authState, authService);
});

final profileProvider = StateNotifierProvider<ProfileNotifier, ProfileState>((ref) {
  final repository = ref.watch(profileRepositoryProvider);
  final notifier = ProfileNotifier(repository);
  
  // Initialize profile from auth state
  ref.read(authServiceProvider).maybeMap(
    authenticated: (state) {
      Future.microtask(() {
        notifier.initializeProfile(state.user);
      });
    },
    orElse: () {},
  );
  
  return notifier;
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