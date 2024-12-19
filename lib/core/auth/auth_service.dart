import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'auth_state.dart';
import '../api/api_client.dart';

const _tokenKey = 'auth_token';

class AuthService extends StateNotifier<AuthState> {
  final ApiClient _apiClient;
  final FlutterSecureStorage _storage;

  AuthService(this._apiClient, this._storage) : super(const AuthState.initial()) {
    _apiClient.onRefreshFailed = () {
      // When refresh fails, clear storage and set state to unauthenticated
      _storage.delete(key: _tokenKey);
      state = const AuthState.unauthenticated();
    };
    // Try to restore session on creation
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    state = const AuthState.loading();
    try {
      final token = await _storage.read(key: _tokenKey);
      if (token != null) {
        _apiClient.setToken(token);
        // Try to refresh the token to verify it's still valid
        final refreshed = await _apiClient.refreshToken();
        if (!refreshed) {
          // If refresh fails, clear token and stay logged out
          await _storage.delete(key: _tokenKey);
          state = const AuthState.unauthenticated();
        } else {
          state = AuthState.authenticated(
            user: await _apiClient.getMe(),
            token: token,
          );
        }
      } else {
        state = const AuthState.unauthenticated();
      }
    } catch (e) {
      state = const AuthState.unauthenticated();
    }
  }

  Future<void> login(String email, String password) async {
    try {
      final response = await _apiClient.login(email, password);
      
      if (response.isSuccess && response.data != null && response.meta?.token != null) {
        await _storage.write(key: _tokenKey, value: response.meta!.token);
        state = AuthState.authenticated(
          user: response.data!,
          token: response.meta!.token!,
        );
      } else {
        state = const AuthState.error('Login failed');
      }
    } catch (e) {
      state = AuthState.error(e.toString());
    }
  }

  Future<void> logout() async {
    state.when(
      initial: () async {
        await _storage.delete(key: _tokenKey);
        state = const AuthState.unauthenticated();
      },
      authenticated: (user, token) async {
        try {
          await _apiClient.logout(token);
          await _storage.delete(key: _tokenKey);
          state = const AuthState.unauthenticated();
        } catch (e) {
          state = AuthState.error(e.toString());
        }
      },
      unauthenticated: () async {
        await _storage.delete(key: _tokenKey);
        state = const AuthState.unauthenticated();
      },
      error: (_) async {
        await _storage.delete(key: _tokenKey);
        state = const AuthState.unauthenticated();
      },
      loading: () async {
        await _storage.delete(key: _tokenKey);
        state = const AuthState.unauthenticated();
      },
    );
  }
}

final authServiceProvider = StateNotifierProvider<AuthService, AuthState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  const storage = FlutterSecureStorage();
  return AuthService(apiClient, storage);
});