import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter/foundation.dart';
import 'json_converters.dart';

part 'profile.freezed.dart';
part 'profile.g.dart';

@freezed
class Profile with _$Profile {
  const factory Profile({
    required String username,
    @JsonKey(name: 'first_name') 
    required String firstName,
    @JsonKey(name: 'last_name') 
    required String lastName,
    required String about,
    @JsonKey(name: 'full_name') 
    required String fullName,
    @JsonKey(name: 'display_name') 
    required String displayName,
    @JsonKey(name: 'preferred_theme') 
    required String preferredTheme,
    @JsonKey(name: 'preferred_language') 
    required String preferredLanguage,
    @JsonKey(name: 'created_at') 
    @UtcDateTimeConverter()
    required DateTime createdAt,
    @JsonKey(name: 'updated_at') 
    @UtcDateTimeConverter()
    required DateTime updatedAt,
    required String email,
    @JsonKey(name: 'avatar_urls') 
    required AvatarUrls avatarUrls,
  }) = _Profile;

  factory Profile.fromJson(Map<String, dynamic> json) => _$ProfileFromJson(json);
}

@freezed
class ProfileUpdateRequest with _$ProfileUpdateRequest {
  const factory ProfileUpdateRequest({
    @JsonKey(name: 'display_name')
    String? displayName,
    @JsonKey(name: 'first_name')
    String? firstName,
    @JsonKey(name: 'last_name')
    String? lastName,
    String? about,
    @JsonKey(name: 'preferred_theme')
    String? preferredTheme,
    @JsonKey(name: 'preferred_language')
    String? preferredLanguage,
  }) = _ProfileUpdateRequest;

  factory ProfileUpdateRequest.fromJson(Map<String, dynamic> json) =>
      _$ProfileUpdateRequestFromJson(json);
}

@freezed
class AvatarUrls with _$AvatarUrls {
  const factory AvatarUrls({
    required String thumbnail,
    required String small,
    required String medium,
    required String large,
    required String original,
  }) = _AvatarUrls;

  factory AvatarUrls.fromJson(Map<String, dynamic> json) => _$AvatarUrlsFromJson(json);
}
