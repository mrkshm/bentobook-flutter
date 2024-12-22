import 'package:drift/drift.dart';

enum SyncStatus {
  synced,      // Data is up to date with server
  pendingSync, // Local changes need to be synced
  error        // Last sync attempt failed
}

class SyncStatusConverter extends TypeConverter<SyncStatus, String> {
  const SyncStatusConverter();
  
  @override
  SyncStatus fromSql(String fromDb) {
    return SyncStatus.values.firstWhere(
      (e) => e.name == fromDb,
      orElse: () => SyncStatus.synced,
    );
  }

  @override
  String toSql(SyncStatus value) => value.name;
}

class SyncStatusTable extends Table {
  TextColumn get entityType => text()();
  IntColumn get entityId => integer()();
  TextColumn get status => textEnum<SyncStatus>()();
  DateTimeColumn get lastSynced => dateTime()();
  TextColumn get error => text().nullable()();

  @override
  Set<Column> get primaryKey => {entityType, entityId};
}
