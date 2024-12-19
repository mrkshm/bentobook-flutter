import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:bentobook/features/auth/widgets/login_form.dart';
import 'package:bentobook/features/auth/widgets/signup_form.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  int _selectedSegment = 0;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Login / Sign Up'),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              const SizedBox(height: 16),
              CupertinoSlidingSegmentedControl<int>(
                groupValue: _selectedSegment,
                onValueChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedSegment = value;
                    });
                  }
                },
                children: const {
                  0: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text('Login'),
                  ),
                  1: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text('Sign Up'),
                  ),
                },
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