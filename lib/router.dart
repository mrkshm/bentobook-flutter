import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:page_transition/page_transition.dart';
import 'package:bentobook/core/auth/auth_service.dart';
import 'package:bentobook/screens/app/dashboard_screen.dart';
import 'package:bentobook/screens/public/auth_screen.dart';
import 'package:bentobook/screens/public/landing_screen.dart';
import 'package:bentobook/screens/public/loading_screen.dart';
import 'package:bentobook/screens/app/profile_screen.dart';
import 'dart:developer' as dev;

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authServiceProvider);
  
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      dev.log('Router: Checking redirect - path: ${state.matchedLocation}');

      // Handle loading state
      if (authState.maybeMap(
        initial: (_) => true,
        loading: (_) => true,
        orElse: () => false,
      )) {
        return '/public/loading';
      }

      final isAuthenticated = authState.maybeMap(
        authenticated: (_) => true,
        orElse: () => false,
      );

      // Always redirect authenticated users to dashboard if they're in public area
      if (isAuthenticated && state.matchedLocation.startsWith('/public')) {
        dev.log('Router: Authenticated user in public area - redirecting to dashboard');
        return '/app/dashboard';
      }

      // Redirect unauthenticated users to landing if they try to access app area
      if (!isAuthenticated && state.matchedLocation.startsWith('/app')) {
        dev.log('Router: Unauthenticated user in app area - redirecting to landing');
        return '/public/landing';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        redirect: (_, __) => '/public/landing',
      ),
      // Public routes
      GoRoute(
        path: '/public/landing',
        builder: (context, state) => const LandingScreen(),
      ),
      GoRoute(
        path: '/public/auth',
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: '/public/loading',
        builder: (context, state) => const LoadingScreen(),
      ),
      // App routes
      GoRoute(
        path: '/app/dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/app/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
    ],
  );
});
