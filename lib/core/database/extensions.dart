import 'package:bentobook/core/api/models/user.dart' as api;
import 'package:bentobook/core/database/database.dart';

extension UserToApi on User {
  api.User toApiUser() {
    final urls = avatarUrls;
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
          preferredTheme: preferredTheme,
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
