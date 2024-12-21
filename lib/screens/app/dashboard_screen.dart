import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bentobook/core/shared/providers.dart';
import 'package:bentobook/core/auth/auth_service.dart';
import 'dart:developer' as dev;

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String _testResult = '';

  Future<void> _showCurrentUser() async {
    final userRepository = ref.read(userRepositoryProvider);
    final authState = ref.read(authServiceProvider);
    
    dev.log('DashboardScreen: Current auth state: $authState');
    
    final user = authState.maybeMap(
      authenticated: (state) => state.user,
      orElse: () => null,
    );
    
    if (user == null) {
      setState(() {
        _testResult = 'No user is logged in';
      });
      return;
    }

    try {
      dev.log('DashboardScreen: Looking up user with email: ${user.attributes.email}');
      final userFromDatabase = await userRepository.getUserByEmail(user.attributes.email);
      dev.log('DashboardScreen: Database lookup result: $userFromDatabase');
      
      if (userFromDatabase != null) {
        setState(() {
          _testResult = 'Current User:\n'
            '- Email: ${userFromDatabase.email}\n'
            '- Display Name: ${userFromDatabase.displayName ?? "Not set"}\n'
            '- Username: ${userFromDatabase.username ?? "Not set"}\n'
            '- First Name: ${userFromDatabase.firstName ?? "Not set"}\n'
            '- Last Name: ${userFromDatabase.lastName ?? "Not set"}\n'
            '- About: ${userFromDatabase.about ?? "Not set"}\n'
            '- Theme: ${userFromDatabase.preferredTheme}\n'
            '- Language: ${userFromDatabase.preferredLanguage}';
        });
      } else {
        setState(() {
          _testResult = 'User not found in local database';
        });
      }
    } catch (e) {
      dev.log('DashboardScreen: Error getting user data', error: e);
      setState(() {
        _testResult = 'Error getting user data: $e';
      });
    }
  }

  Future<void> _showAllUsers() async {
    final userRepository = ref.read(userRepositoryProvider);
    try {
      final users = await userRepository.getAllUsers();
      setState(() {
        _testResult = 'Found ${users.length} users:\n'
            '${users.map((user) => '- ${user.displayName ?? user.email} (${user.email})').join('\n')}';
      });
    } catch (e) {
      setState(() {
        _testResult = 'Error: $e';
      });
    }
  }

  void _handleLogout() async {
    dev.log('DashboardScreen: Logging out');
    await ref.read(navigationProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authServiceProvider);
    final user = authState.maybeMap(
      authenticated: (state) => state.user,
      orElse: () => null,
    );

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    dev.log('DashboardScreen: Building with user: ${user.attributes.email}');
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        centerTitle: true,
        backgroundColor: theme.colorScheme.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () {
              dev.log('Dashboard: Going to profile');
              ref.read(navigationProvider.notifier).startTransition('/profile');
            },
          ),
          TextButton.icon(
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
            onPressed: _handleLogout,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                Text(
                  'Welcome, ${user.attributes.email}!',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _showCurrentUser,
                        child: const Text('Show Current User'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _showAllUsers,
                        child: const Text('Show All Users'),
                      ),
                    ),
                  ],
                ),
                if (_testResult.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        _testResult,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontFamily: 'Menlo',
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}