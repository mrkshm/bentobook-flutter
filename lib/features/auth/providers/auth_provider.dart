import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'dart:developer' as dev;
import 'package:bentobook/core/api/api_client.dart';
import 'package:bentobook/core/api/api_exception.dart';
import 'package:bentobook/core/api/models/user.dart';

part 'auth_provider.freezed.dart';

@freezed
class AuthState with _$AuthState {
  const factory AuthState({
    @Default(false) bool isLoading,
    @Default(false) bool isAuthenticated,
    User? user,
    String? error,
    String? token,
  }) = _AuthState;
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient _apiClient;

  AuthNotifier({
    required ApiClient apiClient,
  }) : _apiClient = apiClient,
       super(const AuthState());

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    dev.log('AuthNotifier: Starting login');
    state = state.copyWith(
      isLoading: true,
      error: null,
    );

    try {
      final response = await _apiClient.login(
        email: email,
        password: password,
      );
      
      dev.log('AuthNotifier: Login response received');
      
      if (!response.isSuccess || response.meta?.token == null || response.data == null) {
        dev.log('AuthNotifier: Login failed - response not successful or missing token/data');
        throw ApiException(
          message: response.errors.isNotEmpty 
            ? response.errors.first.detail 
            : 'Login failed',
        );
      }

      dev.log('AuthNotifier: Login successful, updating state');
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        user: response.data,
        token: response.meta!.token,
        error: null,
      );
      dev.log('AuthNotifier: State updated - isAuthenticated: ${state.isAuthenticated}, hasUser: ${state.user != null}, hasToken: ${state.token != null}');
      return true;
    } on ApiException catch (e) {
      dev.log('AuthNotifier: Login error - ${e.message}');
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: false,
        user: null,
        token: null,
        error: e.message,
      );
      return false;
    }
  }

  Future<bool> signup({
    required String email,
    required String password,
    String? passwordConfirmation,
  }) async {
    dev.log('AuthNotifier: Starting signup');
    state = state.copyWith(
      isLoading: true,
      error: null,
    );

    try {
      final response = await _apiClient.register(
        email: email,
        password: password,
        passwordConfirmation: passwordConfirmation,
      );
      
      dev.log('AuthNotifier: Signup response received');
      
      if (!response.isSuccess || response.meta?.token == null || response.data == null) {
        dev.log('AuthNotifier: Signup failed - response not successful or missing token/data');
        throw ApiException(
          message: response.errors.isNotEmpty 
            ? response.errors.first.detail 
            : 'Signup failed',
        );
      }

      dev.log('AuthNotifier: Signup successful, updating state');
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        user: response.data,
        token: response.meta!.token,
        error: null,
      );
      dev.log('AuthNotifier: State updated - isAuthenticated: ${state.isAuthenticated}, hasUser: ${state.user != null}, hasToken: ${state.token != null}');
      return true;
    } on ApiException catch (e) {
      dev.log('AuthNotifier: Signup error - ${e.message}');
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: false,
        user: null,
        token: null,
        error: e.message,
      );
      return false;
    }
  }

  Future<void> logout() async {
    dev.log('AuthNotifier: Starting logout');
    try {
      await _apiClient.logout();
    } finally {
      dev.log('AuthNotifier: Resetting state');
      state = const AuthState();
      dev.log('AuthNotifier: State reset - isAuthenticated: ${state.isAuthenticated}');
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AuthNotifier(apiClient: apiClient);
});
