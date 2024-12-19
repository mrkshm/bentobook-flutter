import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';

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
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                // Title section - fixed position
                Column(
                  children: const [
                    Text(
                      'Welcome to BentoBook',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Login or create an account to continue',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        color: CupertinoColors.systemGrey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                // Form section - fixed height container
                SizedBox(
                  height: 280, // Fixed height for form container
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: Column(
                      children: [
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
                        const SizedBox(height: 24),
                        const CupertinoTextField(
                          placeholder: 'Email',
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                        ),
                        const SizedBox(height: 12),
                        const CupertinoTextField(
                          placeholder: 'Password',
                          obscureText: true,
                          autocorrect: false,
                        ),
                        if (_selectedSegment == 1) ...[
                          const SizedBox(height: 12),
                          const CupertinoTextField(
                            placeholder: 'Confirm Password',
                            obscureText: true,
                            autocorrect: false,
                          ),
                        ],
                        const SizedBox(height: 24),
                        CupertinoButton.filled(
                          onPressed: () {
                            // TODO: Implement login/signup
                          },
                          child: Text(_selectedSegment == 0 ? 'Login' : 'Sign Up'),
                        ),
                      ],
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