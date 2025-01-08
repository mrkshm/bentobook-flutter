import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'BentoBook';

  @override
  String get profileTitle => 'Profil';

  @override
  String get appearance => 'Apparence';

  @override
  String get themeMode => 'Mode de thème';

  @override
  String get colorScheme => 'Schéma de couleurs';

  @override
  String get personalInformation => 'Informations personnelles';

  @override
  String get username => 'Nom d\'utilisateur';

  @override
  String get firstName => 'Prénom';

  @override
  String get lastName => 'Nom';

  @override
  String get email => 'E-mail';

  @override
  String get about => 'À propos';

  @override
  String get preferences => 'Préférences';

  @override
  String get language => 'Langue';

  @override
  String get notSet => 'Non défini';

  @override
  String get loading => 'Chargement...';

  @override
  String errorLoading(String field) {
    return 'Erreur lors du chargement de $field';
  }

  @override
  String get logout => 'Déconnexion';

  @override
  String get logoutConfirmation => 'Êtes-vous sûr de vouloir vous déconnecter ?';

  @override
  String get cancel => 'Annuler';

  @override
  String get save => 'Enregistrer';

  @override
  String get edit => 'Modifier';
}
