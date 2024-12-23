import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:bentobook/features/auth/models/auth_form_state.dart';
import 'package:bentobook/features/auth/validators.dart';
import 'package:bentobook/features/auth/widgets/shared/auth_text_field.dart';
import "dart:developer" as dev;

class SignupForm extends StatefulWidget {
  const SignupForm({super.key});

  @override
  State<SignupForm> createState() => _SignupFormState();
}

class _SignupFormState extends State<SignupForm> {
  var _formState = const SignupFormState();

  void _validateEmail(String value) {
    final error = AuthValidators.validateEmail(value);

    final newState = SignupFormState(
      email: value,
      password: _formState.password,
      passwordConfirm: _formState.passwordConfirm,
      emailError: error,
      passwordError: _formState.passwordError,
      passwordConfirmError: _formState.passwordConfirmError,
    );

    setState(() {
      _formState = newState;
    });
  }

  void _validatePassword(String value) {
    final error = AuthValidators.validatePassword(value);

    // When password changes, we need to revalidate the confirmation
    final confirmError = value.isEmpty
        ? null
        : AuthValidators.validatePasswordConfirmation(
            _formState.passwordConfirm, value);

    final newState = SignupFormState(
      email: _formState.email,
      password: value,
      passwordConfirm: _formState.passwordConfirm,
      emailError: _formState.emailError,
      passwordError: error,
      passwordConfirmError: confirmError,
    );

    setState(() {
      _formState = newState;
    });
  }

  void _validatePasswordConfirm(String value) {
    final error =
        AuthValidators.validatePasswordConfirmation(value, _formState.password);

    final newState = SignupFormState(
      email: _formState.email,
      password: _formState.password,
      passwordConfirm: value,
      emailError: _formState.emailError,
      passwordError: _formState.passwordError,
      passwordConfirmError: error,
    );

    setState(() {
      _formState = newState;
    });
  }

  void _handleSubmit() {
    if (_formState.isValid) {
      dev.log('Signing up with:');
      dev.log('  email: ${_formState.email}');
      dev.log('  password length: ${_formState.password.length}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
        const SizedBox(height: 12),
        AuthTextField(
          placeholder: 'Confirm Password',
          obscureText: true,
          errorText: _formState.passwordConfirmError,
          onChanged: _validatePasswordConfirm,
        ),
        const SizedBox(height: 24),
        CupertinoButton.filled(
          onPressed: _formState.isValid ? _handleSubmit : null,
          disabledColor: theme.colorScheme.primary.withAlpha(128),
          child: Text(
            'Sign Up',
            style: TextStyle(
              color: _formState.isValid
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onPrimary.withAlpha(179),
            ),
          ),
        ),
      ],
    );
  }
}
