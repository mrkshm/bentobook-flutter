import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bentobook/features/auth/models/auth_form_state.dart';
import 'package:bentobook/core/auth/auth_service.dart';
import 'package:bentobook/features/auth/validators.dart';
import 'package:bentobook/features/auth/widgets/shared/auth_text_field.dart';
import 'dart:developer' as dev;
import 'package:bentobook/core/shared/providers.dart';

class LoginForm extends ConsumerStatefulWidget {
  const LoginForm({super.key});

  @override
  ConsumerState<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends ConsumerState<LoginForm> {
  var _formState = const LoginFormState();

  void _validateEmail(String value) {
    final error = AuthValidators.validateEmail(value);
    
    final newState = LoginFormState(
      email: value,
      password: _formState.password,
      emailError: error,
      passwordError: _formState.passwordError,
    );
    
    setState(() {
      _formState = newState;
    });
  }

  void _validatePassword(String value) {
    final error = AuthValidators.validatePassword(value);
    
    final newState = LoginFormState(
      email: _formState.email,
      password: value,
      emailError: _formState.emailError,
      passwordError: error,
    );
    
    setState(() {
      _formState = newState;
    });
  }

  Future<void> _handleSubmit() async {
    dev.log('LoginForm: Handling submit');
    if (_formState.isValid) {
      dev.log('LoginForm: Form is valid, attempting login');
      
      try {
        // Start transition to dashboard and keep it transitioning until we're done
        ref.read(navigationProvider.notifier).startTransition('/dashboard');
        
        // Do login
        await ref.read(authServiceProvider.notifier).login(
          email: _formState.email,
          password: _formState.password,
        );
        
        // Check auth state
        final authState = ref.read(authServiceProvider);
        
        // Only end transition if login was successful
        if (mounted && authState.maybeWhen(
          authenticated: (_, __) => true,
          orElse: () => false,
        )) {
          // Wait a bit for auth state to propagate
          await Future.delayed(const Duration(milliseconds: 100));
          ref.read(navigationProvider.notifier).endTransition();
        }
      } catch (e) {
        dev.log('LoginForm: Login error - $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString())),
          );
        }
      }
    } else {
      dev.log('LoginForm: Form is invalid');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authServiceProvider);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        authState.maybeWhen(
          error: (message) => Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              message,
              style: TextStyle(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
          orElse: () => const SizedBox.shrink(),
        ),
        const SizedBox(height: 16),
        AuthTextField(
          placeholder: 'Email',
          keyboardType: TextInputType.emailAddress,
          errorText: _formState.emailError,
          onChanged: _validateEmail,
        ),
        const SizedBox(height: 12),
        AuthTextField(
          placeholder: 'Password',
          obscureText: true,
          errorText: _formState.passwordError,
          onChanged: _validatePassword,
        ),
        const SizedBox(height: 24),
        CupertinoButton.filled(
          onPressed: authState.maybeWhen(
            loading: () => null,
            orElse: () => _handleSubmit,
          ),
          child: authState.maybeWhen(
            loading: () => const CupertinoActivityIndicator(),
            orElse: () => const Text('Login'),
          ),
        ),
      ],
    );
  }
}
