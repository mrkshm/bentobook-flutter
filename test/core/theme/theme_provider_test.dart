import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:bentobook/core/theme/theme_provider.dart';
import 'package:bentobook/core/auth/auth_service.dart';
import 'package:bentobook/core/auth/auth_state.dart';

class MockAuthService extends StateNotifier<AuthState> implements AuthService {
  MockAuthService() : super(const AuthState.unauthenticated());

  @override
  Future<void> initializeAuth() async {}

  @override
  Future<void> login(String email, String password) async {}

  @override
  Future<void> logout() async {}

  @override
  Future<void> register(String email, String password) async {}
}

ProviderContainer createContainer({
  AuthService? authService,
}) {
  final container = ProviderContainer(
    overrides: [
      authServiceProvider.overrideWith((ref) => authService ?? MockAuthService()),
    ],
  );

  addTearDown(container.dispose);
  return container;
}

void main() {
  group('ThemeProvider', () {
    test('initial theme is system', () {
      final container = createContainer();
      final theme = container.read(themeProvider);
      expect(theme, equals(ThemeMode.system));
    });

    test('setTheme updates theme state', () {
      final container = createContainer();
      final notifier = container.read(themeProvider.notifier);
      notifier.setTheme(ThemeMode.dark);
      expect(container.read(themeProvider), equals(ThemeMode.dark));
    });

    test('cycles through theme modes', () {
      final container = createContainer();
      final notifier = container.read(themeProvider.notifier);
      
      notifier.setTheme(ThemeMode.light);
      expect(container.read(themeProvider), equals(ThemeMode.light));
      
      notifier.setTheme(ThemeMode.dark);
      expect(container.read(themeProvider), equals(ThemeMode.dark));
      
      notifier.setTheme(ThemeMode.system);
      expect(container.read(themeProvider), equals(ThemeMode.system));
    });
  });
}
