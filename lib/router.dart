import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:page_transition/page_transition.dart';
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
  
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',  // Always start at root
    redirect: (context, state) {
      dev.log('Router: Checking redirect - path: ${state.matchedLocation}');
      dev.log('Router: Auth init state: $authInitState');
      dev.log('Router: Auth state: $authState');
      
      // Get navigation state
      final navStateFresh = ref.read(navigationProvider);  // Fresh read in redirect
      dev.log('Router: Navigation state - target: ${navStateFresh.targetLocation}, transitioning: ${navStateFresh.isTransitioning}');
      
      // If we're transitioning, go to target location
      if (navStateFresh.isTransitioning && state.matchedLocation != navStateFresh.targetLocation) {
        dev.log('Router: Following navigation transition to ${navStateFresh.targetLocation}');
        return navStateFresh.targetLocation;
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

          // If authenticated, allow dashboard and profile routes
          if (isAuthenticated) {
            if (!state.matchedLocation.startsWith('/dashboard') && 
                !state.matchedLocation.startsWith('/profile')) {
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
        pageBuilder: (context, state) {
          return CustomTransitionPage(
            key: state.pageKey,
            child: const LandingScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return PageTransition(
                type: PageTransitionType.leftToRight,
                child: child,
                duration: const Duration(milliseconds: 300),
                reverseDuration: const Duration(milliseconds: 300),
              ).buildTransitions(
                context,
                animation,
                secondaryAnimation,
                child,
              );
            },
          );
        },
      ),
      GoRoute(
        path: '/auth',
        pageBuilder: (context, state) {
          return CustomTransitionPage(
            key: state.pageKey,
            child: const AuthScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return PageTransition(
                type: PageTransitionType.rightToLeft,
                child: child,
                duration: const Duration(milliseconds: 300),
                reverseDuration: const Duration(milliseconds: 300),
              ).buildTransitions(
                context,
                animation,
                secondaryAnimation,
                child,
              );
            },
          );
        },
      ),
      GoRoute(
        path: '/loading',
        pageBuilder: (context, state) {
          return CustomTransitionPage(
            key: state.pageKey,
            child: const LoadingScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return PageTransition(
                type: PageTransitionType.rightToLeft,
                child: child,
                duration: const Duration(milliseconds: 300),
                reverseDuration: const Duration(milliseconds: 300),
              ).buildTransitions(
                context,
                animation,
                secondaryAnimation,
                child,
              );
            },
          );
        },
      ),
      
      // Protected routes
      GoRoute(
        path: '/dashboard',
        pageBuilder: (context, state) {
          final navState = ref.read(navigationProvider);
          return CustomTransitionPage(
            key: state.pageKey,
            child: const DashboardScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return PageTransition(
                type: navState.isBack ? PageTransitionType.leftToRight : PageTransitionType.rightToLeft,
                child: child,
                duration: const Duration(milliseconds: 300),
                reverseDuration: const Duration(milliseconds: 300),
              ).buildTransitions(
                context,
                animation,
                secondaryAnimation,
                child,
              );
            },
          );
        },
      ),
      GoRoute(
        path: '/profile',
        pageBuilder: (context, state) {
          final navState = ref.read(navigationProvider);
          return CustomTransitionPage(
            key: state.pageKey,
            child: const ProfileScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return PageTransition(
                type: navState.isBack ? PageTransitionType.leftToRight : PageTransitionType.rightToLeft,
                child: child,
                duration: const Duration(milliseconds: 300),
                reverseDuration: const Duration(milliseconds: 300),
              ).buildTransitions(
                context,
                animation,
                secondaryAnimation,
                child,
              );
            },
          );
        },
      ),
    ],
  );
});
