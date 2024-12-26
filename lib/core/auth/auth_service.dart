import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:developer' as dev;
import 'auth_state.dart';
import 'package:bentobook/core/api/api_client.dart';
import 'package:bentobook/core/api/api_exception.dart';
import 'package:bentobook/core/repositories/user_repository.dart';
import 'package:bentobook/core/shared/providers.dart';
import 'package:bentobook/core/api/models/user.dart' as user_models;

const _tokenKey = 'auth_token';

class AuthService extends StateNotifier<AuthState> {
  final ApiClient _apiClient;
  final FlutterSecureStorage _storage;
  final UserRepository _userRepository;

  AuthService(this._apiClient, this._storage, this._userRepository) 
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

      final userResponse = await _apiClient.getMe();
      dev.log('AuthService: User response: ${userResponse.toString()}');
      
      if (userResponse.isSuccess && userResponse.data != null) {
        state = AuthState.authenticated(user: userResponse.data!, token: token);
      } else {
        state = const AuthState.unauthenticated();
      }
    } catch (e, stack) {
      dev.log('AuthService: Error during initialization', error: e, stackTrace: stack);
      state = AuthState.error(e.toString());
    }
  }

  Future<void> login(String email, String password) async {
    state = const AuthState.loading();
    
    try {
      final response = await _apiClient.login(email: email, password: password);
      if (!response.isSuccess || response.data == null || response.meta?.token == null) {
        dev.log('AuthService: Login failed - no data or token');
        state = const AuthState.error('Login failed');
        return;
      }

      final token = response.meta!.token!;
      final user = response.data!;
      
      // Store credentials
      await _storage.write(key: _tokenKey, value: token);
      await _storage.write(key: 'user_email', value: email);
      
      // Update state with user data
      state = AuthState.authenticated(
        user: user,
        token: token,
      );
      
      // Save user to local database
      await _userRepository.saveUserFromApi(user);
      
      dev.log('AuthService: Login successful');
    } catch (e) {
      dev.log('AuthService: Login error', error: e);
      state = AuthState.error(e is ApiException ? e.message : 'Login failed');
    }
  }

  Future<void> register(String email, String password) async {
    state = const AuthState.loading();
    
    try {
      final response = await _apiClient.register(email: email, password: password);
      if (!response.isSuccess || response.data == null || response.meta?.token == null) {
        dev.log('AuthService: Registration failed - no data or token');
        state = const AuthState.error('Registration failed');
        return;
      }

      final token = response.meta!.token!;
      final user = response.data!;
      
      // Store credentials
      await _storage.write(key: _tokenKey, value: token);
      await _storage.write(key: 'user_email', value: email);
      
      // Update state with user data
      state = AuthState.authenticated(
        user: user,
        token: token,
      );
      
      // Save user to local database
      await _userRepository.saveUserFromApi(user);
      
      dev.log('AuthService: Registration successful');
    } catch (e) {
      dev.log('AuthService: Registration error', error: e);
      state = AuthState.error(e is ApiException ? e.message : 'Registration failed');
    }
  }

  Future<void> updateUserProfile(user_models.User updatedUser) async {
    state.maybeMap(
      authenticated: (authState) {
        state = AuthState.authenticated(
          user: updatedUser,
          token: authState.token,
        );
      },
      orElse: () {},
    );
  }

  Future<void> logout() async {
    dev.log('AuthService: Logging out');
    state = const AuthState.loading();
    
    try {
      await _storage.delete(key: _tokenKey);
      await _storage.delete(key: 'user_email');
      state = const AuthState.unauthenticated();
      dev.log('AuthService: Logged out successfully');
    } catch (e) {
      dev.log('AuthService: Error during logout', error: e);
      state = AuthState.error('Failed to logout: $e');
    }
  }
}

final authServiceProvider = StateNotifierProvider<AuthService, AuthState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final userRepository = ref.watch(userRepositoryProvider);
  const storage = FlutterSecureStorage();
  return AuthService(apiClient, storage, userRepository);
});