import 'package:bentobook/core/api/models/user.dart' as api;
import 'package:bentobook/core/database/database.dart';
import 'package:bentobook/core/theme/theme_persistence.dart';
import 'dart:developer' as dev;

extension UserToApi on User {
  api.User toApiUser() {
    final urls = avatarUrls;
    final themeString = ThemePersistence.themeToString(preferredTheme);
    dev.log('Database: Converting ThemeMode "$preferredTheme" to API string: "$themeString"');
    
    return api.User(
      id: id.toString(),
      type: 'users',
      attributes: api.UserAttributes(
        email: email,
        profile: api.UserProfile(
          username: username,
          displayName: displayName,
          firstName: firstName,
          lastName: lastName,
          about: about,
          preferredTheme: themeString,
          preferredLanguage: preferredLanguage,
          avatarUrls: urls != null 
            ? api.AvatarUrls(
                small: urls['small'],
                medium: urls['medium'],
                large: urls['large'],
              )
            : null,
        ),
      ),
    );
  }
}
