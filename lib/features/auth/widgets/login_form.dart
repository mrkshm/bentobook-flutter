import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bentobook/core/auth/auth_service.dart';
import 'package:bentobook/features/auth/validators.dart';
import 'dart:developer' as dev;
import 'package:flutter/foundation.dart' as foundation;

class LoginForm extends ConsumerStatefulWidget {
  const LoginForm({super.key});

  @override
  ConsumerState<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends ConsumerState<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _error;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    // Method 1: print
    print('DEBUG_TEST_1: Basic print statement');

    // Method 2: debugPrint
    foundation.debugPrint('DEBUG_TEST_2: Using debugPrint');

    // Method 3: developer.log
    dev.log('DEBUG_TEST_3: Using developer.log', name: 'auth.form');

    // Method 4: Flutter's logging
    const String message = 'DEBUG_TEST_4: Flutter logging';
    foundation.FlutterError.reportError(
      foundation.FlutterErrorDetails(
        exception: message,
        library: 'auth.form',
      ),
    );

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _error = null;
      _isLoading = true;
    });

    try {
      dev.log('Attempting login with email: ${_emailController.text}',
          name: 'auth.form');
      await ref.read(authServiceProvider.notifier).login(
            _emailController.text,
            _passwordController.text,
          );
      dev.log('Login API call completed', name: 'auth.form');
    } catch (e) {
      dev.log('Login error occurred', error: e, name: 'auth.form');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
    dev.log('===== LOGIN END =====', name: 'auth.form');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Listen to auth state changes
    ref.listen(authServiceProvider, (previous, next) {
      dev.log('🔐 LOGIN_FORM: Auth state changed from $previous to $next',
          name: 'auth.login');
      next.maybeMap(
        authenticated: (_) {
          dev.log(
              '🔐 LOGIN_FORM: Successfully authenticated, navigating to dashboard',
              name: 'auth.login');
          if (mounted) {
            context.go('/app/dashboard');
          }
        },
        error: (state) {
          dev.log('🔐 LOGIN_FORM: Auth error state: ${state.message}',
              name: 'auth.login');
          if (mounted) {
            setState(() {
              _error = state.message;
              _isLoading = false;
            });
          }
        },
        orElse: () {},
      );
    });

    return Form(
      key: _formKey,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'Enter your email',
              ),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              validator: AuthValidators.validateEmail,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                hintText: 'Enter your password',
              ),
              obscureText: true,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              validator: AuthValidators.validatePassword,
              onFieldSubmitted: (_) => _handleSubmit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isLoading
                  ? null
                  : () {
                      print('DEBUG_TEST_5: Button pressed');
                      _handleSubmit();
                    },
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Login'),
            ),
          ],
        ),
      ),
    );
  }
}
