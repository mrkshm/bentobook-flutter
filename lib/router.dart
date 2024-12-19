import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bentobook/features/auth/providers/auth_provider.dart';
import 'package:bentobook/screens/app/dashboard_screen.dart';
import 'package:bentobook/screens/public/auth_screen.dart';
import 'package:bentobook/screens/public/landing_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    redirect: (context, state) {
      // Only protect app routes (anything not starting with /auth or /)
      final isPublicRoute = state.matchedLocation == '/' || 
                          state.matchedLocation == '/auth';
      
      if (!isPublicRoute && !authState.isAuthenticated) {
        return '/auth';
      }
      
      return null;
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
