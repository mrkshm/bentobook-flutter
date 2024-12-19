import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:developer' as dev;
import 'auth_state.dart';
import '../api/api_client.dart';
import '../api/api_exception.dart';

const _tokenKey = 'auth_token';

class AuthService extends StateNotifier<AuthState> {
  final ApiClient _apiClient;
  final FlutterSecureStorage _storage;

  AuthService(this._apiClient, this._storage) : super(const AuthState.initial()) {
    _apiClient.onRefreshFailed = () {
      _storage.delete(key: _tokenKey);
      state = const AuthState.unauthenticated();
    };
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    state = const AuthState.loading();
    try {
      final token = await _storage.read(key: _tokenKey);
      if (token != null) {
        _apiClient.setToken(token);
        final refreshed = await _apiClient.refreshToken();
        if (!refreshed) {
          await _storage.delete(key: _tokenKey);
          state = const AuthState.unauthenticated();
        } else {
          state = const AuthState.unauthenticated();
        }
      } else {
        state = const AuthState.unauthenticated();
      }
    } catch (e) {
      state = const AuthState.unauthenticated();
    }
  }

  Future<void> login({required String email, required String password}) async {
    dev.log('Starting login for email: $email');
    state = const AuthState.loading();
    try {
      final response = await _apiClient.login(
        email: email,
        password: password,
      );
      
      if (response.isSuccess && 
          response.meta?.token != null && 
          response.data != null) {
        await _storage.write(key: _tokenKey, value: response.meta!.token);
        state = AuthState.authenticated(
          user: response.data!,
          token: response.meta!.token!,
        );
      } else {
        state = const AuthState.error('Login failed');
      }
    } on ApiException catch (e) {
      state = AuthState.error(e.message);
    }
  }

  Future<void> signup({
    required String email,
    required String password,
    String? passwordConfirmation,
  }) async {
    state = const AuthState.loading();
    try {
      final response = await _apiClient.register(
        email: email,
        password: password,
        passwordConfirmation: passwordConfirmation,
      );
      
      if (response.isSuccess && 
          response.meta?.token != null && 
          response.data != null) {
        await _storage.write(key: _tokenKey, value: response.meta!.token);
        state = AuthState.authenticated(
          user: response.data!,
          token: response.meta!.token!,
        );
      } else {
        state = const AuthState.error('Signup failed');
      }
    } on ApiException catch (e) {
      state = AuthState.error(e.message);
    }
  }

  Future<void> logout() async {
    try {
      await _apiClient.logout();
    } finally {
      await _storage.delete(key: _tokenKey);
      state = const AuthState.unauthenticated();
    }
  }
}

final authServiceProvider = StateNotifierProvider<AuthService, AuthState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  const storage = FlutterSecureStorage();
  return AuthService(apiClient, storage);
});