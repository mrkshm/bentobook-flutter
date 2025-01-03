import 'dart:async';

import 'package:bentobook/core/api/models/profile.dart';
import 'package:bentobook/core/auth/auth_service.dart';
import 'package:bentobook/core/image/image_manager.dart';
import 'package:bentobook/core/profile/profile_repository.dart';
import 'package:bentobook/core/shared/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:developer' as dev;

class ProfileState {
  final Profile? profile;
  final bool isLoading;
  final String? error;
  final bool isUploadingImage;

  const ProfileState({
    this.profile,
    this.isLoading = false,
    this.error,
    this.isUploadingImage = false,
  });

  ProfileState copyWith({
    Profile? profile,
    bool? isLoading,
    String? error,
    bool? isUploadingImage,
  }) {
    return ProfileState(
      profile: profile ?? this.profile,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isUploadingImage: isUploadingImage ?? this.isUploadingImage,
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

      // Get initial profile
      var profile = await _repository.getProfile(userId);
      dev.log('ProfileNotifier: Initial profile fetched: ${profile.toJson()}');

      // Download profile images if available
      if (profile.attributes.avatarUrls?.thumbnail != null &&
          profile.attributes.avatarUrls?.medium != null) {
        try {
          await _imageManager.downloadAndSaveProfileImages(
            userId: userId.toString(),
            thumbnailUrl:
                '${_ref.read(envConfigProvider).baseUrl}${profile.attributes.avatarUrls!.thumbnail}',
            mediumUrl:
                '${_ref.read(envConfigProvider).baseUrl}${profile.attributes.avatarUrls!.medium}',
          );

          // Get local paths
          final thumbnailPath =
              await _imageManager.getImagePath(userId, variant: 'thumbnail');
          final mediumPath =
              await _imageManager.getImagePath(userId, variant: 'medium');

          // Update profile with local paths
          profile = profile.copyWith(
            localThumbnailPath: thumbnailPath,
            localMediumPath: mediumPath,
          );
        } catch (e) {
          dev.log('ProfileNotifier: Error downloading profile images',
              error: e);
        }
      }

      state = state.copyWith(profile: profile, isLoading: false);

      // Start watching profile changes
      _profileSubscription?.cancel();
      _profileSubscription = _repository.watchProfile(userId).listen(
        (profile) {
          dev.log(
              'ProfileNotifier: Received profile update: ${profile?.toJson()}');
          if (profile != null &&
              (profile.attributes.username?.isNotEmpty == true ||
                  profile.attributes.displayName?.isNotEmpty == true)) {
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
