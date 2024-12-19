import 'package:freezed_annotation/freezed_annotation.dart';

part 'user.freezed.dart';
part 'user.g.dart';

@freezed
class User with _$User {
  const factory User({
    required String id,
    required String type,
    required UserAttributes attributes,
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}

@freezed
class UserAttributes with _$UserAttributes {
  const factory UserAttributes({
    required String email,
    UserProfile? profile,
  }) = _UserAttributes;

  factory UserAttributes.fromJson(Map<String, dynamic> json) =>
      _$UserAttributesFromJson(json);
}

@freezed
class UserProfile with _$UserProfile {
  const factory UserProfile({
    String? username,
    String? displayName,
    String? firstName,
    String? lastName,
    String? about,
    String? preferredTheme,
    String? preferredLanguage,
    AvatarUrls? avatarUrls,
  }) = _UserProfile;

  factory UserProfile.fromJson(Map<String, dynamic> json) =>
      _$UserProfileFromJson(json);
}

@freezed
class AvatarUrls with _$AvatarUrls {
  const factory AvatarUrls({
    String? small,
    String? medium,
    String? large,
  }) = _AvatarUrls;

  factory AvatarUrls.fromJson(Map<String, dynamic> json) =>
      _$AvatarUrlsFromJson(json);
}