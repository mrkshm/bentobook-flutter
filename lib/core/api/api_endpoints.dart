class ApiEndpoints {
  // Auth
  static const String login = '/sessions';
  static const String register = '/users';
  static const String refreshToken = '/refresh_token';
  static const String logout = '/session';
  static const String logoutAll = '/sessions';

  // Profile
  static const String profile = '/profile';
  static const String updateProfile = '/profile';
  static const String updateAvatar = '/profile/avatar';
  static const String verifyUsername = '/usernames/verify';
}
