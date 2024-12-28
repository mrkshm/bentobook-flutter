import 'package:bentobook/core/api/api_client.dart';
import 'package:bentobook/core/api/models/profile.dart' as api;
import 'package:bentobook/core/database/database.dart';
import 'package:bentobook/core/database/operations/profile_operations.dart';
import 'package:bentobook/core/sync/models/syncable.dart';
import 'package:bentobook/core/sync/operation_types.dart';
import 'package:bentobook/core/sync/queue_manager.dart';
import 'package:bentobook/core/sync/resolvers/profile_resolver.dart';
import 'dart:developer' as dev;

class ProfileRepository {
  final ApiClient _apiClient;
  final AppDatabase _db;
  final QueueManager _queueManager;
  final _resolver = ProfileResolver();

  ProfileRepository(this._apiClient, this._db, this._queueManager);

  api.Profile _convertToApiProfile(Profile dbProfile) {
    return api.Profile(
      id: dbProfile.userId.toString(),
      type: 'profile',
      attributes: api.ProfileAttributes(
        username: dbProfile.displayName ?? '',
        firstName: dbProfile.firstName,
        lastName: dbProfile.lastName,
        about: dbProfile.about,
        fullName:
            '${dbProfile.firstName ?? ''} ${dbProfile.lastName ?? ''}'.trim(),
        displayName: dbProfile.displayName ?? '',
        preferredLanguage: dbProfile.preferredLanguage,
        createdAt: dbProfile.createdAt,
        updatedAt: dbProfile.updatedAt,
        email: '', // Email handled by auth
        avatarUrls: null,
      ),
    );
  }

  Future<api.Profile> getProfile(int userId) async {
    try {
      // 1. First try to get from local DB
      dev.log(
          'ProfileRepository: Checking local database first for user: $userId');
      final dbProfile = await _db.getProfile(userId);

      if (dbProfile != null) {
        dev.log('ProfileRepository: Found profile in local database');
        final localProfile = _convertToApiProfile(dbProfile);

        // If we're offline or have pending changes, return local data
        if (dbProfile.syncStatus == 'pending') {
          dev.log('ProfileRepository: Using pending local changes');
          return localProfile;
        }

        // If we're online, try to sync with server
        try {
          dev.log('ProfileRepository: Attempting to sync with server');
          final response = await _apiClient.getProfile(userId.toString());
          if (response.data != null) {
            final apiProfile = response.data!;

            // Resolve any conflicts
            final resolution = _resolver.resolveConflict(
              localData: localProfile.toSyncable(),
              remoteData: apiProfile.toSyncable(),
              strategy: ConflictStrategy.merge,
            );

            if (resolution.shouldUpdate) {
              dev.log(
                  'ProfileRepository: Updating local profile with server data');
              final resolvedProfile = resolution.resolvedData.profile;
              await _db.upsertProfile(
                userId: userId,
                firstName: resolvedProfile.attributes.firstName,
                lastName: resolvedProfile.attributes.lastName,
                about: resolvedProfile.attributes.about,
                displayName: resolvedProfile.attributes.displayName,
                preferredLanguage: resolvedProfile.attributes.preferredLanguage,
                syncStatus: 'synced',
              );
              return resolvedProfile;
            }
          }
        } catch (e) {
          dev.log(
              'ProfileRepository: Failed to sync with server, using local data',
              error: e);
          // On API error, return local data
          return localProfile;
        }

        return localProfile;
      }

      // 2. If no local data, try to get from API
      dev.log('ProfileRepository: No local profile, fetching from API');
      final response = await _apiClient.getProfile(userId.toString());
      if (response.data == null) {
        throw Exception('Profile data is null');
      }

      final apiProfile = response.data!;

      // Save API data to local DB
      await _db.upsertProfile(
        userId: userId,
        firstName: apiProfile.attributes.firstName,
        lastName: apiProfile.attributes.lastName,
        about: apiProfile.attributes.about,
        displayName: apiProfile.attributes.displayName,
        preferredLanguage: apiProfile.attributes.preferredLanguage,
        syncStatus: 'synced',
      );

      return apiProfile;
    } catch (e) {
      dev.log('ProfileRepository: Failed to get profile', error: e);
      rethrow;
    }
  }

  // Helper method to safely convert string ID to int
  int _parseUserId(String userId) {
    try {
      return int.parse(userId);
    } catch (e) {
      dev.log('ProfileRepository: Error parsing user ID: $userId', error: e);
      throw Exception('Invalid user ID format: $userId');
    }
  }

  Future<api.Profile> updateProfile({
    required int userId,
    String? firstName,
    String? lastName,
    String? about,
    String? displayName,
    String? preferredTheme,
    String? preferredLanguage,
  }) async {
    // 1. Update local DB first
    await _db.upsertProfile(
      userId: userId,
      firstName: firstName,
      lastName: lastName,
      about: about,
      displayName: displayName,
      preferredTheme: preferredTheme,
      preferredLanguage: preferredLanguage,
      syncStatus: 'pending',
    );

    // 2. Try to sync immediately if online
    await _queueManager.enqueueOperation(
      type: OperationType.profileUpdate,
      payload: {
        'userId': userId,
        'firstName': firstName,
        'lastName': lastName,
        'about': about,
        'displayName': displayName,
        'preferredTheme': preferredTheme,
        'preferredLanguage': preferredLanguage,
      },
    );

    // 3. Return local profile immediately
    final localProfile = await _db.getProfile(userId);
    return _convertToApiProfile(localProfile!);
  }

  // Convenience method that accepts string ID
  Future<api.Profile> updateProfileFromString({
    required String userId,
    String? firstName,
    String? lastName,
    String? about,
    String? displayName,
    String? preferredTheme,
    String? preferredLanguage,
  }) async {
    final intId = _parseUserId(userId);
    return updateProfile(
      userId: intId,
      firstName: firstName,
      lastName: lastName,
      about: about,
      displayName: displayName,
      preferredTheme: preferredTheme,
      preferredLanguage: preferredLanguage,
    );
  }

  Stream<api.Profile?> watchProfile(int userId) async* {
    await for (final dbProfile in _db.watchProfile(userId)) {
      if (dbProfile == null) {
        yield null;
      } else {
        yield _convertToApiProfile(dbProfile);
      }
    }
  }
}
