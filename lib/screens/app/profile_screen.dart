import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bentobook/core/shared/providers.dart';
import 'package:bentobook/core/auth/auth_service.dart';
import 'package:bentobook/core/database/database.dart';
import 'package:bentobook/core/theme/theme.dart';
import 'package:bentobook/core/theme/theme_provider.dart';
import 'dart:developer' as dev;

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  User? _userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authState = ref.read(authServiceProvider);
      final email = authState.maybeMap(
        authenticated: (state) => state.user.attributes.email,
        orElse: () => null,
      );

      if (email != null) {
        final userRepository = ref.read(userRepositoryProvider);
        final user = await userRepository.getUserByEmail(email);
        setState(() {
          _userData = user;
        });
      }
    } catch (e) {
      dev.log('ProfileScreen: Error loading user data', error: e);
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error'),
            content: const Text('Failed to load user data'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          // Theme Settings Card
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: colorScheme.outlineVariant,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      'Appearance',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                  ListTile(
                    title: const Text('Theme Mode'),
                    trailing: SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.light,
                          icon: Icon(Icons.light_mode),
                        ),
                        ButtonSegment(
                          value: ThemeMode.system,
                          icon: Icon(Icons.brightness_auto),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          icon: Icon(Icons.dark_mode),
                        ),
                      ],
                      selected: {ref.watch(themeProvider)},
                      onSelectionChanged: (Set<ThemeMode> selection) {
                        ref.read(themeProvider.notifier).setTheme(selection.first);
                      },
                    ),
                  ),
                  ListTile(
                    title: const Text('Color Scheme'),
                    trailing: PopupMenuButton<String>(
                      icon: Icon(Icons.palette_outlined, color: colorScheme.primary),
                      position: PopupMenuPosition.under,
                      itemBuilder: (context) => AppTheme.schemes.entries.map((scheme) =>
                        PopupMenuItem(
                          value: scheme.key,
                          child: Text(scheme.key),
                        ),
                      ).toList(),
                      onSelected: (String schemeName) {
                        ref.read(colorSchemeProvider.notifier).setSchemeByName(schemeName);
                      },
                    ),
                    subtitle: Text(
                      ref.watch(colorSchemeProvider.notifier).schemeName,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_userData != null) ...[
            // User Info Card
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: colorScheme.outlineVariant,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        'User Information',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                    if (_userData?.email?.isNotEmpty ?? false)
                      ListTile(
                        title: const Text('Email'),
                        subtitle: Text(_userData?.email ?? ''),
                      ),
                    if (_userData?.displayName?.isNotEmpty ?? false)
                      ListTile(
                        title: const Text('Display Name'),
                        subtitle: Text(_userData?.displayName ?? ''),
                      ),
                    if (_userData?.username?.isNotEmpty ?? false)
                      ListTile(
                        title: const Text('Username'),
                        subtitle: Text(_userData?.username ?? ''),
                      ),
                    if (_userData?.firstName?.isNotEmpty ?? false)
                      ListTile(
                        title: const Text('First Name'),
                        subtitle: Text(_userData?.firstName ?? ''),
                      ),
                    if (_userData?.lastName?.isNotEmpty ?? false)
                      ListTile(
                        title: const Text('Last Name'),
                        subtitle: Text(_userData?.lastName ?? ''),
                      ),
                    if (_userData?.about?.isNotEmpty ?? false)
                      ListTile(
                        title: const Text('About'),
                        subtitle: Text(_userData?.about ?? ''),
                      ),
                  ],
                ),
              ),
            ),
          ],

          // Logout Card
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: colorScheme.outlineVariant,
                ),
              ),
              child: ListTile(
                title: Text(
                  'Logout',
                  style: TextStyle(color: colorScheme.error),
                ),
                leading: Icon(Icons.logout, color: colorScheme.error),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Logout'),
                      content: const Text('Are you sure you want to logout?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () async {
                            Navigator.pop(context);
                            await ref.read(authServiceProvider.notifier).logout();
                          },
                          child: const Text('Logout'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}