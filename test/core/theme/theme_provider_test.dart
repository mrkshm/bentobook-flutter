import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:bentobook/core/theme/theme_provider.dart';
import 'package:bentobook/core/auth/auth_service.dart';
import 'package:bentobook/core/shared/providers.dart';
import 'package:bentobook/core/database/database.dart';
import 'package:bentobook/core/api/models/user.dart' as api;
import 'package:bentobook/core/auth/auth_state.dart';
import 'package:bentobook/core/database/tables/sync_status.dart';

// Simple test database that tracks theme changes
class TestDatabase implements AppDatabase {
  User? lastUpdatedUser;
  
  @override
  Future<User> updateUser(User user) async {
    lastUpdatedUser = user;
    return user;
  }
  
  @override
  Future<User?> getUserByEmail(String email) async {
    return User(
      id: 1,
      email: email,
      username: 'testuser',
      displayName: 'Test User',
      firstName: 'Test',
      lastName: 'User',
      about: 'Test user for unit tests',
      preferredTheme: ThemeMode.light,
      preferredLanguage: 'en',
      avatarUrls: const {},
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      syncStatus: SyncStatus.synced,
    );
  }

  @override
  Future<User> createUser({
    required String email,
    String? username,
    String? displayName,
    String? firstName,
    String? lastName,
    String? about,
    ThemeMode? preferredTheme,
    String? preferredLanguage,
    Map<String, String>? avatarUrls,
  }) async {
    return User(
      id: 1,
      email: email,
      username: username ?? 'testuser',
      displayName: displayName ?? 'Test User',
      firstName: firstName ?? 'Test',
      lastName: lastName ?? 'User',
      about: about ?? 'Test user for unit tests',
      preferredTheme: preferredTheme ?? ThemeMode.light,
      preferredLanguage: preferredLanguage ?? 'en',
      avatarUrls: avatarUrls ?? const {},
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      syncStatus: SyncStatus.synced,
    );
  }

  @override
  Future<List<User>> getAllUsers() async => [];

  @override
  Stream<User?> watchUserByEmail(String email) {
    return Stream.value(null);
  }

  @override
  Future<void> close() async {}
  Future<void> initialize() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Simple test auth service that returns a fixed user
class TestAuthService extends StateNotifier<AuthState> implements AuthService {
  TestAuthService() : super(AuthState.authenticated(
    user: api.User(
      id: '1',
      type: 'users',
      attributes: api.UserAttributes(
        email: 'test@example.com',
        profile: api.UserProfile(
          username: 'testuser',
          preferredTheme: 'light',
          preferredLanguage: 'en',
        ),
      ),
    ),
    token: 'test-token',
  ));

  @override
  Future<void> login({required String email, required String password}) async {}

  Future<void> register({required String email, required String password, String? passwordConfirmation}) async {}

  @override
  Future<void> logout() async {}

  @override
  Future<void> offlineLogin({required String email, required String password}) async {}

  @override
  Future<void> initializeAuth() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  late ProviderContainer container;
  late TestDatabase testDatabase;

  setUp(() {
    testDatabase = TestDatabase();

    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(testDatabase),
        authServiceProvider.overrideWith((ref) => TestAuthService()),
      ],
    );

    addTearDown(container.dispose);
  });

  group('ThemeNotifier', () {
    test('initial state is system theme', () {
      final theme = container.read(themeProvider);
      expect(theme, equals(ThemeMode.system));
    });

    test('setTheme updates theme state', () {
      final notifier = container.read(themeProvider.notifier);
      notifier.setTheme(ThemeMode.dark);
      expect(container.read(themeProvider), equals(ThemeMode.dark));
    });

    test('toggleTheme switches between light and dark', () {
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

    test('setTheme persists theme to database for authenticated user', () async {
      final notifier = container.read(themeProvider.notifier);
      notifier.setTheme(ThemeMode.dark);

      // Give time for the async database update to complete
      await Future.delayed(const Duration(milliseconds: 100));

      // Verify database was updated with dark theme
      expect(testDatabase.lastUpdatedUser?.preferredTheme, equals(ThemeMode.dark));
    });

    test('themeName returns correct string representation', () {
      final notifier = container.read(themeProvider.notifier);
      
      notifier.setTheme(ThemeMode.system);
      expect(notifier.themeName, equals('System'));
      
      notifier.setTheme(ThemeMode.light);
      expect(notifier.themeName, equals('Light'));
      
      notifier.setTheme(ThemeMode.dark);
      expect(notifier.themeName, equals('Dark'));
    });
  });
}
