import 'package:bentobook/core/shared/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bentobook/core/profile/profile_provider.dart';
import 'package:bentobook/core/auth/auth_service.dart' show authServiceProvider;
import 'dart:developer' as dev;

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String _testResult = '';

  @override
  void initState() {
    super.initState();
    dev.log('DashboardScreen: initState');
  }

  void _showCurrentUser() {
    final authState = ref.read(authServiceProvider);

    dev.log('DashboardScreen: Current auth state: $authState');

    final userId = authState.maybeMap(
      authenticated: (state) => state.userId,
      orElse: () => null,
    );

    setState(() {
      _testResult =
          userId != null ? 'Current User ID: $userId' : 'No user is logged in';
    });
  }

  void _showProfileState() {
    final profileState = ref.read(profileProvider);
    final config = ref.read(envConfigProvider);
    dev.log('DashboardScreen: Profile state details:');
    dev.log('- Loading: ${profileState.isLoading}');
    dev.log('- Has Profile: ${profileState.profile != null}');
    dev.log('- Profile Data: ${profileState.profile?.toJson()}');
    dev.log('- Error: ${profileState.error}');

    setState(() {
      _testResult = '''Current Profile State:
Loading: ${profileState.isLoading}
Error: ${profileState.error ?? 'None'}
Profile Data:
${profileState.profile != null ? '''
  - Username: ${profileState.profile!.attributes.username}
  - Display Name: ${profileState.profile!.attributes.displayName}
  - Email: ${profileState.profile!.attributes.email}
  
Avatar URLs (Full):
  - Thumbnail: ${profileState.profile!.attributes.avatarUrls?.thumbnail != null ? '${config.baseUrl}${profileState.profile!.attributes.avatarUrls!.thumbnail}' : 'None'}
  - Small: ${profileState.profile!.attributes.avatarUrls?.small != null ? '${config.baseUrl}${profileState.profile!.attributes.avatarUrls!.small}' : 'None'}
  - Medium: ${profileState.profile!.attributes.avatarUrls?.medium != null ? '${config.baseUrl}${profileState.profile!.attributes.avatarUrls!.medium}' : 'None'}
  - Large: ${profileState.profile!.attributes.avatarUrls?.large != null ? '${config.baseUrl}${profileState.profile!.attributes.avatarUrls!.large}' : 'None'}
  - Original: ${profileState.profile!.attributes.avatarUrls?.original != null ? '${config.baseUrl}${profileState.profile!.attributes.avatarUrls!.original}' : 'None'}''' : 'No profile data available'}''';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authServiceProvider);
    // Actively watch profile state
    final profileState = ref.watch(profileProvider);

    dev.log('DashboardScreen: Build with profile state - '
        'loading: ${profileState.isLoading}, '
        'hasProfile: ${profileState.profile != null}, '
        'error: ${profileState.error}');

    return authState.map(
      initial: (_) => const Scaffold(
        body: Center(child: Text('Initializing...')),
      ),
      loading: (_) => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      authenticated: (state) {
        final userId = state.userId;
        dev.log('DashboardScreen: Building with userId: $userId');

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
                  context.go('/app/profile');
                },
              ),
              TextButton.icon(
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
                onPressed: () async {
                  dev.log('Dashboard: Logging out');
                  await ref.read(authServiceProvider.notifier).logout();
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 24),
                        Text(
                          'Welcome! (ID: $userId)',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _showCurrentUser,
                          child: const Text('Show Current User ID'),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _showProfileState,
                          child: const Text('Show Profile State'),
                        ),
                        if (_testResult.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _testResult,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      unauthenticated: (_) {
        // Redirect to login
        WidgetsBinding.instance.addPostFrameCallback((_) {
          context.go('/public/login');
        });
        return const Scaffold(
          body: Center(child: Text('Redirecting to login...')),
        );
      },
      error: (state) => Scaffold(
        body: Center(child: Text('Error: ${state.message}')),
      ),
    );
  }
}
