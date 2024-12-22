import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:developer' as dev;
import 'auth_state.dart';
import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../repositories/user_repository.dart';
import '../shared/providers.dart';

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

      // We have a token, try to get the user
      try {
        final response = await _apiClient.getMe();
        if (response.isSuccess && response.data != null) {
          dev.log('AuthService: Successfully got user data');
          state = AuthState.authenticated(
            user: response.data!,
            token: token,
          );
          
          // Save user to local database
          await _userRepository.saveUserFromApi(response.data!);
        } else {
          dev.log('AuthService: Failed to get user data');
          await _storage.delete(key: _tokenKey);
          await _storage.delete(key: 'user_email');
          state = const AuthState.unauthenticated();
        }
      } catch (e) {
        dev.log('AuthService: Error getting user data', error: e);
        await _storage.delete(key: _tokenKey);
        await _storage.delete(key: 'user_email');
        state = AuthState.error('Failed to get user data: $e');
      }
    } catch (e) {
      dev.log('AuthService: Error during initialization', error: e);
      state = AuthState.error('Failed to initialize: $e');
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