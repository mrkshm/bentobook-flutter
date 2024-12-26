import 'package:bentobook/core/api/api_client.dart';
import 'package:bentobook/core/api/api_endpoints.dart';
import 'package:bentobook/core/api/models/profile.dart' as api;
import 'package:bentobook/core/api/models/api_response.dart';
import 'package:bentobook/core/database/database.dart';
import 'package:bentobook/core/database/operations/profile_operations.dart';
import 'package:bentobook/core/auth/auth_state.dart';
import 'package:bentobook/core/auth/auth_service.dart';
import 'package:bentobook/core/shared/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:developer' as dev;

class ProfileRepository {
  final ApiClient _apiClient;
  final AppDatabase _db;
  final AuthState _authState;
  final AuthService _authService;

  ProfileRepository(this._apiClient, this._db, this._authState, this._authService);

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
        preferredTheme: 'light',
        preferredLanguage: dbProfile.preferredLanguage,
        createdAt: dbProfile.createdAt,
        updatedAt: dbProfile.updatedAt,
        email: '', // We don't store email in local DB
        avatarUrls: api.AvatarUrls(
          thumbnail: '',
          small: '',
          medium: '',
          large: '',
          original: '',
        ),
      ),
    );
  }

  Future<void> updateProfile({
    String? username,
    String? firstName,
    String? lastName,
    String? about,
  }) async {
    final userId = _authState.maybeMap(
      authenticated: (state) => state.user.id,
      orElse: () => throw Exception('User not authenticated'),
    );

    try {
      // Convert empty strings to null
      firstName = firstName?.isEmpty ?? true ? null : firstName;
      lastName = lastName?.isEmpty ?? true ? null : lastName;
      about = about?.isEmpty ?? true ? null : about;

      // First update local DB with pending status
      await _db.upsertProfile(
        userId: userId,
        firstName: firstName,
        lastName: lastName,
        about: about,
        syncStatus: 'pending',
      );

      // Only include fields in the request that were actually changed
      final request = api.ProfileUpdateRequest(
        firstName: firstName,
        lastName: lastName,
        about: about,
      );

      final response = await _apiClient.patch<Map<String, dynamic>>(
        ApiEndpoints.updateProfile,
        data: request.toJson(),
      );

      final apiResponse = ApiResponse<api.Profile>.fromJson(
        response,
        (json) => api.Profile.fromJson(json as Map<String, dynamic>),
      );

      if (!apiResponse.isSuccess) {
        final errorMessage = apiResponse.errors.isNotEmpty 
            ? apiResponse.errors.first.detail
            : 'Failed to update profile';
        throw Exception(errorMessage);
      }

      if (apiResponse.data == null) {
        throw Exception('Profile data is missing from response');
      }

      // Update local DB with synced status and the fields that were changed
      final profile = apiResponse.data!.attributes;
      await _db.upsertProfile(
        userId: userId,
        firstName: firstName != null ? profile.firstName : null,
        lastName: lastName != null ? profile.lastName : null,
        about: about != null ? profile.about : null,
        syncStatus: 'synced',
      );

      // Update auth state with new profile data
      _authState.maybeMap(
        authenticated: (state) {
          final updatedUser = state.user.copyWith(
            attributes: state.user.attributes.copyWith(
              firstName: firstName ?? state.user.attributes.firstName,
              lastName: lastName ?? state.user.attributes.lastName,
              profile: state.user.attributes.profile?.copyWith(
                about: about ?? state.user.attributes.profile?.about,
              ),
            ),
          );
          _authService.updateUserProfile(updatedUser);
        },
        orElse: () {},
      );

      dev.log('ProfileRepository: Profile updated successfully');
    } catch (e, stackTrace) {
      dev.log('ProfileRepository: Failed to update profile', error: e, stackTrace: stackTrace);
      // Mark as failed in local DB
      await _db.updateProfileSyncStatus(userId, 'failed');
      rethrow;
    }
  }

  Stream<api.Profile?> watchProfile() async* {
    final userId = _authState.maybeMap(
      authenticated: (state) => state.user.id,
      orElse: () => null,
    );

    if (userId == null) {
      yield null;
      return;
    }

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
  final authState = ref.watch(authServiceProvider);
  final authService = ref.read(authServiceProvider.notifier);
  return ProfileRepository(apiClient, db, authState, authService);
});