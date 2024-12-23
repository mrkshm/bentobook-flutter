import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart' show ThemeMode;
import 'tables/users_table.dart';
import 'tables/sync_status.dart';
import 'tables/operation_queue.dart';
import 'package:bentobook/core/sync/operation_types.dart';
import 'dart:developer' as dev;

part 'database.g.dart';

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    try {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'bentobook.sqlite'));
      dev.log('Database: Opening connection at ${file.path}');
      
      if (!file.existsSync()) {
        dev.log('Database: Creating new database file');
        file.createSync(recursive: true);
      }
      
      final database = NativeDatabase.createInBackground(file);
      dev.log('Database: Connection created successfully');
      return database;
    } catch (e, stackTrace) {
      dev.log('Database: Error opening connection', error: e, stackTrace: stackTrace);
      rethrow;
    }
  });
}

@DriftDatabase(tables: [
  Users, 
  SyncStatusTable, 
  OperationQueue, 
  ])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection()) {
    _initDatabase();
  }

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      dev.log('Database: Creating tables');
      await m.createAll();
      dev.log('Database: Tables created successfully');
    },
    onUpgrade: (Migrator m, int from, int to) async {
      dev.log('Database: Upgrading from version $from to $to');
      if (from < 2) {
        // Add new columns for version 2
        await m.addColumn(users, users.avatarUrls);
        await m.addColumn(users, users.syncStatus);
        dev.log('Database: Added new columns for version 2');
      }
      if (from < 4) {
        dev.log('Database: Adding operation queue table');
        await m.createTable(operationQueue);
        dev.log('Database: Operation queue table created');
      }
    },
    beforeOpen: (details) async {
      if (details.wasCreated) {
        dev.log('Database: New database created');
      } else {
        dev.log('Database: Opening existing database');
        dev.log('Database: Schema version ${details.versionNow}');
      }
      await customStatement('PRAGMA foreign_keys = ON');
      dev.log('Database: Foreign keys enabled');
    },
  );

  Future<void> _initDatabase() async {
    try {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'bentobook.sqlite'));
      dev.log('Database: Initializing at ${file.path}');
      dev.log('Database: File exists: ${file.existsSync()}');
      if (file.existsSync()) {
        dev.log('Database: File size: ${await file.length()} bytes');
        dev.log('Database: File permissions: ${file.statSync().modeString()}');
      }

      // Verify database connection
      try {
        await customStatement('SELECT 1');
        dev.log('Database: Connection test successful');
      } catch (e) {
        dev.log('Database: Connection test failed', error: e);
        rethrow;
      }

      // List all users in database
      try {
        final allUsers = await select(users).get();
        dev.log('Database: Current users in database: ${allUsers.length}');
        for (final user in allUsers) {
          dev.log('Database: User - ID: ${user.id}, Email: ${user.email}');
        }
      } catch (e) {
        dev.log('Database: Error listing users', error: e);
        rethrow;
      }
    } catch (e, stackTrace) {
      dev.log('Database: Error initializing database',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

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
    dev.log('Database: Creating user with email: $email');
    dev.log('Database: Username: $username');
    dev.log('Database: Display Name: $displayName');
    
    try {
      // First check if user exists
      final existingUser = await getUserByEmail(email);
      if (existingUser != null) {
        dev.log('Database: User already exists, updating instead');
        final theme = preferredTheme ?? ThemeMode.light;
        dev.log('Database: Saving theme change to: ${theme.toString()}');
        
        final updatedUser = existingUser.copyWith(
          username: Value(username),
          displayName: Value(displayName),
          firstName: Value(firstName),
          lastName: Value(lastName),
          about: Value(about),
          preferredTheme: theme,
          preferredLanguage: preferredLanguage ?? 'en',
          avatarUrls: Value(avatarUrls),
          updatedAt: DateTime.now(),
        );
        await (update(users)..where((t) => t.id.equals(existingUser.id)))
          .write(UsersCompanion(
            username: Value(updatedUser.username),
            displayName: Value(updatedUser.displayName),
            firstName: Value(updatedUser.firstName),
            lastName: Value(updatedUser.lastName),
            about: Value(updatedUser.about),
            preferredTheme: Value(updatedUser.preferredTheme),
            preferredLanguage: Value(updatedUser.preferredLanguage),
            avatarUrls: Value(updatedUser.avatarUrls),
            updatedAt: Value(updatedUser.updatedAt),
          ));
        return updatedUser;
      }

      dev.log('Database: Creating new user');
      final userId = await into(users).insert(
        UsersCompanion.insert(
          email: email,
          username: Value(username),
          displayName: Value(displayName),
          firstName: Value(firstName),
          lastName: Value(lastName),
          about: Value(about),
          preferredTheme: Value(preferredTheme ?? ThemeMode.light),
          preferredLanguage: Value(preferredLanguage ?? 'en'),
          avatarUrls: Value(avatarUrls),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      
      dev.log('Database: User created with ID: $userId');
      
      // Read back the created user
      final user = await (select(users)..where((t) => t.id.equals(userId))).getSingle();
      dev.log('Database: Created user data: ${user.toString()}');
      return user;
    } catch (e, stackTrace) {
      dev.log('Database: Error creating user', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<User> updateUser(User user) async {
    dev.log('Database: Updating user with ID: ${user.id}');
    try {
      await update(users).replace(user);
      dev.log('Database: User updated successfully');
      return user;
    } catch (e, stackTrace) {
      dev.log('Database: Error updating user', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<User?> getUserByEmail(String email) async {
    dev.log('Database: Getting user by email: $email');
    try {
      final user = await (select(users)..where((t) => t.email.equals(email)))
          .getSingleOrNull();
      dev.log('Database: Retrieved user: ${user?.email ?? 'null'}');
      return user;
    } catch (e, stackTrace) {
      dev.log('Database: Error getting user by email', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Stream<User?> watchUserByEmail(String email) {
    dev.log('Database: Starting to watch user by email: $email');
    return (select(users)..where((t) => t.email.equals(email)))
        .watchSingleOrNull()
        .map((user) {
          dev.log('Database: Watch update - User: ${user?.email ?? 'null'}');
          return user;
        });
  }

  Future<List<User>> getAllUsers() {
    dev.log('Database: Getting all users');
    return (select(users)).get();
  }

  Future<void> updateUserTheme(String email, ThemeMode theme) async {
    dev.log('Database: Updating theme to ${theme.toString()} for user: $email');
    try {
      final user = await getUserByEmail(email);
      if (user == null) {
        throw StateError('User not found: $email');
      }

      final updatedUser = user.copyWith(
        preferredTheme: theme,
        updatedAt: DateTime.now(),
      );
      
      await updateUser(updatedUser);
      dev.log('Database: Theme updated successfully');
    } catch (e) {
      dev.log('Database: Error updating user theme', error: e);
      rethrow;
    }
  }
}