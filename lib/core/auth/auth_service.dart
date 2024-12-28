import 'package:bentobook/core/shared/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:developer' as dev;
import 'auth_state.dart';
import 'package:bentobook/core/api/api_client.dart';
import 'package:bentobook/core/api/api_exception.dart';

const _tokenKey = 'auth_token';

class AuthService extends StateNotifier<AuthState> {
  final ApiClient _apiClient;
  final FlutterSecureStorage _storage;

  AuthService(this._apiClient, this._storage) 
      : super(const AuthState.initial()) {
    _apiClient.onRefreshFailed = () {
      _storage.delete(key: _tokenKey);
      state = const AuthState.unauthenticated();
    };
  }

  // Public initialization method
  Future<void> initializeAuth() async {
    try {
      dev.log('AuthService: Starting initialization');
      final token = await _storage.read(key: _tokenKey);
      if (token == null) {
        dev.log('AuthService: No token found');
        state = const AuthState.unauthenticated();
        return;
      }

      _apiClient.setToken(token);
      final refreshSuccess = await _apiClient.refreshToken();
      dev.log('AuthService: Token refresh result: $refreshSuccess');

      if (!refreshSuccess) {
        dev.log('AuthService: Token refresh failed');
        await _storage.delete(key: _tokenKey);
        state = const AuthState.unauthenticated();
        return;
      }

      // Get user data from API
      final response = await _apiClient.getMe();
      final userId = response.data?.id;
      if (userId == null) {
        dev.log('AuthService: No user ID in response');
        await _storage.delete(key: _tokenKey);
        state = const AuthState.unauthenticated();
        return;
      }

      state = AuthState.authenticated(userId: userId, token: token);
      dev.log('AuthService: Successfully authenticated with user ID: $userId');
    } catch (e) {
      dev.log('AuthService: Error during initialization', error: e);
      await _storage.delete(key: _tokenKey);
      state = const AuthState.unauthenticated();
    }
  }

  Future<void> login(String email, String password) async {
    state = const AuthState.loading();
    
    try {
      final response = await _apiClient.login(email: email, password: password);
      
      final token = response.meta?.token;
      final userId = response.data?.id;
      
      if (token == null || userId == null) {
        throw ApiException(message: 'Invalid response from server');
      }

      await _storage.write(key: _tokenKey, value: token);
      state = AuthState.authenticated(userId: userId, token: token);
    } catch (e) {
      dev.log('AuthService: Login failed', error: e);
      state = AuthState.error(e.toString());
    }
  }

  Future<void> register(String email, String password) async {
    state = const AuthState.loading();
    
    try {
      final response = await _apiClient.register(email: email, password: password);
      
      final token = response.meta?.token;
      final userId = response.data?.id;
      
      if (token == null || userId == null) {
        throw ApiException(message: 'Invalid response from server');
      }

      await _storage.write(key: _tokenKey, value: token);
      state = AuthState.authenticated(userId: userId, token: token);
    } catch (e) {
      dev.log('AuthService: Registration failed', error: e);
      state = AuthState.error(e.toString());
    }
  }

  Future<void> logout() async {
    try {
      await _storage.delete(key: _tokenKey);
      _apiClient.setToken(null);
      state = const AuthState.unauthenticated();
      dev.log('AuthService: Logged out successfully');
    } catch (e) {
      dev.log('AuthService: Logout failed', error: e);
      state = AuthState.error(e.toString());
    }
  }
}

final authServiceProvider = StateNotifierProvider<AuthService, AuthState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  const storage = FlutterSecureStorage();
  return AuthService(apiClient, storage);
});