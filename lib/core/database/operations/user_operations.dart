import 'package:flutter/material.dart' show ThemeMode;
import '../database.dart';
import 'dart:developer' as dev;
import 'package:drift/drift.dart';

extension UserOperations on AppDatabase {
  Future<User?> getUserByEmail(String email) async {
    dev.log('Database: Getting user by email: $email');
    try {
      return (select(users)..where((t) => t.email.equals(email)))
          .getSingleOrNull();
    } catch (e) {
      dev.log('Database: Error getting user by email', error: e);
      rethrow;
    }
  }

  Stream<User?> watchUserByEmail(String email) {
    dev.log('Database: Starting to watch user by email: $email');
    return (select(users)..where((t) => t.email.equals(email)))
        .watchSingleOrNull();
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
    final user = UsersCompanion.insert(
      email: email,
      username: Value(username),
      displayName: Value(displayName),
      firstName: Value(firstName),
      lastName: Value(lastName),
      about: Value(about),
      preferredTheme: Value(preferredTheme ?? ThemeMode.system),
      preferredLanguage: Value(preferredLanguage ?? 'en'),
      avatarUrls: Value(avatarUrls),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final id = await into(users).insert(user);
    return (select(users)..where((t) => t.id.equals(id))).getSingle();
  }

  Future<User> updateUser(User user) async {
    dev.log('Database: Updating user with ID: ${user.id}');
    try {
      await update(users).replace(user);
      return user;
    } catch (e) {
      dev.log('Database: Error updating user', error: e);
      rethrow;
    }
  }

  Future<void> updateUserTheme(String email, ThemeMode theme) async {
    dev.log('Database: Updating theme to ${theme.toString()} for user: $email');
    try {
      final user = await getUserByEmail(email);
      if (user == null) {
        throw StateError('User not found: $email');
      }
      await updateUser(user.copyWith(
        preferredTheme: theme,
        updatedAt: DateTime.now(),
      ));
    } catch (e) {
      dev.log('Database: Error updating user theme', error: e);
      rethrow;
    }
  }

  Future<List<User>> getAllUsers() async {
    dev.log('Database: Getting all users');
    try {
      return await select(users).get();
    } catch (e) {
      dev.log('Database: Error getting all users', error: e);
      rethrow;
    }
  }
}
