import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bentobook/core/database/database.dart';
import 'package:bentobook/core/repositories/user_repository.dart';
import 'package:bentobook/core/auth/auth_service.dart';
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