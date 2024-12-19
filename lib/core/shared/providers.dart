import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bentobook/core/auth/auth_state.dart';
import 'package:bentobook/core/auth/auth_service.dart';
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
    state = NavigationState(targetLocation: '/', isTransitioning: true);
    
    try {
      // Do logout
      await _ref.read(authServiceProvider.notifier).logout();
      
      // Wait a bit for auth state to propagate
      await Future.delayed(const Duration(milliseconds: 100));
      
      // End transition
      state = NavigationState(targetLocation: '/', isTransitioning: false);
    } catch (e) {
      dev.log('Navigation: Logout error - $e');
      // End transition even on error
      state = NavigationState(targetLocation: '/', isTransitioning: false);
    }
  }

  void startTransition(String target) {
    // Check current auth state
    final authState = _ref.read(authServiceProvider);
    
    authState.maybeWhen(
      error: (_) {
        // If in error state, always go to auth
        dev.log('Navigation: Auth error, redirecting to auth');
        state = NavigationState(targetLocation: '/auth', isTransitioning: false);
      },
      authenticated: (_, __) {
        // If authenticated and trying to go to auth/landing, redirect to dashboard
        if (target == '/auth' || target == '/') {
          dev.log('Navigation: Authenticated, redirecting to dashboard');
          state = NavigationState(targetLocation: '/dashboard', isTransitioning: true);
        } else {
          dev.log('Navigation: Starting transition to $target');
          state = NavigationState(targetLocation: target, isTransitioning: true);
        }
      },
      unauthenticated: () {
        // Allow navigation to any public route
        dev.log('Navigation: Starting transition to $target');
        state = NavigationState(targetLocation: target, isTransitioning: true);
      },
      orElse: () {
        dev.log('Navigation: Starting transition to $target');
        state = NavigationState(targetLocation: target, isTransitioning: true);
      },
    );
  }

  void endTransition() {
    dev.log('Navigation: Ending transition');
    state = NavigationState(
      targetLocation: state.targetLocation,
      isTransitioning: false,
    );
  }
}