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
    redirect: (context, state) {
      dev.log('Router: Checking redirect - path: ${state.matchedLocation}');
      
      return authState.maybeMap(
        authenticated: (_) {
          // If already on a valid authenticated route, don't redirect
          if (state.matchedLocation == '/dashboard' || 
              state.matchedLocation == '/profile') {
            return null;
          }
          return '/dashboard';
        },
        unauthenticated: (_) {
          // If already on a valid public route, don't redirect
          if (state.matchedLocation == '/' || 
              state.matchedLocation == '/auth') {
            return null;
          }
          return '/';
        },
        initial: (_) => '/loading',
        loading: (_) => '/loading',
        error: (_) => '/auth',
        orElse: () => null,
      );
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
          return CustomTransitionPage(
            key: state.pageKey,
            child: const DashboardScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              final isBack = state.extra as bool? ?? false;
              return PageTransition(
                type: isBack ? PageTransitionType.leftToRight : PageTransitionType.rightToLeft,
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
          return CustomTransitionPage(
            key: state.pageKey,
            child: const ProfileScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              final isBack = state.extra as bool? ?? false;
              return PageTransition(
                type: isBack ? PageTransitionType.leftToRight : PageTransitionType.rightToLeft,
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
