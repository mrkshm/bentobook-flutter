import 'package:bentobook/core/api/api_client.dart';
import 'package:bentobook/core/api/models/profile.dart' as api;
import 'package:bentobook/core/database/database.dart';
import 'package:bentobook/core/database/operations/profile_operations.dart';
import 'package:bentobook/core/sync/models/syncable.dart';
import 'package:bentobook/core/sync/resolvers/profile_resolver.dart';
import 'dart:developer' as dev;

class ProfileRepository {
  final ApiClient _apiClient;
  final AppDatabase _db;
  final _resolver = ProfileResolver();

  ProfileRepository(this._apiClient, this._db);

  api.Profile _convertToApiProfile(Profile dbProfile) {
    return api.Profile(
      id: dbProfile.userId,
      type: 'profile',
      attributes: api.ProfileAttributes(
        username: dbProfile.displayName ?? '',
        firstName: dbProfile.firstName,
        lastName: dbProfile.lastName,
        about: dbProfile.about,
        fullName: '${dbProfile.firstName ?? ''} ${dbProfile.lastName ?? ''}'.trim(),
        displayName: dbProfile.displayName ?? '',
        preferredLanguage: dbProfile.preferredLanguage,
        createdAt: dbProfile.createdAt,
        updatedAt: dbProfile.updatedAt,
        email: '', // Email handled by auth
        avatarUrls: null,
      ),
    );
  }

  Future<api.Profile> getProfile(String userId) async {
    try {
      // First try to get from API
      final response = await _apiClient.getProfile(userId);
      if (response.data == null) {
        throw Exception('Profile data is null');
      }

      final apiProfile = response.data!;
      
      // Get existing profile from database
      final dbProfile = await _db.getProfile(userId);
      
      if (dbProfile != null) {
        // Convert database profile to API format for comparison
        final localProfile = _convertToApiProfile(dbProfile);
        
        // Resolve any conflicts
        final resolution = _resolver.resolveConflict(
          localData: localProfile.toSyncable(),
          remoteData: apiProfile.toSyncable(),
          strategy: ConflictStrategy.merge,
        );

        if (resolution.shouldUpdate) {
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
          return localProfile;
        }
      } else {
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
      dev.log('Failed to get profile', error: e);
      rethrow;
    }
  }

  Future<api.Profile> updateProfile({
    required String userId,
    String? firstName,
    String? lastName,
    String? about,
    String? displayName,
    String? preferredTheme,
    String? preferredLanguage,
  }) async {
    try {
      // Update local DB with pending status
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

      // Update API
      final response = await _apiClient.updateProfile(
        request: api.ProfileUpdateRequest(
          firstName: firstName,
          lastName: lastName,
          about: about,
          displayName: displayName,
          preferredTheme: preferredTheme,
          preferredLanguage: preferredLanguage,
        ),
      );

      dev.log('ProfileRepository: Profile updated successfully');
      return response.data!;
    } catch (e, stack) {
      dev.log('ProfileRepository: Failed to update profile', error: e, stackTrace: stack);
      await _db.updateProfileSyncStatus(userId, 'failed');
      rethrow;
    }
  }

  Stream<api.Profile?> watchProfile(String userId) async* {
    await for (final dbProfile in _db.watchProfile(userId)) {
      if (dbProfile == null) {
        yield null;
      } else {
        yield _convertToApiProfile(dbProfile);
      }
    }
  }
}