import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const defaultScheme = FlexScheme.blue;

  static final schemes = {
    'Blue': FlexScheme.blue,
    'Material': FlexScheme.material,
    'Espresso': FlexScheme.espresso,
    'Sakura': FlexScheme.sakura,
    'Gold': FlexScheme.gold,
    'Amber': FlexScheme.amber,
    'Jungle': FlexScheme.jungle,
    'Deepblue': FlexScheme.deepBlue,
    'Green': FlexScheme.green,
    'Red': FlexScheme.red,
  };

  static ThemeData light({FlexScheme scheme = defaultScheme}) {
    return FlexThemeData.light(
      scheme: scheme,
      surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
      blendLevel: 7,
      subThemesData: const FlexSubThemesData(
        blendOnLevel: 10,
        blendOnColors: false,
        useMaterial3Typography: true,
        useM2StyleDividerInM3: true,
        alignedDropdown: true,
        useInputDecoratorThemeInDialogs: true,
      ),
      keyColors: const FlexKeyColors(),
      visualDensity: FlexColorScheme.comfortablePlatformDensity,
      fontFamily: GoogleFonts.notoSans().fontFamily,
    );
  }

  static ThemeData dark({FlexScheme scheme = defaultScheme}) {
    return FlexThemeData.dark(
      scheme: scheme,
      surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
      blendLevel: 13,
      subThemesData: const FlexSubThemesData(
        blendOnLevel: 20,
        useMaterial3Typography: true,
        useM2StyleDividerInM3: true,
        alignedDropdown: true,
        useInputDecoratorThemeInDialogs: true,
      ),
      keyColors: const FlexKeyColors(),
      visualDensity: FlexColorScheme.comfortablePlatformDensity,
      fontFamily: GoogleFonts.notoSans().fontFamily,
    );
  }

  static String schemeToString(FlexScheme scheme) {
    return schemes.entries
        .firstWhere(
          (e) => e.value == scheme,
          orElse: () => MapEntry('Blue', FlexScheme.blue),
        )
        .key;
  }

  static FlexScheme stringToScheme(String name) {
    return schemes[name] ?? defaultScheme;
  }
}
