import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:developer' as dev;
import 'auth_state.dart';
import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../repositories/user_repository.dart';
import '../shared/providers.dart';
import '../database/extensions.dart';

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
    if (state.maybeMap(
      initial: (_) => false,
      orElse: () => true,
    )) {
      dev.log('AuthService: Already initialized');
      return; // Already initialized
    }

    state = const AuthState.loading();
    dev.log('AuthService: Starting initialization');
    
    try {
      final token = await _storage.read(key: _tokenKey);
      final userEmail = await _storage.read(key: 'user_email');
      
      dev.log('AuthService: Token: ${token != null}, Email: ${userEmail != null}');
      
      if (token == null || userEmail == null) {
        dev.log('AuthService: No stored credentials');
        // Clean up any partial credentials
        await _storage.delete(key: _tokenKey);
        await _storage.delete(key: 'user_email');
        state = const AuthState.unauthenticated();
        return;
      }

      // Set token for API client
      _apiClient.setToken(token);
      
      // Try to get user from local DB
      final userData = await _userRepository.getUserByEmail(userEmail);
      dev.log('AuthService: Local user data found: ${userData != null}');
      
      if (userData == null) {
        dev.log('AuthService: No local user data found');
        await _clearCredentials();
        state = const AuthState.unauthenticated();
        return;
      }

      // Restore auth state from local data
      dev.log('AuthService: Restoring auth state from local data');
      state = AuthState.authenticated(
        user: userData.toApiUser(),
        token: token,
      );
      
      // Try to refresh token if online
      try {
        final refreshed = await _apiClient.refreshToken();
        dev.log('AuthService: Token refresh result: $refreshed');
        if (!refreshed) {
          dev.log('AuthService: Token refresh failed');
          await _clearCredentials();
          state = const AuthState.unauthenticated();
        }
      } catch (e) {
        // Offline or other error - keep existing auth state
        dev.log('AuthService: Token refresh failed (possibly offline): $e');
      }
    } catch (e) {
      dev.log('AuthService: Error during initialization: $e');
      state = AuthState.error(e.toString());
    }
  }

  // Helper to clear credentials consistently
  Future<void> _clearCredentials() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: 'user_email');
    _apiClient.setToken(null);
  }

  Future<void> login({required String email, required String password}) async {
    state = const AuthState.loading();
    dev.log('AuthService: Starting login');

    try {
      final response = await _apiClient.login(
        email: email,
        password: password,
      );

      if (!response.isSuccess || response.meta?.token == null || response.data == null) {
        throw ApiException(
          message: response.errors.isNotEmpty 
            ? response.errors.first.detail 
            : 'Login failed',
        );
      }

      final userData = response.data!;
      final token = response.meta!.token!;

      // Save credentials
      await _storage.write(key: _tokenKey, value: token);
      await _storage.write(key: 'user_email', value: email);
      _apiClient.setToken(token);

      // Save user data to local DB
      await _userRepository.saveUserFromApi(userData);

      state = AuthState.authenticated(
        user: userData,
        token: token,
      );
    } catch (e) {
      dev.log('AuthService: Login error', error: e);
      state = AuthState.error(e.toString());
      rethrow;
    }
  }

  Future<void> offlineLogin({required String email, required String password}) async {
    state = const AuthState.loading();
    dev.log('AuthService: Starting offline login');

    try {
      // Check if we have stored credentials for this email
      final storedEmail = await _storage.read(key: 'user_email');
      final storedToken = await _storage.read(key: _tokenKey);
      
      if (storedEmail != email) {
        throw ApiException(message: 'Email not found in offline storage');
      }

      if (storedToken == null) {
        throw ApiException(message: 'No stored credentials found');
      }

      // Get user from local DB
      final userData = await _userRepository.getUserByEmail(email);
      if (userData == null) {
        throw ApiException(message: 'User data not found in local database');
      }

      // Set token for future API calls
      _apiClient.setToken(storedToken);

      state = AuthState.authenticated(
        user: userData.toApiUser(),
        token: storedToken,
      );

      dev.log('AuthService: Offline login successful');
    } catch (e) {
      dev.log('AuthService: Offline login error', error: e);
      state = AuthState.error(e.toString());
      rethrow;
    }
  }

  Future<void> logout() async {
    await _clearCredentials();
    state = const AuthState.unauthenticated();
  }
}

final authServiceProvider = StateNotifierProvider<AuthService, AuthState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final userRepository = ref.watch(userRepositoryProvider);
  const storage = FlutterSecureStorage();
  return AuthService(apiClient, storage, userRepository);
});