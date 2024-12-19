import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bentobook/core/auth/auth_service.dart';
import 'package:bentobook/screens/app/dashboard_screen.dart';
import 'package:bentobook/screens/public/auth_screen.dart';
import 'package:bentobook/screens/public/landing_screen.dart';
import 'dart:developer' as dev;
import 'package:bentobook/core/shared/providers.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

// Provider to control router redirects
final routerRedirectEnabledProvider = StateProvider<bool>((ref) => true);

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authServiceProvider);
  final navState = ref.watch(navigationProvider);
  
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: navState.targetLocation,
    redirect: (context, state) {
      dev.log('Router: Checking redirect - path: ${state.matchedLocation}');
      dev.log('Router: Auth state: ${authState.toString()}');
      
      // Skip redirects during transitions
      if (navState.isTransitioning) {
        dev.log('Router: In transition, skipping redirect');
        return null;
      }
      
      // Always respect navigation controller's target location
      if (state.matchedLocation != navState.targetLocation) {
        dev.log('Router: Redirecting to navigation target: ${navState.targetLocation}');
        return navState.targetLocation;
      }
      
      return authState.when(
        initial: () => null,
        loading: () => null,
        authenticated: (user, token) {
          dev.log('Router: Authenticated state - user: ${user.attributes.email}');
          // Always redirect to dashboard when authenticated
          return '/dashboard';
        },
        unauthenticated: () {
          dev.log('Router: Unauthenticated state');
          // Only allow public routes when unauthenticated
          final isPublicRoute = state.matchedLocation == '/' || 
                              state.matchedLocation == '/auth';
          return isPublicRoute ? null : '/';
        },
        error: (_) => '/auth',
      );
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
      
      // Protected routes
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
    ],
  );
});
