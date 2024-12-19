import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:bentobook/screens/app/dashboard_screen.dart';
import 'package:bentobook/screens/public/auth_screen.dart';

final router = GoRouter(
  initialLocation: '/',
  debugLogDiagnostics: true,
  routes: [
    GoRoute(
      path: '/',
      pageBuilder: (context, state) => const CupertinoPage(
        child: DashboardScreen(),
      ),
    ),
    GoRoute(
      path: '/auth',
      pageBuilder: (context, state) => const CupertinoPage(
        child: AuthScreen(),
      ),
    ),
  ],
);
