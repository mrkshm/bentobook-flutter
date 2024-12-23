import 'package:freezed_annotation/freezed_annotation.dart';
import 'user.dart';

part 'session_response.freezed.dart';
part 'session_response.g.dart';

@freezed
class SessionResponse with _$SessionResponse {
  const factory SessionResponse({
    required String id,
    required String type,
    required SessionAttributes attributes,
  }) = _SessionResponse;

  factory SessionResponse.fromJson(Map<String, dynamic> json) => 
      _$SessionResponseFromJson(json);
}

@freezed
class SessionAttributes with _$SessionAttributes {
  const factory SessionAttributes({
    required String token,
    required User user,  // Remove custom JsonKey
  }) = _SessionAttributes;

  factory SessionAttributes.fromJson(Map<String, dynamic> json) => 
      _$SessionAttributesFromJson(json);
}
