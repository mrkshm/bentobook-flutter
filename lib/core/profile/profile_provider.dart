import 'dart:async';

import 'package:bentobook/core/api/models/profile.dart';
import 'package:bentobook/core/auth/auth_service.dart';
import 'package:bentobook/core/profile/profile_repository.dart';
import 'package:bentobook/core/shared/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      if (state.isLoading) return; // Prevent duplicate initialization
      
      state = state.copyWith(isLoading: true, error: null);
      
      // Start watching profile changes first
      _profileSubscription?.cancel();
      _profileSubscription = _repository.watchProfile(userId).listen(
        (profile) {
          if (!state.isLoading) { // Only update if not in initial load
            state = state.copyWith(profile: profile);
          }
        },
        onError: (error) {
          state = state.copyWith(error: error.toString());
        },
      );
      
      // Then get initial profile
      final profile = await _repository.getProfile(userId);
      state = state.copyWith(profile: profile, isLoading: false);
    } catch (e) {
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
final profileProvider = StateNotifierProvider<ProfileNotifier, ProfileState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final db = ref.watch(databaseProvider);
  final repository = ProfileRepository(apiClient, db);
  final notifier = ProfileNotifier(repository);

  // Listen to auth state changes
  ref.listen(authServiceProvider, (previous, next) {
    next.maybeMap(
      authenticated: (state) {
        // Only initialize if previous state was not authenticated or if user changed
        if (previous?.maybeMap(
          authenticated: (prevAuth) => prevAuth.userId != state.userId,
          orElse: () => true,
        ) ?? true) {
          notifier.initializeProfile(state.userId as int);
        }
      },
      orElse: () {},
    );
  });

  return notifier;
});
