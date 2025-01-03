import 'package:bentobook/core/api/api_client.dart';
import 'package:bentobook/core/api/api_exception.dart';
import 'package:bentobook/core/api/models/profile.dart' as api;
import 'package:bentobook/core/database/database.dart';
import 'package:bentobook/core/database/operations/profile_operations.dart';
import 'package:bentobook/core/sync/conflict_resolver.dart';
import 'package:bentobook/core/sync/operation_types.dart';
import 'package:bentobook/core/sync/queue_manager.dart';
import 'package:bentobook/core/image/image_manager.dart';
import 'dart:developer' as dev;
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:bentobook/core/config/env_config.dart';
import 'package:drift/drift.dart';

class ProfileRepository {
  final ApiClient _apiClient;
  final AppDatabase _db;
  final QueueManager _queueManager;
  final ImageManager _imageManager;
  final EnvConfig _config;

  ProfileRepository({
    required AppDatabase db,
    required ApiClient apiClient,
    required QueueManager queueManager,
    required ConflictResolver resolver,
    required EnvConfig config,
    ImageManager? imageManager,
  })  : _db = db,
        _apiClient = apiClient,
        _queueManager = queueManager,
        _config = config,
        _imageManager = imageManager ?? ImageManager(dio: Dio());

  api.Profile _convertToApiProfile(Profile dbProfile,
      {api.AvatarUrls? serverUrls}) {
    return api.Profile(
      id: dbProfile.userId.toString(),
      type: 'profile',
      attributes: api.ProfileAttributes(
        username: dbProfile.username ?? '',
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
        avatarUrls: serverUrls,
      ),
      localThumbnailPath: dbProfile.thumbnailPath,
      localMediumPath: dbProfile.mediumPath,
    );
  }

  Future<api.Profile> getProfile(int userId) async {
    try {
      dev.log('ProfileRepository: Getting profile for user $userId');

      // 1. Get local data
      final dbProfile = await _db.getProfile(userId);
      final localProfile =
          dbProfile != null ? _convertToApiProfile(dbProfile) : null;

      dev.log(
          'ProfileRepository: Local profile avatar URLs: ${localProfile?.attributes.avatarUrls}');
      dev.log(
          'ProfileRepository: Local profile sync status: ${dbProfile?.syncStatus}');

      // 2. Try server fetch if needed
      if (localProfile == null || _isStale(dbProfile!.updatedAt)) {
        try {
          dev.log('ProfileRepository: Fetching from server');
          final serverProfile = await _fetchFromServer(userId);

          if (serverProfile.attributes.avatarUrls != null) {
            return syncProfileImages(serverProfile);
          }
          return serverProfile;
        } catch (e) {
          dev.log('ProfileRepository: Server fetch failed', error: e);
        }
      }

      if (localProfile == null) {
        throw Exception('No profile data available');
      }
      return localProfile;
    } catch (e) {
      dev.log('ProfileRepository: Error getting profile', error: e);
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
    String? username,
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
      username: username,
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
        'username': username,
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
    String? username,
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
      username: username,
    );
  }

  Stream<api.Profile?> watchProfile(int userId) {
    dev.log('ProfileRepository: Starting watchProfile for user $userId');
    return _db.watchProfile(userId).map((dbProfile) {
      dev.log('ProfileRepository: DB Profile update received: $dbProfile');
      if (dbProfile == null) {
        dev.log('ProfileRepository: DB returned null profile');
        return null;
      }
      final apiProfile = _convertToApiProfile(dbProfile);
      dev.log(
          'ProfileRepository: Converted to API profile: ${apiProfile.toJson()}');
      return apiProfile;
    });
  }

  Future<bool> checkUsernameAvailability(String username) async {
    try {
      dev.log('ProfileRepository: Checking username availability: $username');
      final isAvailable =
          await _apiClient.profileApi.checkUsernameAvailability(username);
      dev.log(
          'ProfileRepository: Username $username is ${isAvailable ? 'available' : 'taken'}');
      return isAvailable;
    } catch (e) {
      dev.log('ProfileRepository: Failed to check username availability',
          error: e);
      rethrow;
    }
  }

  String? _extractTimestamp(String? path) {
    if (path == null) return null;

    // Match any timestamp pattern in the path
    final timestampRegex = RegExp(r'_(\d+)\.(jpg|webp|png)$');
    final match = timestampRegex.firstMatch(path);

    dev.log('ProfileRepository: Extracting timestamp from path:');
    dev.log('  Input path: $path');
    dev.log('  Extracted timestamp: ${match?.group(1)}');

    return match?.group(1);
  }

