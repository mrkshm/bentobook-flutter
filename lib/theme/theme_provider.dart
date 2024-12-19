import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flex_color_scheme/flex_color_scheme.dart' show FlexScheme;

// Mock subscription status - replace with actual subscription logic
final isSubscribedProvider = Provider<bool>((ref) => false);

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  return ThemeNotifier();
});

final colorSchemeProvider = StateNotifierProvider<ColorSchemeNotifier, FlexScheme>((ref) {
  final isSubscribed = ref.watch(isSubscribedProvider);
  // Non-subscribers always get the default blue theme
  return ColorSchemeNotifier(isSubscribed);
});

class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier() : super(ThemeMode.system);

  void setTheme(ThemeMode theme) {
    state = theme;
  }

  void toggleTheme() {
    state = state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
  }
}

class ColorSchemeNotifier extends StateNotifier<FlexScheme> {
  ColorSchemeNotifier(this.isSubscribed) : super(FlexScheme.blue);
  
  final bool isSubscribed;

  void setScheme(FlexScheme scheme) {
    if (isSubscribed) {
      state = scheme;
    }
    // Silently ignore theme changes for non-subscribers
    // Or you could throw an error, show a dialog, etc.
  }
}