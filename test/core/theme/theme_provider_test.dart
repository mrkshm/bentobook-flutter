import 'package:bentobook/core/api/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:bentobook/core/theme/theme_provider.dart';
import 'package:bentobook/core/shared/providers.dart';
import 'package:bentobook/core/database/database.dart';
import 'package:bentobook/core/database/tables/sync_status.dart';
import 'package:bentobook/core/auth/auth_service.dart';
import 'package:bentobook/core/auth/auth_state.dart';
import 'package:bentobook/core/api/models/api_response.dart';
import 'package:bentobook/core/api/models/user.dart' as api;
import 'package:bentobook/core/api/api_exception.dart';
import 'package:mocktail/mocktail.dart';

// Mock classes
class MockDatabase extends Mock implements AppDatabase {}
class MockApiClient extends Mock implements ApiClient {}
class MockAuthService extends Mock implements AuthService {}
class MockAuthState extends Mock implements AuthState {}

ProviderContainer createContainer({
  AppDatabase? database,
  ApiClient? apiClient,
  AuthService? authService,
}) {
  final container = ProviderContainer(
    overrides: [
      databaseProvider.overrideWithValue(database ?? MockDatabase()),
      apiClientProvider.overrideWithValue(apiClient ?? MockApiClient()),
      authServiceProvider.overrideWith((ref) => authService ?? MockAuthService()),
    ],
  );

  addTearDown(container.dispose);
  return container;
}

void main() {
  setUpAll(() {
    registerFallbackValue(ThemeMode.system);
    registerFallbackValue(MockAuthState());
    registerFallbackValue(User(
      id: 1,
      email: 'test@example.com',
      username: 'test',
      preferredTheme: ThemeMode.system,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      preferredLanguage: '',
      syncStatus: SyncStatus.synced,
    ));
  });

  group('ThemeNotifier', () {
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

    test('toggleTheme switches between light and dark', () {
      final container = createContainer();
      final notifier = container.read(themeProvider.notifier);
      
      // Start with light theme
      notifier.setTheme(ThemeMode.light);
      expect(container.read(themeProvider), equals(ThemeMode.light));
      
      // Toggle to dark
      notifier.toggleTheme();
      expect(container.read(themeProvider), equals(ThemeMode.dark));
      
      // Toggle back to light
      notifier.toggleTheme();
      expect(container.read(themeProvider), equals(ThemeMode.light));
    });

    test('themeName returns correct string representation', () {
      final container = createContainer();
      final notifier = container.read(themeProvider.notifier);
      
      notifier.setTheme(ThemeMode.system);
      expect(notifier.themeName, equals('System'));
      
      notifier.setTheme(ThemeMode.light);
      expect(notifier.themeName, equals('Light'));
      
      notifier.setTheme(ThemeMode.dark);
      expect(notifier.themeName, equals('Dark'));
    });

    test('syncs theme changes with API', () async {
      // Arrange
      final mockDb = MockDatabase();
      final mockApiClient = MockApiClient();
      final mockAuthService = MockAuthService();
      final container = createContainer(
        database: mockDb,
        apiClient: mockApiClient,
        authService: mockAuthService,
      );

      // Mock authenticated user
      final authState = AuthState.authenticated(
        user: api.User(
          id: '1',
          type: 'user',
          attributes: api.UserAttributes(
            email: 'test@example.com',
            profile: api.UserProfile(
              username: 'test',
              preferredTheme: 'system',
            ),
          ),
        ),
        token: 'test-token',
      );
      when(() => mockAuthService.state).thenReturn(authState);

      when(() => mockDb.getUserByEmail('test@example.com')).thenAnswer((_) async => User(
        id: 1,
        email: 'test@example.com',
        username: 'test',
        preferredTheme: ThemeMode.system,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        preferredLanguage: '',
        syncStatus: SyncStatus.synced,
      ));

      when(() => mockDb.updateUser(any())).thenAnswer((_) async => User(
        id: 1,
        email: 'test@example.com',
        username: 'test',
        preferredTheme: ThemeMode.dark,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        preferredLanguage: '',
        syncStatus: SyncStatus.synced,
      ));

      when(() => mockApiClient.updateProfile(preferredTheme: 'dark'))
          .thenAnswer((_) async => ApiResponse(status: 'success', data: null));

      // Act
      final notifier = container.read(themeProvider.notifier);
      notifier.setTheme(ThemeMode.dark);
      await Future.delayed(const Duration(milliseconds: 100)); // Wait for async operations

      // Assert
      verify(() => mockApiClient.updateProfile(preferredTheme: 'dark')).called(1);
      verify(() => mockDb.updateUser(any())).called(1);
    });

    test('keeps local changes when API sync fails', () async {
      // Arrange
      final mockDb = MockDatabase();
      final mockApiClient = MockApiClient();
      final mockAuthService = MockAuthService();
      final container = createContainer(
        database: mockDb,
        apiClient: mockApiClient,
        authService: mockAuthService,
      );

      // Mock authenticated user
      final authState = AuthState.authenticated(
        user: api.User(
          id: '1',
          type: 'user',
          attributes: api.UserAttributes(
            email: 'test@example.com',
            profile: api.UserProfile(
              username: 'test',
              preferredTheme: 'system',
            ),
          ),
        ),
        token: 'test-token',
      );
      when(() => mockAuthService.state).thenReturn(authState);

      when(() => mockDb.getUserByEmail('test@example.com')).thenAnswer((_) async => User(
        id: 1,
        email: 'test@example.com',
        username: 'test',
        preferredTheme: ThemeMode.system,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        preferredLanguage: '',
        syncStatus: SyncStatus.synced,
      ));

      when(() => mockDb.updateUser(any())).thenAnswer((_) async => User(
        id: 1,
        email: 'test@example.com',
        username: 'test',
        preferredTheme: ThemeMode.dark,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        preferredLanguage: '',
        syncStatus: SyncStatus.synced,
      ));

      when(() => mockApiClient.updateProfile(preferredTheme: 'dark'))
          .thenThrow(ApiException(message: 'Failed to update profile'));

      // Act
      final notifier = container.read(themeProvider.notifier);
      notifier.setTheme(ThemeMode.dark);
      await Future.delayed(const Duration(milliseconds: 100)); // Wait for async operations

      // Assert
      verify(() => mockApiClient.updateProfile(preferredTheme: 'dark')).called(1);
      verify(() => mockDb.updateUser(any())).called(1); // Local update should still happen
    });
  });
}
