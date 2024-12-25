import 'package:bentobook/core/database/tables/sync_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:drift/drift.dart';
import 'package:flutter/material.dart' hide Table;
import 'package:bentobook/core/database/database.dart';
import 'package:bentobook/core/database/operations/user_operations.dart';

// Mock classes
class MockDatabase extends Mock implements AppDatabase {
  @override
  $UsersTable get users => MockUsersTable();
}

class MockUsersTable extends Mock implements $UsersTable {}

class MockSimpleSelectStatement extends Mock 
    implements SimpleSelectStatement<$UsersTable, User> {}

class MockInsertStatement extends Mock 
    implements InsertStatement<$UsersTable, User> {}

void main() {
  late MockDatabase mockDatabase;
  late MockSimpleSelectStatement selectStatement;
  
  final testUser = User(
    id: 1,
    email: 'test@example.com',
    username: 'testuser',
    displayName: 'Test User',
    firstName: 'Test',
    lastName: 'User',
    about: 'Test bio',
    preferredTheme: ThemeMode.system,
    preferredLanguage: 'en',
    avatarUrls: null,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    syncStatus: SyncStatus.synced,
  );

  setUp(() {
    mockDatabase = MockDatabase();
    selectStatement = MockSimpleSelectStatement();
    
    registerFallbackValue(MockUsersTable());
    registerFallbackValue($UsersTable(mockDatabase));
    registerFallbackValue(
      UsersCompanion.insert(
        email: 'test@example.com',
        username: const Value('testuser'),
        displayName: const Value('Test User'),
        firstName: const Value('Test'),
        lastName: const Value('Test'),
        about: const Value('Test bio'),
        preferredTheme: const Value(ThemeMode.system),
        preferredLanguage: const Value('en'),
        avatarUrls: const Value(null),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  });

  group('User Operations Tests', () {
    test('getUserByEmail returns user when found', () async {
      when(() => mockDatabase.select(any<$UsersTable>()))
          .thenReturn(selectStatement);
      when(() => selectStatement.where(any()))
          .thenReturn(selectStatement);
      when(() => selectStatement.getSingleOrNull())
          .thenAnswer((_) async => testUser);

      final user = await mockDatabase.getUserByEmail('test@example.com');
      
      expect(user, equals(testUser));
      verify(() => selectStatement.getSingleOrNull()).called(1);
    });

    test('getUserByEmail returns null when user not found', () async {
      when(() => mockDatabase.select(any<$UsersTable>()))
          .thenReturn(selectStatement);
      when(() => selectStatement.where(any()))
          .thenReturn(selectStatement);
      when(() => selectStatement.getSingleOrNull())
          .thenAnswer((_) async => null);

      final user = await mockDatabase.getUserByEmail('nonexistent@example.com');
      
      expect(user, null);
      verify(() => selectStatement.getSingleOrNull()).called(1);
    });

    test('createUser successfully creates a new user', () async {
      final insertStatement = MockInsertStatement();
      
      when(() => mockDatabase.into(any<$UsersTable>()))
          .thenReturn(insertStatement);
      when(() => insertStatement.insert(any<UsersCompanion>()))
          .thenAnswer((_) async => 1);
          
      when(() => mockDatabase.select(any<$UsersTable>()))
          .thenReturn(selectStatement);
      when(() => selectStatement.where(any()))
          .thenReturn(selectStatement);
      when(() => selectStatement.getSingle())
          .thenAnswer((_) async => testUser);
      
      final result = await mockDatabase.createUser(
        email: 'test@example.com',
        username: 'testuser',
        displayName: 'Test User',
        firstName: 'Test',
        lastName: 'User',
        about: 'Test bio',
      );

      expect(result, equals(testUser));
      verify(() => mockDatabase.into(any<$UsersTable>())).called(1);
      verify(() => insertStatement.insert(any<UsersCompanion>())).called(1);
      verify(() => selectStatement.getSingle()).called(1);
    });
  });
}