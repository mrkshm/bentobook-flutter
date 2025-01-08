import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'BentoBook';

  @override
  String get profileTitle => 'Profile';

  @override
  String get appearance => 'Appearance';

  @override
  String get themeMode => 'Theme Mode';

  @override
  String get colorScheme => 'Color Scheme';

  @override
  String get personalInformation => 'Personal Information';

  @override
  String get username => 'Username';

  @override
  String get firstName => 'First Name';

  @override
  String get lastName => 'Last Name';

  @override
  String get email => 'Email';

  @override
  String get about => 'About';

  @override
  String get preferences => 'Preferences';

  @override
  String get language => 'Language';

  @override
  String get notSet => 'Not set';

  @override
  String get loading => 'Loading...';

  @override
  String errorLoading(String field) {
    return 'Error loading $field';
  }

  @override
  String get logout => 'Logout';

  @override
  String get logoutConfirmation => 'Are you sure you want to logout?';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get edit => 'Edit';
}
