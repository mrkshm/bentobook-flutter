import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bentobook/features/auth/models/auth_form_state.dart';
import 'package:bentobook/features/auth/providers/auth_provider.dart';
import 'package:bentobook/features/auth/validators.dart';
import 'package:bentobook/features/auth/widgets/shared/auth_text_field.dart';

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
    if (_formState.isValid) {
      final success = await ref.read(authProvider.notifier).login(
        email: _formState.email,
        password: _formState.password,
      );
      
      if (mounted && success) {
        context.go('/dashboard');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authProvider);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (authState.error != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              authState.error!,
              style: TextStyle(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
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
          onPressed: _formState.isValid && !authState.isLoading 
            ? _handleSubmit 
            : null,
          child: authState.isLoading
            ? const CupertinoActivityIndicator(color: CupertinoColors.white)
            : Text(
                'Login',
                style: TextStyle(
                  color: _formState.isValid 
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onPrimary.withOpacity(0.7),
                ),
              ),
        ),
      ],
    );
  }
}
