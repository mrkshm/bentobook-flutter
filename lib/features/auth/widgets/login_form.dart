import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bentobook/core/shared/providers.dart';
import 'package:bentobook/features/auth/providers/auth_provider.dart';
import 'package:bentobook/core/auth/auth_state.dart';
import 'dart:developer' as dev;

class LoginForm extends ConsumerStatefulWidget {
  const LoginForm({super.key});

  @override
  ConsumerState<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends ConsumerState<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final success = await ref.read(authProvider.notifier).login(
        email: _emailController.text,
        password: _passwordController.text,
      );

      if (success) {
        dev.log('LoginForm: Login successful');
        ref.read(navigationProvider.notifier).startTransition('/dashboard');
      } else {
        final authState = ref.read(authProvider);
        authState.maybeMap(
          error: (state) => setState(() {
            _error = state.message;
          }),
          orElse: () => setState(() {
            _error = 'Login failed';
          }),
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = authState.maybeMap(
      loading: (_) => true,
      orElse: () => false,
    );
    
    return Form(
      key: _formKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CupertinoTextFormFieldRow(
            controller: _emailController,
            placeholder: 'Email',
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your email';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          CupertinoTextFormFieldRow(
            controller: _passwordController,
            placeholder: 'Password',
            obscureText: true,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your password';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          if (_error != null) ...[
            Text(
              _error!,
              style: const TextStyle(
                color: CupertinoColors.destructiveRed,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
          ],
          CupertinoButton.filled(
            onPressed: _isLoading || isLoading ? null : _handleSubmit,
            child: _isLoading || isLoading
                ? const CupertinoActivityIndicator()
                : const Text('Login'),
          ),
        ],
      ),
    );
  }
}
