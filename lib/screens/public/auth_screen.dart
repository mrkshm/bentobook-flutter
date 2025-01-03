import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bentobook/features/auth/widgets/login_form.dart';
import 'package:bentobook/features/auth/widgets/signup_form.dart';

import 'package:go_router/go_router.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  int _selectedSegment = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Login / Sign Up'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            context.go('/');
          },
        ),
        centerTitle: true,
        backgroundColor: theme.colorScheme.surface,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              const SizedBox(height: 16),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment<int>(
                    value: 0,
                    label: Text('Login'),
                  ),
                  ButtonSegment<int>(
                    value: 1,
                    label: Text('Sign Up'),
                  ),
                ],
                selected: {_selectedSegment},
                onSelectionChanged: (Set<int> newSelection) {
                  setState(() {
                    _selectedSegment = newSelection.first;
                  });
                },
                style: ButtonStyle(
                  side: WidgetStateProperty.all(BorderSide(
                    color: theme.colorScheme.primary.withAlpha(
                        128), // 0.5 opacity = 128 in alpha (255 * 0.5)
                  )),
                ),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: SingleChildScrollView(
                  child: _selectedSegment == 0
                      ? const LoginForm()
                      : const SignupForm(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