  Future<api.Profile> syncProfileImages(api.Profile profile,
      {bool forceSync = false}) async {
    try {
      dev.log('ProfileRepository: Starting syncProfileImages');

      if (profile.attributes.avatarUrls == null) {
        return profile;
      }

      final userId = int.parse(profile.id);
      final dbProfile = await _db.getProfile(userId);

      // Check if files already exist and match
      if (!forceSync && dbProfile?.thumbnailPath != null) {
        final serverFilename =
            profile.attributes.avatarUrls!.thumbnail!.split('/').last;
        final localFilename = dbProfile!.thumbnailPath!.split('/').last;

        if (serverFilename == localFilename) {
          dev.log(
              'ProfileRepository: Files already synced, returning existing profile');
          return profile.copyWith(
            localThumbnailPath: dbProfile.thumbnailPath,
            localMediumPath: dbProfile.mediumPath,
          );
        }
      }

      // Continue with download only if files don't match
      dev.log('ProfileRepository: ACTUALLY STARTING DOWNLOAD');
      final newPaths = await _imageManager.downloadAndSaveProfileImages(
        userId: userId.toString(),
        thumbnailUrl:
            '${_config.baseUrl}${profile.attributes.avatarUrls!.thumbnail}',
        mediumUrl: '${_config.baseUrl}${profile.attributes.avatarUrls!.medium}',
      );

      // Update database with new paths immediately
      if (dbProfile != null) {
        await _db.updateProfile(
          dbProfile.copyWith(
            thumbnailPath: Value(newPaths.thumbnailPath),
            mediumPath: Value(newPaths.mediumPath),
            imageUpdatedAt: Value(DateTime.now()),
          ),
        );
      }

      // Return profile with new paths
      return profile.copyWith(
        localThumbnailPath: newPaths.thumbnailPath,
        localMediumPath: newPaths.mediumPath,
      );
    } catch (e) {
      dev.log('ProfileRepository: Error in syncProfileImages', error: e);
      rethrow;
    }
  }

  Future<String?> getProfileImagePath(int userId,
      {bool thumbnail = true}) async {
    final profile = await _db.getProfile(userId);
    return thumbnail ? profile?.thumbnailPath : profile?.mediumPath;
  }

  Future<void> updateProfileImage(int userId, File imageFile) async {
    try {
      // 1. Upload image first
      final response = await _apiClient.profileApi
          .uploadAvatar(userId.toString(), imageFile);

      // 2. Once upload succeeds, enqueue sync operation for downloading variants
      if (response.data?.attributes.avatarUrls != null) {
        // Clean up old images before syncing new ones
        await _imageManager.cleanupOldImages(userId);

        await syncProfileImages(response.data!);

        // 3. Force a profile refresh to update the UI
        await getProfile(userId);
      }
    } catch (e) {
      dev.log('Failed to update profile image', error: e);
      rethrow;
    }
  }

  Future<void> handleImageConflict(int userId, DateTime serverTimestamp) async {
    final profile = await _db.getProfile(userId);

    if (profile?.imageUpdatedAt != null &&
        profile!.imageUpdatedAt!.isBefore(serverTimestamp)) {
      // Server has newer image, sync it
      final apiProfile =
          await _apiClient.profileApi.getProfile(userId.toString());
      if (apiProfile.data?.attributes.avatarUrls != null) {
        await syncProfileImages(apiProfile.data!);
      }
    }
  }

  bool _isStale(DateTime timestamp) {
    final staleThreshold = Duration(minutes: 5);
    return DateTime.now().difference(timestamp) > staleThreshold;
  }

  Future<api.Profile> _fetchFromServer(int userId) async {
    final response = await _apiClient.profileApi.getProfile(userId.toString());
    if (response.data != null) {
      final profile = response.data!;
      if (profile.attributes.avatarUrls != null) {
        return syncProfileImages(profile);
      }
      return profile;
    }
    throw Exception('Server returned no profile data');
  }

  Future<api.Profile> uploadAvatar(int userId, File imageFile,
      {String? filename}) async {
    // Use the provided filename or generate a default one without timestamp
    final actualFilename = filename ?? 'profile_$userId.jpg';
    try {
      // Upload to API and get response with processed image URLs
      final response = await _apiClient.profileApi
          .uploadAvatar(userId.toString(), imageFile, filename: actualFilename);

      if (response.data != null) {
        // Use syncProfileImages to handle the API response
        return await syncProfileImages(response.data!);
      }
      throw ApiException(message: 'Failed to upload avatar');
    } catch (e) {
      dev.log('Failed to upload avatar', error: e);
      rethrow;
    }
  }
}
