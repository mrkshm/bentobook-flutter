import 'package:bentobook/core/api/api_client.dart';
import 'package:bentobook/core/api/models/profile.dart' as api;
import 'package:bentobook/core/database/database.dart';
import 'package:bentobook/core/database/operations/profile_operations.dart';
import 'package:bentobook/core/shared/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:developer' as dev;

class ProfileRepository {
  final ApiClient _apiClient;
  final AppDatabase _db;

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
      final response = await _apiClient.getProfile(userId);
      if (response.data == null) {
        throw Exception('Profile data is null');
      }
      
      await _db.upsertProfile(
        userId: userId,
        firstName: response.data!.attributes.firstName,
        lastName: response.data!.attributes.lastName,
        about: response.data!.attributes.about,
        displayName: response.data!.attributes.displayName,
        preferredLanguage: response.data!.attributes.preferredLanguage,
        syncStatus: 'synced',
      );
      return response.data!;
    } catch (e, stack) {
      dev.log('ProfileRepository: Failed to get profile', error: e, stackTrace: stack);
      // Try to return cached profile
      final cached = await _db.getProfile(userId);
      if (cached != null) {
        return _convertToApiProfile(cached);
      }
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

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final db = ref.watch(databaseProvider);
  return ProfileRepository(apiClient, db);
});