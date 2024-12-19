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

  AuthService(this._apiClient, this._storage, this._userRepository) : super(const AuthState.initial()) {
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
        
        // Get user from local DB first
        final userEmail = await _storage.read(key: 'user_email');
        if (userEmail != null) {
          final userData = await _userRepository.getUserByEmail(userEmail);
          if (userData != null) {
            // Restore auth state from local data
            state = AuthState.authenticated(
              user: userData.toApiUser(), // Convert DB user to API user
              token: token,
            );
            
            // Try to refresh token only if online
            try {
              final refreshed = await _apiClient.refreshToken();
              if (!refreshed) {
                // Token invalid - clear auth
                await _storage.delete(key: _tokenKey);
                await _storage.delete(key: 'user_email');
                state = const AuthState.unauthenticated();
              }
            } catch (e) {
              // Offline or other error - keep existing auth state
              dev.log('Token refresh failed (possibly offline): $e');
            }
            return;
          }
        }
      }
      
      // No valid local data
      state = const AuthState.unauthenticated();
    } catch (e) {
      dev.log('Error restoring session: $e');
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
      
      if (!response.isSuccess || response.meta?.token == null || response.data == null) {
        throw ApiException(
          message: response.errors.isNotEmpty 
            ? response.errors.first.detail 
            : 'Login failed',
      );
    }

    // Save token and email
    await _storage.write(key: _tokenKey, value: response.meta!.token);
    await _storage.write(key: 'user_email', value: email);
    _apiClient.setToken(response.meta!.token!);

    // Save user data
    dev.log('AuthService: Saving user data');
    await _userRepository.saveUserFromApi(response.data!);
    dev.log('AuthService: User data saved');

    // Update state
    state = AuthState.authenticated(
      user: response.data!,
      token: response.meta!.token!,
    );
  } catch (e) {
    dev.log('Login error: $e');
    state = AuthState.error(e.toString());
    rethrow;
  }
}

  Future<void> logout() async {
    await _storage.delete(key: _tokenKey);
    _apiClient.setToken(null);
    state = const AuthState.unauthenticated();
  }
}

final authServiceProvider = StateNotifierProvider<AuthService, AuthState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final userRepository = ref.watch(userRepositoryProvider);
  const storage = FlutterSecureStorage();
  return AuthService(apiClient, storage, userRepository);
});