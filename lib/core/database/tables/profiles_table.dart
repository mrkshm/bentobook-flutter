import 'package:bentobook/core/database/tables/users_table.dart';
import 'package:drift/drift.dart';

class Profiles extends Table {
  IntColumn get userId => integer().references(Users, #id)();
  TextColumn get username => text().nullable()();
  TextColumn get displayName => text().nullable()();
  TextColumn get about => text().nullable()();
  TextColumn get firstName => text().nullable()();
  TextColumn get lastName => text().nullable()();
  TextColumn get preferredTheme =>
      text().nullable().withDefault(const Constant('system'))();
  TextColumn get preferredLanguage =>
      text().nullable().withDefault(const Constant('en'))();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {userId};
}
