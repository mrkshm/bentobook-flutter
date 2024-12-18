import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bentobook/providers/theme_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLightTheme = ref.watch(themeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('BentoBook'),
        actions: [
          IconButton(
            icon: Icon(
              isLightTheme ? Icons.dark_mode : Icons.light_mode,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            onPressed: () {
              ref.read(themeProvider.notifier).toggleTheme();
            },
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
              'Current theme: ${isLightTheme ? "Light" : "Dark"}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () {
                ref.read(themeProvider.notifier).toggleTheme();
              },
              icon: Icon(
                isLightTheme ? Icons.dark_mode : Icons.light_mode,
              ),
              label: Text(
                isLightTheme ? 'Switch to Dark Theme' : 'Switch to Light Theme',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
