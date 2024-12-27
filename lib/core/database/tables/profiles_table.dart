import 'package:drift/drift.dart';

class Profiles extends Table {
  IntColumn get id => integer()();
  TextColumn get userId => text().unique()();
  TextColumn get displayName => text().nullable()();
  TextColumn get about => text().nullable()();
  TextColumn get firstName => text().nullable()();
  TextColumn get lastName => text().nullable()();
  TextColumn get preferredTheme => 
      text().withDefault(const Constant('system'))();
  TextColumn get preferredLanguage =>
      text().withDefault(const Constant('en'))();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
