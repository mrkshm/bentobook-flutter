import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences.dart';

class ThemeNotifier extends StateNotifier<bool> {
  ThemeNotifier() : super(true) {
    _loadTheme();
  }

  static const _key = 'is_light_theme';
  late final SharedPreferences _prefs;

  Future<void> _loadTheme() async {
    _prefs = await SharedPreferences.getInstance();
    state = _prefs.getBool(_key) ?? true;
  }

  Future<void> toggleTheme() async {
    state = !state;
    await _prefs.setBool(_key, state);
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, bool>((ref) {
  return ThemeNotifier();
});
