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
      dev.log('ProfileRepository: Getting profile from API for user: $userId');
      // First try to get from API
      final response = await _apiClient.getProfile(userId.toString());
      if (response.data == null) {
        dev.log('ProfileRepository: API returned null profile data');
        throw Exception('Profile data is null');
      }

      dev.log(
          'ProfileRepository: Got profile from API, checking local database');
      final apiProfile = response.data!;

      // Get existing profile from database
      final dbProfile = await _db.getProfile(userId);

      if (dbProfile != null) {
        dev.log('ProfileRepository: Found existing profile in database');
        // Convert database profile to API format for comparison
        final localProfile = _convertToApiProfile(dbProfile);

        // Resolve any conflicts
        final resolution = _resolver.resolveConflict(
          localData: localProfile.toSyncable(),
          remoteData: apiProfile.toSyncable(),
          strategy: ConflictStrategy.merge,
        );

        if (resolution.shouldUpdate) {
          dev.log(
              'ProfileRepository: Updating local profile with resolved data');
          // Save resolved data to database
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
        } else {
          dev.log('ProfileRepository: Using existing local profile data');
          return localProfile;
        }
      } else {
        dev.log('ProfileRepository: No local profile found, saving API data');
        // No local data, save API data to database
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
      }
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
