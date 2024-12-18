import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:bentobook/screens/home_screen.dart';

final router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
  ],
);
