import 'package:bentobook/core/database/database.dart';
import 'package:bentobook/core/api/models/user.dart' as api;
import 'package:bentobook/core/database/operations/user_operations.dart';
import 'package:bentobook/core/database/tables/sync_status.dart';
import 'package:bentobook/core/theme/theme_persistence.dart';
import 'package:bentobook/core/sync/conflict_resolver.dart';
import 'package:bentobook/core/sync/models/syncable.dart';
import 'dart:developer' as dev;

class UserSyncable implements Syncable {
  final User user;

  UserSyncable(this.user);

  @override
  String get id => user.id.toString();

  @override
  DateTime get updatedAt => user.updatedAt;

  @override
  String? get syncStatus => user.syncStatus.toString();

  @override
  String get type => 'user';
}

class ApiUserSyncable implements Syncable {
  final api.User user;

  ApiUserSyncable(this.user);

  @override
  String get id => user.id;

  @override
  DateTime get updatedAt => user.attributes.createdAt ?? DateTime(0);

  @override
  String? get syncStatus => null;

  @override
  String get type => 'user';
}

class UserResolver implements ConflictResolver {
  @override
  Map<String, ConflictResolver> get resolvers => {'user': this};

  @override
  ConflictResolution<Syncable> resolveConflict({
    required Syncable localData,
    required Syncable remoteData,
    ConflictStrategy strategy = ConflictStrategy.remoteWins,
  }) {
    return ConflictResolution(
      shouldUpdate: strategy == ConflictStrategy.remoteWins ||
          (strategy == ConflictStrategy.newerWins &&
              remoteData.updatedAt.isAfter(localData.updatedAt)),
      resolvedData: remoteData,
    );
  }

  @override
  ConflictResolution<Syncable> mergeData(Syncable local, Syncable remote) {
    return ConflictResolution(
      shouldUpdate: true,
      resolvedData: remote,
    );
  }
}

class UserRepository {
  final AppDatabase _db;
  final _conflictResolver = UserResolver();

  UserRepository(this._db);

  Future<void> saveUserFromApi(api.User apiUser) async {
    try {
      final email = apiUser.attributes.email;
      dev.log('UserRepository: Starting to save API user data');

      // First try to get existing user
      final existingUser = await _db.getUserByEmail(email);

      if (existingUser != null) {
        dev.log('UserRepository: Found existing user, checking for conflicts');

        final localData = UserSyncable(existingUser);
        final remoteData = ApiUserSyncable(apiUser);

        final resolution = _conflictResolver.resolveConflict(
          localData: localData,
          remoteData: remoteData,
        );

        dev.log('UserRepository: Conflict resolution - ${resolution.message}');

        if (!resolution.shouldUpdate) {
          dev.log('UserRepository: Keeping local data');
          return;
        }
      }

      // Convert avatar URLs
      Map<String, String>? avatarUrls;
      final userAvatarUrls = apiUser.attributes.profile?.avatarUrls;
      if (userAvatarUrls != null) {
        avatarUrls = {
          if (userAvatarUrls.small != null) 'small': userAvatarUrls.small!,
          if (userAvatarUrls.medium != null) 'medium': userAvatarUrls.medium!,
          if (userAvatarUrls.large != null) 'large': userAvatarUrls.large!,
        };
      }

      final profile = apiUser.attributes.profile;
      final user = User(
        id: int.parse(apiUser.id),
        email: email,
        username: profile?.username,
        displayName: profile?.displayName,
        firstName: profile?.firstName,
        lastName: profile?.lastName,
        about: profile?.about ?? '',
        preferredTheme: ThemePersistence.stringToTheme(profile?.preferredTheme),
        preferredLanguage: profile?.preferredLanguage ?? 'en',
        avatarUrls: avatarUrls,
        createdAt: existingUser?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        syncStatus: SyncStatus.synced,
      );

      if (existingUser != null) {
        await _db.updateUser(user);
        dev.log('UserRepository: Updated existing user');
      } else {
        await _db.createUser(
          id: user.id,
          email: user.email,
          username: user.username,
          displayName: user.displayName,
          firstName: user.firstName,
          lastName: user.lastName,
          about: user.about,
          preferredTheme: user.preferredTheme,
          preferredLanguage: user.preferredLanguage,
          avatarUrls: user.avatarUrls,
        );
        dev.log('UserRepository: Created new user');
      }

      // Verify the save
      final savedUser = await _db.getUserByEmail(email);
      if (savedUser == null) {
        throw Exception('Failed to verify user save');
      }
      dev.log('UserRepository: User save verified');
    } catch (e, stackTrace) {
      dev.log('UserRepository: Error saving user',
          error: e, stackTrace: stackTrace);
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
    return _db.getUserByEmail(email);
  }
}
