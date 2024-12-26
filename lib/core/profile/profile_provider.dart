import 'package:bentobook/core/api/models/profile.dart';
import 'package:bentobook/core/profile/profile_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bentobook/core/api/models/user.dart' as user_models;
import 'package:bentobook/core/auth/auth_service.dart';
import 'package:bentobook/core/auth/auth_state.dart';

// Profile state
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

// Profile notifier
class ProfileNotifier extends StateNotifier<ProfileState> {
  final ProfileRepository _repository;

  ProfileNotifier(this._repository) : super(const ProfileState());

  void initializeProfile(user_models.User user) {
    state = state.copyWith(
      profile: Profile(
        id: user.id,
        type: 'profile',
        attributes: ProfileAttributes(
          username: user.attributes.username ?? '',
          firstName: user.attributes.firstName,
          lastName: user.attributes.lastName,
          about: user.attributes.profile?.about,
          fullName: '${user.attributes.firstName ?? ''} ${user.attributes.lastName ?? ''}'.trim(),
          displayName: user.attributes.username ?? '',
          preferredTheme: user.attributes.preferredTheme ?? 'light',
          preferredLanguage: user.attributes.profile?.preferredLanguage ?? 'en',
          createdAt: user.attributes.profile?.createdAt ?? DateTime.now(),
          updatedAt: user.attributes.updatedAt ?? DateTime.now(),
          email: user.attributes.email ?? '',
          avatarUrls: AvatarUrls(
            thumbnail: '',
            small: '',
            medium: '',
            large: '',
            original: '',
          ),
        ),
      ),
    );
  }

  void clearProfile() {
    state = state.copyWith(profile: null);
  }

  Future<void> updateProfile({
    String? username,
    String? firstName,
    String? lastName,
    String? about,
  }) async {
    if (state.isLoading) return;

    // Store the current profile for rollback
    final previousProfile = state.profile;
    if (previousProfile == null) return;

    try {
      // Create new attributes with updated fields
      final updatedAttributes = previousProfile.attributes.copyWith(
        username: username ?? previousProfile.attributes.username,
        firstName: firstName ?? previousProfile.attributes.firstName,
        lastName: lastName ?? previousProfile.attributes.lastName,
        about: about ?? previousProfile.attributes.about,
      );

      // Create new profile with updated attributes
      final updatedProfile = previousProfile.copyWith(
        attributes: updatedAttributes,
      );

      state = state.copyWith(
        isLoading: true,
        error: null,
        profile: updatedProfile, // Optimistic update
      );

      await _repository.updateProfile(
        username: username,
        firstName: firstName,
        lastName: lastName,
        about: about,
      );

      // Update successful, keep the optimistic update
      state = state.copyWith(isLoading: false);
    } catch (e) {
      // Update failed, rollback to previous profile
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
        profile: previousProfile,
      );
    }
  }

  void startListening() {
    _repository.watchProfile().listen(
      (profile) {
        if (profile != null) {
          state = state.copyWith(profile: profile);
        }
      },
      onError: (error) {
        state = state.copyWith(error: error.toString());
      },
    );
  }
}

// Providers
final profileProvider = StateNotifierProvider<ProfileNotifier, ProfileState>((ref) {
  final repository = ref.watch(profileRepositoryProvider);
  final notifier = ProfileNotifier(repository);
  
  // Listen to auth state changes
  ref.listen<AuthState>(authServiceProvider, (previous, next) {
    next.maybeMap(
      authenticated: (state) => notifier.initializeProfile(state.user),
      orElse: () => notifier.clearProfile(),
    );
  });

  // Initialize profile from current auth state
  ref.read(authServiceProvider).maybeMap(
    authenticated: (state) => notifier.initializeProfile(state.user),
    orElse: () {},
  );
  
  return notifier;
});
