import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bentobook/core/auth/auth_service.dart';
import 'package:bentobook/core/database/database.dart';
import 'package:bentobook/core/repositories/user_repository.dart';
import 'dart:developer' as dev;

// Navigation state
class NavigationState {
  final String targetLocation;
  final bool isTransitioning;

  const NavigationState({
    required this.targetLocation,
    this.isTransitioning = false,
  });
}

final navigationProvider = StateNotifierProvider<NavigationController, NavigationState>((ref) {
  return NavigationController(ref);
});

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

class NavigationController extends StateNotifier<NavigationState> {
  final Ref _ref;
  
  NavigationController(this._ref) : super(const NavigationState(targetLocation: '/')) {
    // Listen to auth state changes
    _ref.listen(authServiceProvider, (previous, next) {
      // Only handle auth state changes if we're not in a transition
      if (!state.isTransitioning) {
        next.maybeWhen(
          error: (_) {
            // On error, go back to auth
            state = NavigationState(targetLocation: '/auth', isTransitioning: false);
          },
          authenticated: (_, __) {
            // On successful auth, go to dashboard
            state = NavigationState(targetLocation: '/dashboard', isTransitioning: false);
          },
          unauthenticated: () {
            // On logout, go to landing
            state = NavigationState(targetLocation: '/', isTransitioning: false);
          },
          orElse: () {},
        );
      }
    });
  }

  // Handle the entire logout flow
  Future<void> logout() async {
    dev.log('Navigation: Starting logout flow');
    // Start transition before anything else
    state = NavigationState(targetLocation: '/auth', isTransitioning: true);
    
    try {
      // Do logout
      await _ref.read(authServiceProvider.notifier).logout();
      
      // Wait a bit for auth state to propagate
      await Future.delayed(const Duration(milliseconds: 100));
      
      // End transition
      state = NavigationState(targetLocation: '/auth', isTransitioning: false);
    } catch (e) {
      dev.log('Navigation: Logout error - $e');
      // End transition even on error
      state = NavigationState(targetLocation: '/auth', isTransitioning: false);
    }
  }

  void startTransition(String target) {
    dev.log('Navigation: Starting transition to $target');
    state = NavigationState(targetLocation: target, isTransitioning: true);
  }

  void endTransition() {
    dev.log('Navigation: Ending transition');
    state = NavigationState(
      targetLocation: state.targetLocation,
      isTransitioning: false,
    );
  }
}