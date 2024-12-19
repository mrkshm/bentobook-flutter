import 'package:drift/drift.dart';
import 'sync_status.dart';
import 'dart:convert';

class AvatarUrlsConverter extends TypeConverter<Map<String, String>, String> {
  const AvatarUrlsConverter();

  @override
  Map<String, String> fromSql(String fromDb) {
    return Map<String, String>.from(json.decode(fromDb));
  }

  @override
  String toSql(Map<String, String> value) {
    return json.encode(value);
  }
}

class Users extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get email => text().unique()();
  TextColumn get username => text().nullable()();
  TextColumn get displayName => text().nullable()();
  TextColumn get firstName => text().nullable()();
  TextColumn get lastName => text().nullable()();
  TextColumn get about => text().nullable()();
  TextColumn get preferredTheme => text().withDefault(const Constant('light'))();
  TextColumn get preferredLanguage => text().withDefault(const Constant('en'))();
  TextColumn get avatarUrls => text().map(const AvatarUrlsConverter()).nullable()();
  TextColumn get syncStatus => text().map(const SyncStatusConverter())
      .withDefault(const Constant('synced'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}