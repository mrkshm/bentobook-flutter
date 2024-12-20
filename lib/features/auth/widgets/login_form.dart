import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bentobook/core/shared/providers.dart';
import 'package:bentobook/core/auth/auth_service.dart';
import 'package:bentobook/core/auth/auth_state.dart';
import 'package:bentobook/features/auth/validators.dart';
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
  bool _isFormValid = false;
  bool _emailTouched = false;
  bool _passwordTouched = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _validateForm() {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (_isFormValid != isValid) {
      setState(() {
        _isFormValid = isValid;
      });
    }
  }

  String? _validateEmail(String? value) {
    if (!_emailTouched) return null;
    return AuthValidators.validateEmail(value);
  }

  String? _validatePassword(String? value) {
    if (!_passwordTouched) return null;
    return AuthValidators.validatePassword(value);
  }

  Future<void> _handleSubmit() async {
    // Set both fields as touched when submitting
    setState(() {
      _emailTouched = true;
      _passwordTouched = true;
    });
    
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await ref.read(authServiceProvider.notifier).login(
        email: _emailController.text,
        password: _passwordController.text,
      );

      final authState = ref.read(authServiceProvider);
      authState.maybeMap(
        authenticated: (_) {
          dev.log('LoginForm: Login successful');
          ref.read(navigationProvider.notifier).startTransition('/dashboard');
        },
        error: (state) {
          dev.log('LoginForm: Login error state: ${state.message}');
          setState(() {
            if (state.message.contains('No internet connection') ||
                state.message.contains('SocketException')) {
              _error = 'No internet connection. Trying offline login...';
              // Attempt offline login after showing message
              Future.delayed(const Duration(milliseconds: 500), () async {
                try {
                  await ref.read(authServiceProvider.notifier).offlineLogin(
                    email: _emailController.text,
                    password: _passwordController.text,
                  );
                  // Check if offline login succeeded
                  final newState = ref.read(authServiceProvider);
                  newState.maybeMap(
                    authenticated: (_) {
                      dev.log('LoginForm: Offline login successful');
                      ref.read(navigationProvider.notifier).startTransition('/dashboard');
                    },
                    error: (state) => setState(() {
                      _error = 'Offline login failed: ${state.message}';
                    }),
                    orElse: () {},
                  );
                } catch (e) {
                  dev.log('LoginForm: Offline login error', error: e);
                  setState(() {
                    _error = 'Offline login failed. Please check your credentials.';
                  });
                }
              });
            } else if (state.message.toLowerCase().contains('invalid credentials') || 
                      state.message.toLowerCase().contains('api exception') ||
                      state.message.toLowerCase().contains('401')) {
              _error = 'Invalid email or password';
            } else if (state.message.contains('404')) {
              _error = 'Account not found. Please check your email.';
            } else if (state.message.contains('locked') || 
                      state.message.contains('429')) {
              _error = 'Too many attempts. Please try again later.';
            } else {
              _error = 'Login failed. Please try again.';
            }
          });
        },
        orElse: () => setState(() {
          _error = 'An unexpected error occurred';
        }),
      );
    } catch (e) {
      dev.log('LoginForm: Login error', error: e);
      setState(() {
        if (e.toString().toLowerCase().contains('no internet connection') ||
            e.toString().toLowerCase().contains('socketexception')) {
          _error = 'No internet connection. Please check your connection.';
        } else if (e.toString().toLowerCase().contains('invalid credentials') ||
                  e.toString().toLowerCase().contains('api exception')) {
          _error = 'Invalid email or password';
        } else {
          _error = 'Login failed. Please try again.';
        }
      });
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
    final authState = ref.watch(authServiceProvider);
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
            onChanged: (value) {
              setState(() {
                _emailTouched = true;
              });
              _validateForm();
            },
            validator: _validateEmail,
          ),
          const SizedBox(height: 16),
          CupertinoTextFormFieldRow(
            controller: _passwordController,
            placeholder: 'Password',
            obscureText: true,
            onChanged: (value) {
              setState(() {
                _passwordTouched = true;
              });
              _validateForm();
            },
            validator: _validatePassword,
          ),
          const SizedBox(height: 24),
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CupertinoColors.destructiveRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _error!,
                style: TextStyle(
                  color: CupertinoColors.destructiveRed,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
          ],
          CupertinoButton.filled(
            onPressed: (_isLoading || isLoading || !_isFormValid) ? null : _handleSubmit,
            child: _isLoading || isLoading
                ? const CupertinoActivityIndicator()
                : const Text('Login'),
          ),
        ],
      ),
    );
  }
}
