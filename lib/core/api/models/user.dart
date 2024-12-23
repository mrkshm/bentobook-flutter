import 'package:freezed_annotation/freezed_annotation.dart';

part 'user.freezed.dart';
part 'user.g.dart';

class DateTimeConverter implements JsonConverter<DateTime, String> {
  const DateTimeConverter();

  @override
  DateTime fromJson(String json) {
    return DateTime.parse(json.replaceAll(' ', 'T'));
  }

  @override
  String toJson(DateTime date) {
    return date.toUtc().toString();
  }
}

@freezed
class User with _$User {
  const factory User({
    @JsonKey(fromJson: _intFromJson) required String id,
    String? type, // Make nullable
    required UserAttributes attributes,
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}

String _intFromJson(dynamic value) => value.toString();

@freezed
class UserAttributes with _$UserAttributes {
  const factory UserAttributes({
    required String email,
    String? username,
    @JsonKey(name: 'first_name') String? firstName,
    @JsonKey(name: 'last_name') String? lastName,
    @JsonKey(name: 'preferred_theme') String? preferredTheme,
    UserProfile? profile,
    @DateTimeConverter() DateTime? updatedAt,
  }) = _UserAttributes;

  factory UserAttributes.fromJson(Map<String, dynamic> json) =>
      _$UserAttributesFromJson(json);
}

@freezed
class UserProfile with _$UserProfile {
  const factory UserProfile({
    String? username,
    @JsonKey(name: 'first_name') String? firstName,
    @JsonKey(name: 'last_name') String? lastName,
    String? about,
    @JsonKey(name: 'full_name') String? fullName,
    @JsonKey(name: 'display_name') String? displayName,
    @JsonKey(name: 'preferred_theme') String? preferredTheme,
    @JsonKey(name: 'preferred_language') String? preferredLanguage,
    @JsonKey(name: 'created_at') @DateTimeConverter() DateTime? createdAt,
    @JsonKey(name: 'updated_at') @DateTimeConverter() DateTime? updatedAt,
    @JsonKey(name: 'avatar_urls') AvatarUrls? avatarUrls,
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
