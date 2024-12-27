import 'package:bentobook/core/api/models/json_converters.dart';
import 'package:bentobook/core/api/models/profile.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'user.freezed.dart';
part 'user.g.dart';

@freezed
class User with _$User {
  const factory User({
    required String id,
    String? type,
    required UserAttributes attributes,
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}

@freezed
class UserAttributes with _$UserAttributes {
  const factory UserAttributes({
    @JsonKey(fromJson: _idFromJson) required int id,
    required String email,
    @JsonKey(name: 'created_at') 
    @UtcDateTimeConverter() 
    DateTime? createdAt,
    ProfileAttributes? profile,
  }) = _UserAttributes;

  factory UserAttributes.fromJson(Map<String, dynamic> json) =>
      _$UserAttributesFromJson(json);
}

// Helper function to convert various id formats to int
int _idFromJson(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is String) return int.parse(value);
  return 0;
}