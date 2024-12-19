import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter/foundation.dart';
import 'device_info.dart';

part 'api_response.freezed.dart';
part 'api_response.g.dart';

@Freezed(genericArgumentFactories: true)
class ApiResponse<T> with _$ApiResponse<T> {
  const ApiResponse._();
  
  const factory ApiResponse({
    required String status,
    T? data,
    ApiMeta? meta,
    @Default([]) List<ApiError> errors,
  }) = _ApiResponse<T>;

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Object?) fromJsonT,
  ) =>
      _$ApiResponseFromJson(json, fromJsonT);

  bool get isSuccess => status == 'success';
}

@freezed
class ApiMeta with _$ApiMeta {
  const factory ApiMeta({
    required String timestamp,
    String? token,
    @JsonKey(name: 'device_info') DeviceInfo? deviceInfo,
  }) = _ApiMeta;

  factory ApiMeta.fromJson(Map<String, dynamic> json) =>
      _$ApiMetaFromJson(json);
}

@freezed
class ApiError with _$ApiError {
  const factory ApiError({
    required String code,
    required String detail,
  }) = _ApiError;

  factory ApiError.fromJson(Map<String, dynamic> json) =>
      _$ApiErrorFromJson(json);
}