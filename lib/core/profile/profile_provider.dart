import 'dart:async';

import 'package:bentobook/core/api/models/profile.dart';
import 'package:bentobook/core/auth/auth_service.dart';
import 'package:bentobook/core/image/image_manager.dart';
import 'package:bentobook/core/profile/profile_repository.dart';
import 'package:bentobook/core/shared/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:developer' as dev;
import 'dart:io';
import 'package:flutter/painting.dart';

class ProfileState {
  final Profile? profile;
  final bool isLoading;
  final String? error;
  final bool isUploadingImage;
  final int lastUpdated;

  const ProfileState({
    this.profile,
    this.isLoading = false,
    this.error,
    this.isUploadingImage = false,
    this.lastUpdated = 0,
  });

  ProfileState copyWith({
    Profile? profile,
    bool? isLoading,
    String? error,
    bool? isUploadingImage,
    int? lastUpdated,
  }) {
    return ProfileState(
      profile: profile ?? this.profile,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      isUploadingImage: isUploadingImage ?? this.isUploadingImage,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

class ProfileNotifier extends StateNotifier<ProfileState> {
  final ProfileRepository _repository;
  final ImageManager _imageManager;
  final Ref _ref;
  StreamSubscription<Profile?>? _profileSubscription;

  ProfileNotifier(this._repository, this._imageManager, this._ref)
      : super(const ProfileState());

  Future<void> initializeProfile(int userId) async {
    try {
      if (state.isLoading) {
        dev.log('ProfileNotifier: Already loading, skipping initialization');
        return;
      }

      dev.log(
          'ProfileNotifier: Starting profile initialization for user ID: $userId');
      state = state.copyWith(isLoading: true, error: null);

      // Get initial profile and store it
      var serverProfile = await _repository.getProfile(userId);
      dev.log(
          'ProfileNotifier: Initial profile fetched: ${serverProfile.toJson()}');

      // Download profile images if available
      if (serverProfile.attributes.avatarUrls?.thumbnail != null) {
        try {
          await _imageManager.downloadAndSaveProfileImages(
            userId: userId.toString(),
            thumbnailUrl:
                '${_ref.read(envConfigProvider).baseUrl}${serverProfile.attributes.avatarUrls!.thumbnail}',
            mediumUrl:
                '${_ref.read(envConfigProvider).baseUrl}${serverProfile.attributes.avatarUrls!.medium}',
          );

          final thumbnailPath =
              await _imageManager.getImagePath(userId, variant: 'thumbnail');
          final mediumPath =
              await _imageManager.getImagePath(userId, variant: 'medium');

          serverProfile = serverProfile.copyWith(
            localThumbnailPath: thumbnailPath,
            localMediumPath: mediumPath,
          );
        } catch (e) {
          dev.log('ProfileNotifier: Error downloading profile images',
              error: e);
        }
      }

      state = state.copyWith(profile: serverProfile, isLoading: false);

      // Start watching profile changes
      _profileSubscription?.cancel();
      _profileSubscription = _repository.watchProfile(userId).listen(
        (profile) {
          dev.log(
              'ProfileNotifier: Received profile update: ${profile?.toJson()}');
          if (profile != null &&
              (profile.attributes.username?.isNotEmpty == true ||
                  profile.attributes.displayName?.isNotEmpty == true)) {
            // Always preserve server profile's avatar URLs if available
            if (profile.attributes.avatarUrls == null &&
                serverProfile.attributes.avatarUrls != null) {
              profile = profile.copyWith(
                attributes: profile.attributes.copyWith(
                  avatarUrls: serverProfile.attributes.avatarUrls,
                ),
                localThumbnailPath: serverProfile.localThumbnailPath,
                localMediumPath: serverProfile.localMediumPath,
              );
            }
            dev.log(
                'ProfileNotifier: Updating state with valid profile update');
            state = state.copyWith(profile: profile);
          } else {
            dev.log('ProfileNotifier: Skipping empty profile update');
          }
        },
        onError: (error) {
          dev.log('ProfileNotifier: Error in profile stream', error: error);
          state = state.copyWith(error: error.toString());
        },
      );
    } catch (e) {
      dev.log('ProfileNotifier: Error initializing profile', error: e);
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void clearProfile() {
    _profileSubscription?.cancel();
    state = const ProfileState();
  }

  @override
  void dispose() {
    _profileSubscription?.cancel();
    super.dispose();
  }

  Future<void> refreshProfile(int userId) async {
    try {
      final profile = await _repository.getProfile(userId);
      state = state.copyWith(
        profile: profile,
        isLoading: false,
        error: null,
      );
    } catch (e) {
      dev.log('ProfileNotifier: Error refreshing profile', error: e);
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
    }
  }

  Future<void> updateAvatar(int userId, File imageFile) async {
    state = state.copyWith(isUploadingImage: true);
    try {
      imageCache.clear();
      imageCache.clearLiveImages();

      // Get original filename and sanitize it
      String originalName = imageFile.path.split('/').last;
      // Remove any existing timestamp pattern if present
      originalName = originalName.replaceAll(RegExp(r'_\d+\.[^.]+$'), '');
      // Truncate if too long (keeping extension)
      String extension =
          originalName.contains('.') ? '.${originalName.split('.').last}' : '';
      String nameWithoutExt = originalName.replaceAll(extension, '');
      if (nameWithoutExt.length > 30) {
        nameWithoutExt = nameWithoutExt.substring(0, 30);
      }
      // Add timestamp to ensure uniqueness
      String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      String newFilename = '${nameWithoutExt}_${userId}_$timestamp$extension';

      // Upload with new filename
      var updatedProfile = await _repository.uploadAvatar(userId, imageFile,
          filename: newFilename);

      // Clear local paths to force refresh
      state = state.copyWith(
        profile: updatedProfile.copyWith(
            localThumbnailPath: null, localMediumPath: null),
        isUploadingImage: true,
      );

      if (updatedProfile.attributes.avatarUrls?.thumbnail != null) {
        await _imageManager.downloadAndSaveProfileImages(
          userId: userId.toString(),
          thumbnailUrl:
              '${_ref.read(envConfigProvider).baseUrl}${updatedProfile.attributes.avatarUrls!.thumbnail}',
          mediumUrl:
              '${_ref.read(envConfigProvider).baseUrl}${updatedProfile.attributes.avatarUrls!.medium}',
        );

        final thumbnailPath =
            await _imageManager.getImagePath(userId, variant: 'thumbnail');
        final mediumPath =
            await _imageManager.getImagePath(userId, variant: 'medium');

        if (thumbnailPath != null &&
            mediumPath != null &&
            await File(thumbnailPath).exists()) {
          state = state.copyWith(
            profile: updatedProfile.copyWith(
              localThumbnailPath: thumbnailPath,
              localMediumPath: mediumPath,
            ),
            isUploadingImage: false,
            lastUpdated: DateTime.now().millisecondsSinceEpoch,
          );
        }
      }
    } catch (e) {
      state = state.copyWith(isUploadingImage: false, error: e.toString());
      rethrow;
    }
  }
}

// Profile state provider
final profileProvider =
    StateNotifierProvider<ProfileNotifier, ProfileState>((ref) {
  final repository = ref.read(profileRepositoryProvider);
  final imageManager = ref.read(imageManagerProvider);
  final notifier = ProfileNotifier(repository, imageManager, ref);

  // Listen to auth state changes
  ref.listen(authServiceProvider, (previous, next) {
    dev.log('ProfileProvider: Auth state changed');
    dev.log('ProfileProvider: Previous state: $previous');
    dev.log('ProfileProvider: Next state: $next');

    next.maybeMap(
      authenticated: (state) async {
        final userId = int.tryParse(state.userId);
        dev.log('ProfileProvider: Parsed user ID: $userId');
        if (userId != null) {
          dev.log('ProfileProvider: Initializing profile for user: $userId');
          // Force immediate initialization
          await notifier.initializeProfile(userId);
        } else {
          dev.log('ProfileProvider: Failed to parse user ID: ${state.userId}');
        }
      },
      orElse: () {
        dev.log('ProfileProvider: Non-authenticated state, clearing profile');
        notifier.clearProfile();
      },
    );
  }, fireImmediately: true);

  return notifier;
});
