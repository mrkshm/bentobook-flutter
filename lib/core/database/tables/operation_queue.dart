import 'package:drift/drift.dart';
import 'package:bentobook/core/sync/operation_types.dart';

class OperationQueue extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get operationType => textEnum<OperationType>()();
  TextColumn get status => textEnum<OperationStatus>()();
  TextColumn get payload => text()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get error => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}