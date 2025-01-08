import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bentobook/core/shared/providers.dart';
import 'package:bentobook/core/profile/profile_provider.dart';
import 'package:bentobook/core/auth/auth_service.dart';
import 'dart:developer' as dev;

class LocaleNotifier extends StateNotifier<Locale> {
  final Ref _ref;

  LocaleNotifier(this._ref) : super(const Locale('en')) {
    // Initialize with user's preferred language if available
    _loadStoredLocale();
  }

  Future<void> _loadStoredLocale() async {
    try {
      final profile = _ref.read(profileProvider).profile;
      if (profile?.attributes.preferredLanguage != null) {
        setLocale(Locale(profile!.attributes.preferredLanguage!));
      }
    } catch (e) {
      dev.log('Error loading stored locale', error: e);
    }
  }

  Future<void> setLocale(Locale locale) async {
    state = locale;
    // Update user's preferred language in profile
    try {
      final userId = _ref.read(authServiceProvider).maybeMap(
            authenticated: (state) => int.tryParse(state.userId),
            orElse: () => null,
          );

      if (userId != null) {
        await _ref.read(profileRepositoryProvider).updateProfile(
              userId: userId,
              preferredLanguage: locale.languageCode,
            );
      }
    } catch (e) {
      dev.log('Error saving locale preference', error: e);
    }
  }
}

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier(ref);
});

final supportedLocalesProvider = Provider<List<Locale>>((ref) {
  return const [
    Locale('en'), // English
    Locale('ja'), // Japanese
    Locale('fr'), // French
    // Add more locales as needed
  ];
});
