import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bentobook/core/auth/auth_service.dart';
import 'package:bentobook/screens/app/dashboard_screen.dart';
import 'package:bentobook/screens/public/auth_screen.dart';
import 'package:bentobook/screens/public/landing_screen.dart';
import 'package:bentobook/screens/public/loading_screen.dart';
import 'dart:developer' as dev;
import 'package:bentobook/core/shared/providers.dart';
import 'package:bentobook/screens/app/profile_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

// Provider to control router redirects
final routerRedirectEnabledProvider = StateProvider<bool>((ref) => true);

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authServiceProvider);
  final authInitState = ref.watch(authInitStateProvider);
  final navState = ref.watch(navigationProvider);
  
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',  // Always start at root
    redirect: (context, state) {
      dev.log('Router: Checking redirect - path: ${state.matchedLocation}');
      dev.log('Router: Auth init state: $authInitState');
      dev.log('Router: Auth state: $authState');
      dev.log('Router: Navigation state - target: ${navState.targetLocation}, transitioning: ${navState.isTransitioning}');
      
      // If we're transitioning, go to target location
      if (navState.isTransitioning && state.matchedLocation != navState.targetLocation) {
        dev.log('Router: Following navigation transition to ${navState.targetLocation}');
        return navState.targetLocation;
      }
      
      // Handle auth initialization states
      switch (authInitState) {
        case AuthInitState.notStarted:
        case AuthInitState.inProgress:
          dev.log('Router: Showing loading screen');
          if (state.matchedLocation != '/loading') {
            return '/loading';
          }
          return null;
          
        case AuthInitState.error:
          dev.log('Router: Auth init error, going to auth');
          return '/auth';
          
        case AuthInitState.completed:
          final isAuthenticated = authState.maybeMap(
            authenticated: (_) => true,
            orElse: () => false,
          );
          
          dev.log('Router: Auth completed - isAuthenticated: $isAuthenticated');

          // If authenticated, always go to dashboard except if already there
          if (isAuthenticated) {
            if (!state.matchedLocation.startsWith('/dashboard')) {
              dev.log('Router: Redirecting to /dashboard - authenticated user');
              return '/dashboard';
            }
            return null;
          }

          // Not authenticated - only allow public routes
          if (!state.matchedLocation.startsWith('/auth') && 
              !state.matchedLocation.startsWith('/loading') &&
              state.matchedLocation != '/') {
            dev.log('Router: Redirecting to /auth - not authenticated');
            return '/auth';
          }

          dev.log('Router: No redirect needed');
          return null;
      }
    },
    routes: [
      // Public routes
      GoRoute(
        path: '/',
        builder: (context, state) => const LandingScreen(),
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: '/loading',
        builder: (context, state) => const LoadingScreen(),
      ),
      
      // Protected routes
      GoRoute(
        path: '/dashboard',
        pageBuilder: (context, state) {
          return CustomTransitionPage(
            key: state.pageKey,
            child: const DashboardScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return SlideTransition(
                position: animation.drive(
                  Tween<Offset>(
                    begin: const Offset(-1.0, 0.0),
                    end: Offset.zero,
                  ).chain(CurveTween(curve: Curves.easeInOut)),
                ),
                child: child,
              );
            },
          );
        },
      ),
      GoRoute(
        path: '/profile',
        pageBuilder: (context, state) {
          return CustomTransitionPage(
            key: state.pageKey,
            child: const ProfileScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return SlideTransition(
                position: animation.drive(
                  Tween<Offset>(
                    begin: const Offset(1.0, 0.0),
                    end: Offset.zero,
                  ).chain(CurveTween(curve: Curves.easeInOut)),
                ),
                child: child,
              );
            },
          );
        },
      ),
    ],
  );
});
