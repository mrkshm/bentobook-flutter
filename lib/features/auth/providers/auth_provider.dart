import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_provider.freezed.dart';

@freezed
class AuthState with _$AuthState {
  const factory AuthState({
    @Default(false) bool isLoading,
    @Default(false) bool isAuthenticated,
    String? error,
    String? token,
  }) = _AuthState;
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState());

  final _controller = StreamController<AuthState>.broadcast();
  Stream<AuthState> get stream => _controller.stream;

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(
      isLoading: true,
      error: null,
    );

    try {
      // TODO: Implement actual API call
      await Future.delayed(const Duration(seconds: 1)); // Simulate API call
      
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        token: 'dummy_token',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  Future<void> signup({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(
      isLoading: true,
      error: null,
    );
    _controller.add(state);

    try {
      // TODO: Implement actual API call
      await Future.delayed(const Duration(seconds: 1)); // Simulate API call
      
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        token: 'dummy_token',
      );
      _controller.add(state);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      _controller.add(state);
    }
  }

  void logout() {
    state = const AuthState();
    _controller.add(state);
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
