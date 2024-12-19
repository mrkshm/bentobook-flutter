import 'package:freezed_annotation/freezed_annotation.dart';

class UtcDateTimeConverter implements JsonConverter<DateTime, String> {
  const UtcDateTimeConverter();

  @override
  DateTime fromJson(String json) {
    if (json.contains('UTC')) {
      // Handle "2024-11-14 17:25:04 UTC" format
      return DateTime.parse(json.replaceAll(' UTC', 'Z'));
    }
    // Handle ISO format "2024-12-18T15:54:37.397Z"
    return DateTime.parse(json);
  }

  @override
  String toJson(DateTime object) {
    return object.toUtc().toIso8601String();
  }
}