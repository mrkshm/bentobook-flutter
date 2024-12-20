import 'package:bentobook/core/database/database.dart';
import 'package:bentobook/core/api/models/user.dart' as api;
import 'package:bentobook/core/database/tables/sync_status.dart';
import 'package:drift/drift.dart';
import 'dart:developer' as dev;

class UserRepository {
  final AppDatabase _db;

  UserRepository(this._db);

  Future<void> saveUserFromApi(api.User apiUser) async {
    try {
      final profile = apiUser.attributes.profile;
      final email = apiUser.attributes.email;
      dev.log('UserRepository: Starting to save API user data');
      dev.log('UserRepository: Email: $email');
      if (profile != null) {
        dev.log('UserRepository: Profile data available');
        dev.log('UserRepository: Username: ${profile.username}');
        dev.log('UserRepository: Display Name: ${profile.displayName}');
      } else {
        dev.log('UserRepository: No profile data available');
      }

      // Convert avatar URLs to correct type
      Map<String, String>? avatarUrls;
      final userAvatarUrls = profile?.avatarUrls;
      if (userAvatarUrls != null) {
        avatarUrls = {
          if (userAvatarUrls.small != null) 'small': userAvatarUrls.small!,
          if (userAvatarUrls.medium != null) 'medium': userAvatarUrls.medium!,
          if (userAvatarUrls.large != null) 'large': userAvatarUrls.large!,
        };
      }

      // First try to get existing user
      var existingUser = await _db.getUserByEmail(email);
      if (existingUser != null) {
        dev.log('UserRepository: Updating existing user');
        await _db.updateUser(User(
          id: existingUser.id,  // Keep local ID
          email: email,
          username: profile?.username,
          displayName: profile?.displayName,
          firstName: profile?.firstName,
          lastName: profile?.lastName,
          about: profile?.about ?? '',
          preferredTheme: profile?.preferredTheme ?? 'light',
          preferredLanguage: profile?.preferredLanguage ?? 'en',
          avatarUrls: avatarUrls,
          createdAt: existingUser.createdAt,
          updatedAt: DateTime.now(),
          syncStatus: SyncStatus.synced,
        ));
        dev.log('UserRepository: Updated existing user');
      } else {
        dev.log('UserRepository: Creating new user');
        final user = await _db.createUser(
          email: email,
          username: profile?.username,
          displayName: profile?.displayName,
          firstName: profile?.firstName,
          lastName: profile?.lastName,
          about: profile?.about ?? '',
          preferredTheme: profile?.preferredTheme ?? 'light',
          preferredLanguage: profile?.preferredLanguage ?? 'en',
          avatarUrls: avatarUrls,
        );
        dev.log('UserRepository: Created new user: $user');
      }

      // Verify the save
      final savedUser = await _db.getUserByEmail(email);
      if (savedUser != null) {
        dev.log('UserRepository: User save verified');
        dev.log('UserRepository: Saved user: $savedUser');
      } else {
        dev.log('UserRepository: Failed to verify user save');
        throw Exception('Failed to verify user save');
      }
    } catch (e, stackTrace) {
      dev.log('UserRepository: Error saving user', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Stream<User?> watchCurrentUser(String email) {
    dev.log('UserRepository: Starting to watch user with email: $email');
    if (email.isEmpty) {
      dev.log('UserRepository: Empty email provided, returning empty stream');
      return Stream.value(null);
    }
    return _db.watchUserByEmail(email).map((user) {
      dev.log('UserRepository: User data changed');
      dev.log('UserRepository: User email: ${user?.email ?? 'null'}');
      dev.log('UserRepository: User data: ${user?.toString() ?? 'null'}');
      return user;
    });
  }

  Future<User?> getCurrentUser(String email) async {
    dev.log('UserRepository: Getting user with email: $email');
    final user = await _db.getUserByEmail(email);
    dev.log('UserRepository: Retrieved user: ${user?.email}');
    return user;
  }

  Future<List<User>> getAllUsers() async {
    dev.log('UserRepository: Getting all users');
    final users = await _db.getAllUsers();
    dev.log('UserRepository: Found ${users.length} users');
    for (final user in users) {
      dev.log('UserRepository: User: ${user.email} (${user.displayName})');
    }
    return users;
  }

  Future<User?> getUserByEmail(String email) async {
    dev.log('UserRepository: Getting user by email: $email');
    final user = await _db.getUserByEmail(email);
    if (user != null) {
      dev.log('UserRepository: Found user: ${user.email} (${user.displayName})');
    } else {
      dev.log('UserRepository: No user found for email: $email');
    }
    return user;
  }
}