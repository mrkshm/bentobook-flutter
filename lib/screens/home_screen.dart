import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bentobook/theme/theme_provider.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:bentobook/theme/theme.dart';
import 'package:bentobook/core/auth/auth_service.dart';
import 'package:bentobook/core/auth/auth_state.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final colorScheme = ref.watch(colorSchemeProvider);
    final isSubscribed = ref.watch(isSubscribedProvider);
    final isDarkMode = themeMode == ThemeMode.dark || 
        (themeMode == ThemeMode.system && 
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    return Scaffold(
      appBar: AppBar(
        title: const Text('BentoBook'),
        actions: [
          if (isSubscribed) // Only show color scheme picker for subscribers
            PopupMenuButton<FlexScheme>(
              icon: const Icon(Icons.palette),
              initialValue: colorScheme,
              onSelected: (FlexScheme scheme) {
                ref.read(colorSchemeProvider.notifier).setScheme(scheme);
              },
              itemBuilder: (BuildContext context) => [
                for (final scheme in AppTheme.schemes.entries)
                  PopupMenuItem<FlexScheme>(
                    value: scheme.value,
                    child: Row(
                      children: [
                        Icon(Icons.color_lens, 
                          color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(scheme.key.toUpperCase()),
                      ],
                    ),
                  ),
              ],
            )
          else
            IconButton(
              icon: const Icon(Icons.palette),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Premium Feature'),
                    content: const Text(
                      'Custom color schemes are available for premium subscribers only.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Maybe Later'),
                      ),
                      FilledButton(
                        onPressed: () {
                          // Add your subscription flow here
                          Navigator.pop(context);
                        },
                        child: const Text('Upgrade Now'),
                      ),
                    ],
                  ),
                );
              },
            ),
          PopupMenuButton<ThemeMode>(
            icon: Icon(
              isDarkMode ? Icons.dark_mode : Icons.light_mode,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            initialValue: themeMode,
            onSelected: (ThemeMode mode) {
              ref.read(themeProvider.notifier).setTheme(mode);
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<ThemeMode>>[
              const PopupMenuItem<ThemeMode>(
                value: ThemeMode.light,
                child: Row(
                  children: [
                    Icon(Icons.light_mode),
                    SizedBox(width: 8),
                    Text('Light'),
                  ],
                ),
              ),
              const PopupMenuItem<ThemeMode>(
                value: ThemeMode.dark,
                child: Row(
                  children: [
                    Icon(Icons.dark_mode),
                    SizedBox(width: 8),
                    Text('Dark'),
                  ],
                ),
              ),
              const PopupMenuItem<ThemeMode>(
                value: ThemeMode.system,
                child: Row(
                  children: [
                    Icon(Icons.settings_suggest),
                    SizedBox(width: 8),
                    Text('System'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Welcome to BentoBook!',
              style: TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 20),
            Text(
              'Current theme: ${themeMode.name.toUpperCase()}\n'
              'Color scheme: ${colorScheme.name.toUpperCase()}'
              '${!isSubscribed ? " (Upgrade for more themes)" : ""}',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  final authService = ref.read(authServiceProvider.notifier);
                  await authService.login(
                    'marc.haussmann@gmail.com',
                    'M4markus'
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              },
              child: const Text('Test Login'),
            ),
            Consumer(
              builder: (context, ref, _) {
                final authState = ref.watch(authServiceProvider);
                
                // Show SnackBar on state changes
                ref.listen<AuthState>(authServiceProvider, (previous, current) {
                  current.whenOrNull(
                    authenticated: (user, _) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Welcome back, ${user.attributes.email}!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                    unauthenticated: () {
                      if ((previous)?.maybeWhen(
                        authenticated: (_, __) => true,
                        orElse: () => false,
                      ) ?? false) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Successfully logged out'),
                            backgroundColor: Colors.blue,
                          ),
                        );
                      }
                    },
                    error: (message) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(message),
                          backgroundColor: Colors.red,
                        ),
                      );
                    },
                  );
                });

                return authState.when(
                  initial: () => const SizedBox.shrink(),
                  loading: () => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  authenticated: (user, token) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Logged in as: ${user.attributes.email}'),
                      ElevatedButton(
                        onPressed: () {
                          ref.read(authServiceProvider.notifier).logout();
                        },
                        child: const Text('Logout'),
                      ),
                    ],
                  ),
                  unauthenticated: () => const Text('Not logged in'),
                  error: (message) => Text('Error: $message', style: TextStyle(color: Colors.red)),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}