import 'package:bentobook/core/profile/profile_provider.dart';
import 'package:bentobook/core/profile/profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bentobook/core/auth/auth_service.dart';
import 'package:bentobook/core/theme/theme_provider.dart';
import 'package:bentobook/core/shared/providers.dart';
import 'dart:developer' as dev;

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = ref.watch(colorSchemeProvider);
    final authState = ref.watch(authServiceProvider);
    final profileState = ref.watch(profileProvider);
    final userId = authState.maybeMap(
      authenticated: (state) => state.userId,
      orElse: () => null,
    );

    if (userId == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final profile = profileState.profile;
    if (profileState.isLoading || profile == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: true,
        backgroundColor: theme.colorScheme.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/app/dashboard'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Profile Card
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: theme.colorScheme.outlineVariant,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          'Personal Information',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      ListTile(
                        title: const Text('Display Name'),
                        subtitle: Text(profile.attributes.displayName ?? 'Not set'),
                      ),
                      ListTile(
                        title: const Text('Username'),
                        subtitle: Text(profile.attributes.username),
                      ),
                      ListTile(
                        title: const Text('First Name'),
                        subtitle: Text(profile.attributes.firstName ?? 'Not set'),
                      ),
                      ListTile(
                        title: const Text('Last Name'),
                        subtitle: Text(profile.attributes.lastName ?? 'Not set'),
                      ),
                      ListTile(
                        title: const Text('Email'),
                        subtitle: Text(profile.attributes.email.isNotEmpty 
                            ? profile.attributes.email
                            : 'Not set'),
                      ),
                    ],
                  ),
                ),
              ),

              // About Card
              if (profile.attributes.about?.isNotEmpty ?? false)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Text(
                            'About',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Text(
                            profile.attributes.about!,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Preferences Card
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: theme.colorScheme.outlineVariant,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          'Preferences',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      if (profile.attributes.preferredLanguage != null)
                        ListTile(
                          title: const Text('Language'),
                          subtitle:
                              Text(profile.attributes.preferredLanguage!),
                        ),
                    ],
                  ),
                ),
              ),

              // Test Button
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: ElevatedButton(
                  onPressed: () async {
                    try {
                      final apiClient = ref.read(apiClientProvider);
                      final db = ref.read(databaseProvider);
                      final repository = ProfileRepository(apiClient, db);
                      await repository.updateProfile(
                        userId: userId,
                        firstName: 'John',
                        lastName: 'Doe',
                      );
                      dev.log('Profile updated successfully');
                    } catch (e) {
                      dev.log('Error updating profile', error: e);
                    }
                  },
                  child: const Text('Update Profile Test'),
                ),
              ),
              const SizedBox(height: 16),

              // Logout Card
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: theme.colorScheme.outlineVariant,
                    ),
                  ),
                  child: ListTile(
                    title: Text(
                      'Logout',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                    leading: Icon(Icons.logout, color: theme.colorScheme.error),
                    onTap: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Logout'),
                          content: const Text('Are you sure you want to logout?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Logout'),
                            ),
                          ],
                        ),
                      );

                      if (confirmed == true) {
                        await ref.read(authServiceProvider.notifier).logout();
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
