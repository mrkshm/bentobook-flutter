import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bentobook/core/auth/auth_service.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authServiceProvider);

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('BentoBook'),
      ),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                const Text(
                  'Welcome to BentoBook',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                authState.when(
                  initial: () => const SizedBox.shrink(),
                  loading: () => const Center(
                    child: CupertinoActivityIndicator(),
                  ),
                  authenticated: (user, _) => Text(
                    'Logged in as ${user.attributes.email}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 17,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                  unauthenticated: () => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: CupertinoButton.filled(
                      onPressed: () => context.push('/auth'),
                      child: const Text('Login / Sign Up'),
                    ),
                  ),
                  error: (message) => Text(
                    'Error: $message',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: CupertinoColors.systemRed,
                    ),
                  ),
                ),
                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}