import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bentobook/core/shared/providers.dart';
import 'package:bentobook/core/profile/profile_provider.dart';
import 'package:bentobook/core/auth/auth_service.dart';
import 'package:bentobook/core/sync/operation_types.dart';
import 'package:bentobook/core/sync/queue_manager.dart';
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
        state = Locale(profile!.attributes.preferredLanguage!);
      }
    } catch (e) {
      dev.log('Error loading stored locale', error: e);
    }
  }

  Future<void> setLocale(Locale locale) async {
    // Update state immediately for responsive UI
    state = locale;

    try {
      // Queue the locale update for server sync
      await _ref.read(QueueManager.currentProvider).enqueueOperation(
        type: OperationType.localeUpdate,
        payload: {'locale': locale.languageCode},
      );
      dev.log('Locale update queued successfully');
    } catch (e) {
      dev.log('Error queueing locale update', error: e);
      // Don't revert the UI state even if queueing fails
      // The queue manager will retry the operation
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
