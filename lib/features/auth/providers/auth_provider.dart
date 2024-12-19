import 'package:bentobook/core/repositories/user_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:developer' as dev;
import 'package:bentobook/core/api/api_client.dart';
import 'package:bentobook/core/api/api_exception.dart';
import 'package:bentobook/core/api/models/user.dart' as api;
import 'package:bentobook/core/shared/providers.dart';
import 'package:bentobook/core/auth/auth_state.dart';

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient _apiClient;
  final UserRepository _userRepository;

  AuthNotifier({
    required ApiClient apiClient,
    required UserRepository userRepository,
  }) : _apiClient = apiClient,
       _userRepository = userRepository,
       super(const AuthState.initial());

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    dev.log('AuthNotifier: Starting login');
    dev.log('AuthNotifier: Attempting login for email: $email');
    
    state = const AuthState.loading();

    try {
      final response = await _apiClient.login(
        email: email,
        password: password,
      );
      
      dev.log('AuthNotifier: Login response received');
      dev.log('AuthNotifier: Response data: ${response.data?.toJson()}');
      
      if (!response.isSuccess || response.meta?.token == null || response.data == null) {
        dev.log('AuthNotifier: Login failed - response not successful or missing token/data');
        throw ApiException(
          message: response.errors.isNotEmpty 
            ? response.errors.first.detail 
            : 'Login failed',
        );
      }

      final userData = response.data!;
      final token = response.meta!.token!;

      dev.log('AuthNotifier: Login successful, saving user data');
      
      // Save user data first
      try {
        dev.log('AuthNotifier: Starting user data save');
        await _userRepository.saveUserFromApi(userData);
        dev.log('AuthNotifier: User data saved');
        
        // Then update state to indicate authentication
        state = AuthState.authenticated(
          user: userData,
          token: token,
        );
        
        return true;
      } catch (e) {
        dev.log('AuthNotifier: Error saving user data', error: e);
        state = AuthState.error('Failed to save user data: $e');
        return false;
      }
    } catch (e) {
      dev.log('AuthNotifier: Login error', error: e);
      state = AuthState.error(e.toString());
      return false;
    }
  }

  void logout() {
    state = const AuthState.unauthenticated();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final userRepository = ref.watch(userRepositoryProvider);
  return AuthNotifier(
    apiClient: apiClient,
    userRepository: userRepository,
  );
});
