import 'package:drift/drift.dart';
import 'package:bentobook/core/sync/operation_types.dart';

class OperationQueue extends Table {
  IntColumn get id => integer()();
  TextColumn get operationType => textEnum<OperationType>()();
  TextColumn get payload => text()();
  TextColumn get status => textEnum<OperationStatus>()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get error => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get localTimestamp => dateTime()();
  DateTimeColumn get serverTimestamp => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}