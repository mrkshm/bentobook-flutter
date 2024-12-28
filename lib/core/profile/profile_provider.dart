import 'dart:async';

import 'package:bentobook/core/api/models/profile.dart';
import 'package:bentobook/core/auth/auth_service.dart';
import 'package:bentobook/core/profile/profile_repository.dart';
import 'package:bentobook/core/shared/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:developer' as dev;

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

  Future<void> initializeProfile(int userId) async {
    try {
      if (state.isLoading) {
        dev.log('ProfileNotifier: Already loading, skipping initialization');
        return;
      }

      dev.log(
          'ProfileNotifier: Starting profile initialization for user ID: $userId');
      state = state.copyWith(isLoading: true, error: null);

      // Start watching profile changes
      _profileSubscription?.cancel();
      _profileSubscription = _repository.watchProfile(userId).listen(
        (profile) {
          dev.log(
              'ProfileNotifier: Received profile update: ${profile?.attributes.displayName}');
          if (!state.isLoading) {
            state = state.copyWith(profile: profile);
          }
        },
        onError: (error) {
          dev.log('ProfileNotifier: Error in profile stream', error: error);
          state = state.copyWith(error: error.toString());
        },
      );

      // Get initial profile
      dev.log('ProfileNotifier: Fetching initial profile');
      final profile = await _repository.getProfile(userId);
      dev.log(
          'ProfileNotifier: Initial profile fetched: ${profile.attributes.displayName}');
      state = state.copyWith(profile: profile, isLoading: false);
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
  final repository = ref.watch(profileRepositoryProvider);
  final notifier = ProfileNotifier(repository);

  // Listen to auth state changes
  ref.listen(authServiceProvider, (previous, next) {
    dev.log('ProfileProvider: Auth state changed');
    dev.log('ProfileProvider: Previous state: $previous');
    dev.log('ProfileProvider: Next state: $next');

    next.maybeMap(
      authenticated: (state) {
        final userId = int.tryParse(state.userId);
        dev.log('ProfileProvider: Parsed user ID: $userId');
        if (userId != null) {
          dev.log('ProfileProvider: Initializing profile for user: $userId');
          notifier.initializeProfile(userId);
        } else {
          dev.log('ProfileProvider: Failed to parse user ID: ${state.userId}');
        }
      },
      orElse: () {
        dev.log('ProfileProvider: Non-authenticated state, clearing profile');
        notifier.clearProfile();
      },
    );
  });

  return notifier;
});
