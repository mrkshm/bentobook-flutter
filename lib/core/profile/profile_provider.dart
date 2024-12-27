import 'dart:async';
import 'dart:developer' as dev;

import 'package:bentobook/core/api/models/profile.dart';
import 'package:bentobook/core/profile/profile_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bentobook/core/auth/auth_service.dart';
import 'package:bentobook/core/auth/auth_state.dart';

class ProfileState {
  final Profile? profile;
  final bool isLoading;
  final String? error;

  const ProfileState({
    this.profile,
    this.isLoading = false,
    this.error,
  });

  ProfileState copyWith({
    Profile? profile,
    bool? isLoading,
    String? error,
  }) {
    return ProfileState(
      profile: profile ?? this.profile,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class ProfileNotifier extends StateNotifier<ProfileState> {
  final ProfileRepository _repository;
  StreamSubscription<Profile?>? _profileSubscription;

  ProfileNotifier(this._repository) : super(const ProfileState());

  Future<void> initializeProfile(String userId) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      final profile = await _repository.getProfile(userId);
      state = state.copyWith(profile: profile, isLoading: false);
      
      // Start watching profile changes
      _profileSubscription?.cancel();
      _profileSubscription = _repository.watchProfile(userId).listen(
        (profile) {
          if (profile != null) {
            state = state.copyWith(profile: profile);
          }
        },
        onError: (error) {
          dev.log('ProfileNotifier: Error watching profile', error: error);
          state = state.copyWith(error: error.toString());
        },
      );
    } catch (e) {
      dev.log('ProfileNotifier: Failed to initialize profile', error: e);
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load profile',
      );
    }
  }

  Future<void> updateProfile({
    String? firstName,
    String? lastName,
    String? about,
    String? displayName,
    String? preferredTheme,
    String? preferredLanguage,
  }) async {
    if (state.isLoading) return;
    final currentProfile = state.profile;
    if (currentProfile == null) return;

    try {
      state = state.copyWith(isLoading: true, error: null);

      // Optimistic update
      final updatedProfile = currentProfile.copyWith(
        attributes: currentProfile.attributes.copyWith(
          firstName: firstName ?? currentProfile.attributes.firstName,
          lastName: lastName ?? currentProfile.attributes.lastName,
          about: about ?? currentProfile.attributes.about,
          displayName: displayName ?? currentProfile.attributes.displayName,
          preferredTheme: preferredTheme ?? currentProfile.attributes.preferredTheme,
          preferredLanguage: preferredLanguage ?? currentProfile.attributes.preferredLanguage,
        ),
      );
      state = state.copyWith(profile: updatedProfile);

      // Perform update
      await _repository.updateProfile(
        userId: currentProfile.id,
        firstName: firstName,
        lastName: lastName,
        about: about,
        displayName: displayName,
        preferredTheme: preferredTheme,
        preferredLanguage: preferredLanguage,
      );

      state = state.copyWith(isLoading: false);
    } catch (e) {
      dev.log('ProfileNotifier: Failed to update profile', error: e);
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to update profile',
        profile: currentProfile, // Rollback on error
      );
    }
  }

  void clearProfile() {
    _profileSubscription?.cancel();
    _profileSubscription = null;
    state = const ProfileState();
  }

  @override
  void dispose() {
    _profileSubscription?.cancel();
    super.dispose();
  }
}

final profileProvider = StateNotifierProvider<ProfileNotifier, ProfileState>((ref) {
  final repository = ref.watch(profileRepositoryProvider);
  final notifier = ProfileNotifier(repository);
  
  // Listen to auth state changes
  ref.listen<AuthState>(authServiceProvider, (previous, next) {
    next.maybeMap(
      authenticated: (state) => notifier.initializeProfile(state.user.id),
      unauthenticated: (_) => notifier.clearProfile(),
      orElse: () {},
    );
  });
  
  return notifier;
});
