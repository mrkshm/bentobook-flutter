import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter/foundation.dart';
import 'json_converters.dart';
import 'profile.dart';

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
    required int id,
    required String email,
    @JsonKey(name: 'created_at') 
    @UtcDateTimeConverter()
    required DateTime createdAt,
    Profile? profile,
  }) = _UserAttributes;

  factory UserAttributes.fromJson(Map<String, dynamic> json) =>
      _$UserAttributesFromJson(json);
}