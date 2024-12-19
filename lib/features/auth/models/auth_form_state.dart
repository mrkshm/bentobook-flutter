// Base class for shared properties
abstract class BaseAuthFormState {
  final String email;
  final String password;
  final String? emailError;
  final String? passwordError;

  const BaseAuthFormState({
    this.email = '',
    this.password = '',
    this.emailError,
    this.passwordError,
  });

  bool get isValid;
}

class LoginFormState extends BaseAuthFormState {
  const LoginFormState({
    super.email = '',
    super.password = '',
    super.emailError,
    super.passwordError,
  });

  @override
  bool get isValid => 
    email.isNotEmpty && 
    password.isNotEmpty && 
    emailError == null && 
    passwordError == null;

  LoginFormState copyWith({
    String? email,
    String? password,
    String? emailError,
    String? passwordError,
  }) {
    return LoginFormState(
      email: email ?? this.email,
      password: password ?? this.password,
      emailError: emailError ?? this.emailError,
      passwordError: passwordError ?? this.passwordError,
    );
  }
}

class SignupFormState extends BaseAuthFormState {
  final String passwordConfirm;
  final String? passwordConfirmError;

  const SignupFormState({
    super.email = '',
    super.password = '',
    super.emailError,
    super.passwordError,
    this.passwordConfirm = '',
    this.passwordConfirmError,
  });

  @override
  bool get isValid =>
    email.isNotEmpty &&
    password.isNotEmpty &&
    passwordConfirm.isNotEmpty &&
    emailError == null &&
    passwordError == null &&
    passwordConfirmError == null;

  SignupFormState copyWith({
    String? email,
    String? password,
    String? passwordConfirm,
    String? emailError,
    String? passwordError,
    String? passwordConfirmError,
  }) {
    return SignupFormState(
      email: email ?? this.email,
      password: password ?? this.password,
      passwordConfirm: passwordConfirm ?? this.passwordConfirm,
      emailError: emailError ?? this.emailError,
      passwordError: passwordError ?? this.passwordError,
      passwordConfirmError: passwordConfirmError ?? this.passwordConfirmError,
    );
  }
}
