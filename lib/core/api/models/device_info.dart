import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter/foundation.dart';
import 'json_converters.dart';

part 'device_info.freezed.dart';
part 'device_info.g.dart';

@freezed
class DeviceInfo with _$DeviceInfo {
  const factory DeviceInfo({
    required String type,
    required String device,
    required String platform,
    @JsonKey(name: 'client_name') required String clientName,
    @JsonKey(name: 'last_used_at') 
    @UtcDateTimeConverter()
    required DateTime lastUsedAt,
    @JsonKey(name: 'last_ip') required String lastIp,
  }) = _DeviceInfo;

  factory DeviceInfo.fromJson(Map<String, dynamic> json) =>
      _$DeviceInfoFromJson(json);
}